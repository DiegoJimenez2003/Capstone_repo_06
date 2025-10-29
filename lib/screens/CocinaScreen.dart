import 'package:flutter/material.dart';

enum OrderStatus { pendiente, enPreparacion, listo, cancelado }

class OrderItem {
  final String name;
  final int quantity;
  OrderItem({required this.name, required this.quantity});
}

class Order {
  final String id;
  final int tableNumber;
  final String waiter;
  OrderStatus status;
  final DateTime timestamp;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.tableNumber,
    required this.waiter,
    this.status = OrderStatus.pendiente,
    required this.timestamp,
    required this.items,
  });
}

class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  List<Order> orders = [
    Order(
      id: '001',
      tableNumber: 1,
      waiter: 'Carlos',
      items: [
        OrderItem(name: 'Lomo Saltado', quantity: 2),
        OrderItem(name: 'Jugo Natural', quantity: 1),
      ],
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Order(
      id: '002',
      tableNumber: 3,
      waiter: 'Ana',
      items: [
        OrderItem(name: 'Ensalada César', quantity: 1),
      ],
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  // Cambiar estado del pedido
  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    setState(() {
      final order = orders.firstWhere((o) => o.id == orderId);
      order.status = newStatus;
    });
  }

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return Colors.yellow.shade600;
      case OrderStatus.enPreparacion:
        return Colors.blue.shade600;
      case OrderStatus.listo:
        return Colors.green.shade600;
      case OrderStatus.cancelado:
        return Colors.red.shade600;
    }
  }

  IconData getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return Icons.access_time;
      case OrderStatus.enPreparacion:
        return Icons.kitchen;
      case OrderStatus.listo:
        return Icons.check_circle;
      case OrderStatus.cancelado:
        return Icons.cancel;
    }
  }

  String getElapsedTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    return '${diff.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final pendingOrders =
        orders.where((o) => o.status == OrderStatus.pendiente).toList();
    final preparingOrders =
        orders.where((o) => o.status == OrderStatus.enPreparacion).toList();
    final readyOrders = orders.where((o) => o.status == OrderStatus.listo).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel del Cocinero"),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pendingOrders.isNotEmpty)
            Section(
              title: "Pedidos Pendientes",
              icon: Icons.access_time,
              orders: pendingOrders,
              onUpdateStatus: updateOrderStatus,
              nextStatus: OrderStatus.enPreparacion,
            ),
          if (preparingOrders.isNotEmpty)
            Section(
              title: "En Preparación",
              icon: Icons.kitchen,
              orders: preparingOrders,
              onUpdateStatus: updateOrderStatus,
              nextStatus: OrderStatus.listo,
            ),
          if (readyOrders.isNotEmpty)
            Section(
              title: "Listos para Servir",
              icon: Icons.check_circle,
              orders: readyOrders,
              onUpdateStatus: null, // ya no se puede actualizar
            ),
          if (orders.isEmpty)
            Center(
              child: Column(
                children: const [
                  SizedBox(height: 50),
                  Icon(Icons.kitchen, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text("No hay pedidos en este momento",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Order> orders;
  final void Function(String orderId, OrderStatus status)? onUpdateStatus;
  final OrderStatus? nextStatus;

  const Section({
    super.key,
    required this.title,
    required this.icon,
    required this.orders,
    this.onUpdateStatus,
    this.nextStatus,
  });

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return Colors.yellow.shade600;
      case OrderStatus.enPreparacion:
        return Colors.blue.shade600;
      case OrderStatus.listo:
        return Colors.green.shade600;
      case OrderStatus.cancelado:
        return Colors.red.shade600;
    }
  }

  IconData getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return Icons.access_time;
      case OrderStatus.enPreparacion:
        return Icons.kitchen;
      case OrderStatus.listo:
        return Icons.check_circle;
      case OrderStatus.cancelado:
        return Icons.cancel;
    }
  }

  String getElapsedTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    return '${diff.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: orders.map((order) {
            return Card(
              child: ListTile(
                leading: Icon(getStatusIcon(order.status), color: getStatusColor(order.status)),
                title: Text("Pedido #${order.id} - Mesa ${order.tableNumber}"),
                subtitle: Text(order.items.map((i) => "${i.quantity}x ${i.name}").join(", ") +
                    " • ${getElapsedTime(order.timestamp)}"),
                trailing: onUpdateStatus != null && nextStatus != null
                    ? ElevatedButton(
                        onPressed: () => onUpdateStatus!(order.id, nextStatus!),
                        child: Text(nextStatus == OrderStatus.enPreparacion
                            ? "Iniciar"
                            : "Marcar listo"),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
