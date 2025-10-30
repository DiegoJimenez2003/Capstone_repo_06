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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Estado actualizado a '$nuevoEstado'")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al actualizar: $e")),
      );
    }
  }

  Color getColor(String status) {
    switch (status) {
      case 'pendiente':
        return Colors.yellow.shade600;
      case 'preparacion':
        return Colors.blue.shade600;
      case 'horno':
        return Colors.orange.shade700;
      case 'entregado':
        return Colors.purple.shade600;
      case 'listo':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  List<String> nextStatuses(String actual) {
    switch (actual) {
      case 'pendiente':
        return ['preparacion'];
      case 'preparacion':
        return ['horno'];
      case 'horno':
        return ['entregado'];
      case 'entregado':
        return ['listo'];
      default:
        return [];
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
                final items = List<Map<String, dynamic>>.from(pedido['order_items']);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  child: ExpansionTile(
                    title: Text(
                      "Mesa ${pedido['table_number']} - ${pedido['waiter']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Total: \$${pedido['total']} • Estado: ${pedido['status']}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    children: items.map((item) {
                      final estado = item['product_status'];
                      return ListTile(
                        title: Text("${item['name']} (${item['quantity']}x)"),
                        subtitle: Text("Estado: $estado"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var next in nextStatuses(estado))
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: getColor(next),
                                  ),
                                  onPressed: () =>
                                      _actualizarEstadoProducto(item['id'], next),
                                  child: Text(next.toUpperCase(),
                                      style: const TextStyle(color: Colors.white)),
                                ),
                              ),
                          ],
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
