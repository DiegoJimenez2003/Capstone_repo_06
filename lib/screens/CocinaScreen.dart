import 'package:flutter/material.dart';
import '../servicios/supabase_service.dart';
import '../models/order_status.dart';
import '../screens/Loginscreen.dart'; 

class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  final _svc = SupabaseService();
  List<Map<String, dynamic>> pedidos = [];

  // Solo hasta "listo"
  final List<OrderStatus> _statusOptions = OrderStatusMapper.workflow()
      .where((s) => s != OrderStatus.entregado && s != OrderStatus.cancelado)
      .toList();

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    // Usamos fetchAllOrdersWithItems que usa 'pedidos' y 'detalle_pedido'
    final data = await _svc.fetchAllOrdersWithItems();
    if (mounted) {
      setState(() => pedidos = data);
    }
  }

  Future<void> _actualizarEstadoProducto(String itemId, String nuevoEstado) async {
    try {
      await _svc.updateProductStatus(itemId, nuevoEstado);
      await _cargarPedidos();
      final label = OrderStatusMapper.fromDb(nuevoEstado).label;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Estado actualizado a '$label'")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al actualizar: $e")),
        );
      }
    }
  }

  // 🔹 FUNCIÓN PARA CERRAR SESIÓN
  Future<void> _logOut() async {
    await _svc.logOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Loginscreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Color getColor(String status) {
    final normalized = OrderStatusMapper.normalize(status);
    switch (normalized) {
      case 'pendiente':
        return Colors.yellow.shade600;
      case 'preparacion':
        return Colors.blue.shade600;
      case 'horno':
        return Colors.orange.shade700;
      case 'listo':
        return Colors.green.shade600;
      case 'entregado':
        return Colors.purple.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Cocina"),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(onPressed: _cargarPedidos, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: pedidos.isEmpty
          ? const Center(
              child: Text(
                "No hay pedidos pendientes.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...pedidos.map((pedido) {
                  final items = List<Map<String, dynamic>>.from(pedido['detalle_pedido'] ?? const []); 
                  final orderStatusValue =
                      OrderStatusMapper.normalize(pedido['estado'] ?? 'pendiente');
                  final orderStatus = OrderStatusMapper.fromDb(orderStatusValue);
                  
                  final waiterDisplay = pedido['mesero_id']?.toString() ?? 'N/A';
                  final mesaNumber = pedido['numero_mesa']?.toString() ?? 'N/A';
                  
                  final total = (pedido['total'] as num?)?.toStringAsFixed(0) ?? '0';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    child: ExpansionTile(
                      title: Text(
                        "Mesa $mesaNumber - Mesero ID: $waiterDisplay",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Total: \$$total • Estado: ${orderStatus.label}",
                        style: const TextStyle(color: Colors.black54),
                      ),
                      children: items.map((item) {
                        final estado = OrderStatusMapper.normalize(
                            item['estado_producto'] ?? 'pendiente');
                        final statusEnum = OrderStatusMapper.fromDb(estado);
                        final itemName = item['nombre_producto'] ?? 'Producto Desconocido'; 
                        final itemQuantity = (item['cantidad'] as num?)?.toInt() ?? 1; 

                        final allowedStatuses = _statusOptions;

                        final safeValue = allowedStatuses.any((s) => s.toDb() == estado)
                            ? estado
                            : null;

                        return ListTile(
                          title: Text("$itemName (${itemQuantity}x)"),
                          subtitle: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: getColor(estado),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('Estado: ${statusEnum.label}'),
                            ],
                          ),
                          trailing: statusEnum == OrderStatus.entregado
                              ? const Text(
                                  "Entregado",
                                  style: TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold),
                                )
                              : DropdownButtonHideUnderline(
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: getColor(estado).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: getColor(estado)),
                                    ),
                                    child: DropdownButton<String>(
                                      value: safeValue,
                                      dropdownColor: Colors.white,
                                      icon: const Icon(Icons.keyboard_arrow_down),
                                      items: allowedStatuses
                                          .map(
                                            (status) => DropdownMenuItem<String>(
                                              value: status.toDb(),
                                              child: Text(status.label),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null && value != estado) {
                                          _actualizarEstadoProducto(
                                              item['id']?.toString() ?? '', value);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                        );
                      }).toList(),
                    ),
                  );
                }),

                const SizedBox(height: 30),

                // BOTÓN DE CERRAR SESIÓN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _logOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout, color: Colors.black87),
                      label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.black87)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
