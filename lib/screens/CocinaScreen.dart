import 'package:flutter/material.dart';
import '../servicios/supabase_service.dart';
import '../models/order_status.dart';

class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  final _svc = SupabaseService();
  List<Map<String, dynamic>> pedidos = [];
  final List<OrderStatus> _statusOptions = OrderStatusMapper.workflow();

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    final data = await _svc.fetchAllOrdersWithItems();
    setState(() => pedidos = data);
  }

  Future<void> _actualizarEstadoProducto(String itemId, String nuevoEstado) async {
    try {
      await _svc.updateProductStatus(itemId, nuevoEstado);
      await _cargarPedidos();
      final label = OrderStatusMapper.fromDb(nuevoEstado).label;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Estado actualizado a '$label'")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al actualizar: $e")),
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
              child: Text("No hay pedidos pendientes.",
                  style: TextStyle(fontSize: 18, color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: pedidos.map((pedido) {
                final items = List<Map<String, dynamic>>.from(pedido['detalle_pedido']);
                final orderStatusValue = OrderStatusMapper.normalize(
                    pedido['status'] ?? 'pendiente');
                final orderStatus = OrderStatusMapper.fromDb(orderStatusValue);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  child: ExpansionTile(
                    title: Text(
                      "Mesa ${pedido['table_number']} - ${pedido['waiter']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Total: \$${pedido['total']} • Estado: ${orderStatus.label}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    children: items.map((item) {
                      final estado = OrderStatusMapper.normalize(
                          item['product_status'] ?? 'pendiente');
                      final statusEnum = OrderStatusMapper.fromDb(estado);
                      return ListTile(
                        title: Text("${item['name']} (${item['quantity']}x)"),
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
                        trailing: DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: getColor(estado).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: getColor(estado)),
                            ),
                            child: DropdownButton<String>(
                              value: estado,
                              dropdownColor: Colors.white,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              items: _statusOptions
                                  .map(
                                    (status) => DropdownMenuItem<String>(
                                      value: status.toDb(),
                                      child: Text(status.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null && value != estado) {
                                  _actualizarEstadoProducto(item['id'], value);
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
