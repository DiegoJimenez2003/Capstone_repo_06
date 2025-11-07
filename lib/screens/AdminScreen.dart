import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_status.dart';
import '../servicios/supabase_service.dart';
import 'LoginScreen.dart'; 

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _svc = SupabaseService();
  
  // Métricas del Dashboard
  int _todayOrders = 0;
  double _todayRevenue = 0.0;
  int _activeOrders = 0;
  
  // Lista de pedidos activos para mostrar
  List<Map<String, dynamic>> _activeOrdersList = [];

  @override
  void initState() {
    super.initState();
    // Llama a la función de carga al iniciar
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    // Resetear métricas antes de calcular
    _todayOrders = 0;
    _todayRevenue = 0.0;

    final today = DateTime.now();
    // Definimos el inicio del día para filtrar pedidos de hoy
    final todayStart = DateTime(today.year, today.month, today.day);
    
    try {
      // Usamos la función del servicio que trae todos los pedidos
      final allOrders = await _svc.fetchAllOrdersWithItems();

      int ordersCount = 0;
      double revenue = 0.0;
      int active = 0;
      List<Map<String, dynamic>> tempActiveList = [];

      for (var order in allOrders) {
        // Hacemos el parsing robusto de las columnas en español
        final rawDate = order['fecha_pedido'] as String?;
        final status = order['estado'] as String?;
        final total = (order['total'] as num?)?.toDouble() ?? 0.0; // Usamos double

        if (rawDate == null || status == null) continue;

        final orderDate = DateTime.tryParse(rawDate);
        if (orderDate == null) continue;

        // 1. Calcular pedidos e ingresos de hoy
        // La comparación debe ser estricta con UTC o con Huso Horario si es posible.
        if (orderDate.isAfter(todayStart)) {
          ordersCount++;
          revenue += total;
        }

        // 2. Determinar pedidos activos (Pendiente, Preparación, Horno, Listo)
        final isCompletedOrCanceled = status == 'entregado' || status == 'cancelado';
        if (!isCompletedOrCanceled) {
          active++;
          tempActiveList.add(order);
        }
      }

      // Actualizamos el estado de las métricas en la UI
      if (mounted) {
        setState(() {
          _todayOrders = ordersCount;
          _todayRevenue = revenue;
          _activeOrders = active;
          _activeOrdersList = tempActiveList;
        });
      }
    } catch (e) {
      if (mounted) {
        // Muestra el error exacto en la snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al cargar métricas del Admin: $e")),
        );
        setState(() {
          _activeOrders = 0;
          _activeOrdersList = [];
        });
      }
    }
  }

  // Cierra la sesión y navega a la pantalla de Login
  Future<void> _logOut() async {
    await _svc.logOut();
    if (mounted) {
      // Usamos Navigator.pushAndRemoveUntil para limpiar la pila de navegación
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Loginscreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(FontAwesomeIcons.chartLine, color: Colors.deepOrangeAccent),
            SizedBox(width: 10),
            Text(
              "Panel del Administrador",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMetrics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              const Text(
                "Resumen del Sistema",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Tarjetas de métricas principales
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricCard(
                    icon: FontAwesomeIcons.receipt,
                    color: Colors.blueAccent,
                    title: "Pedidos de Hoy",
                    value: "${_todayOrders}", // Métrica real
                  ),
                  _buildMetricCard(
                    icon: FontAwesomeIcons.dollarSign,
                    color: Colors.green,
                    title: "Ingresos (Total)",
                    value: "\$${_todayRevenue.toStringAsFixed(0)}", // Métrica real
                  ),
                  _buildMetricCard(
                    icon: FontAwesomeIcons.clock,
                    color: Colors.orange,
                    title: "Tiempo Promedio",
                    value: "N/A min", // Dejado como N/A
                  ),
                  _buildMetricCard(
                    icon: FontAwesomeIcons.users,
                    color: Colors.purple,
                    title: "Pedidos Activos",
                    value: "${_activeOrders}", // Métrica real
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Divider(),

              // Lista de pedidos activos
              const SizedBox(height: 20),
              Text(
                "Pedidos Activos (${_activeOrders})",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (_activeOrdersList.isEmpty)
                const Center(child: Text("No hay pedidos pendientes o en preparación."))
              else
                Column(
                  children: _activeOrdersList.map((order) {
                    final status = OrderStatusMapper.fromDb(order['estado']?.toString() ?? 'pendiente');
                    final total = (order['total'] as num?)?.toInt() ?? 0;
                    final mesa = "Mesa ${order['numero_mesa']}"; 
                    final meseroId = order['mesero_id']?.toString() ?? 'N/A';
                    
                    // Contar los ítems anidados en la lista 'detalle_pedido'
                    final itemsCount = order['detalle_pedido'] is List 
                        ? (order['detalle_pedido'] as List).length 
                        : 0;
                    
                    return _buildOrderCard(
                      mesa,
                      "Mesero ID: ${meseroId}",
                      itemsCount, // Cantidad de ítems
                      total, 
                      order['estado']?.toString() ?? 'pendiente',
                    );
                  }).toList(),
                ),

              const SizedBox(height: 40),

              // Botón de Cerrar Sesión
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
        ),
      ),
    );
  }

  // --- Widgets auxiliares ---

  Widget _buildMetricCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(String mesa, String mesero, int items, int total, String estado) {
    final normalized = OrderStatusMapper.normalize(estado);
    final status = OrderStatusMapper.fromDb(normalized);
    final color = _statusColor(status);
    final label = status == OrderStatus.cancelado ? 'Cancelado' : status.label;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.restaurant_menu, color: color),
        ),
        title: Text(mesa),
        subtitle: Text("$mesero - $items productos\nTotal: \$${total.toStringAsFixed(0)}"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return Colors.amber;
      case OrderStatus.preparacion:
        return Colors.blueAccent;
      case OrderStatus.horno:
        return Colors.deepOrange;
      case OrderStatus.listo:
        return Colors.green;
      case OrderStatus.entregado:
        return Colors.purple;
      case OrderStatus.cancelado:
        return Colors.redAccent;
    }
  }
}
