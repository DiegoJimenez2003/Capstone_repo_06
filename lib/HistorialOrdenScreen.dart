import 'package:flutter/material.dart';

enum OrderStatus { pendiente, enPreparacion, listo }

class OrderItem {
  final String id;
  final String name;
  final String category;
  final int price;
  int quantity;

  OrderItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.quantity = 1,
  });
}

class Order {
  final String id;
  final int tableNumber;
  final String waiter;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime timestamp;
  final String customerGender;

  int get total => items.fold(0, (sum, item) => sum + item.price * item.quantity);

  Order({
    required this.id,
    required this.tableNumber,
    required this.waiter,
    required this.items,
    required this.status,
    required this.timestamp,
    required this.customerGender,
  });
}

class HistorialOrdenScreen extends StatefulWidget {
  final List<Order> orders;
  final VoidCallback onBack;

  const HistorialOrdenScreen({super.key, required this.orders, required this.onBack});

  @override
  State<HistorialOrdenScreen> createState() => _HistorialOrdenScreenState();
}

class _HistorialOrdenScreenState extends State<HistorialOrdenScreen> {
  String searchDate = '';
  String searchTable = '';
  String statusFilter = 'todos';

  List<Order> get historicalOrders {
    final simulatedOrders = [
      ...widget.orders,
      Order(
        id: 'hist-001',
        tableNumber: 2,
        items: [
          OrderItem(id: '1', name: 'Ensalada César', category: 'entrada', price: 12000),
          OrderItem(id: '4', name: 'Pollo a la plancha', category: 'plato', price: 25000),
          OrderItem(id: '8', name: 'Jugo de naranja', category: 'bebida', price: 8000),
        ],
        status: OrderStatus.listo,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        waiter: 'María García',
        customerGender: 'mujer',
      ),
      Order(
        id: 'hist-002',
        tableNumber: 5,
        items: [
          OrderItem(id: '2', name: 'Sopa del día', category: 'entrada', price: 10000, quantity: 2),
          OrderItem(id: '6', name: 'Pasta carbonara', category: 'plato', price: 22000),
          OrderItem(id: '9', name: 'Agua mineral', category: 'bebida', price: 5000, quantity: 2),
        ],
        status: OrderStatus.listo,
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        waiter: 'Carlos López',
        customerGender: 'hombre',
      ),
    ];
    return simulatedOrders;
  }

  List<Order> get filteredOrders {
    return historicalOrders.where((order) {
      final matchesDate = searchDate.isEmpty ||
          order.timestamp.toIso8601String().split('T')[0] == searchDate;
      final matchesTable = searchTable.isEmpty ||
          order.tableNumber.toString().contains(searchTable);
      final matchesStatus = statusFilter == 'todos' ||
          (statusFilter == 'pendiente' && order.status == OrderStatus.pendiente) ||
          (statusFilter == 'en_preparacion' && order.status == OrderStatus.enPreparacion) ||
          (statusFilter == 'listo' && order.status == OrderStatus.listo);
      return matchesDate && matchesTable && matchesStatus;
    }).toList();
  }

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return 'Pendiente';
      case OrderStatus.enPreparacion:
        return 'En preparación';
      case OrderStatus.listo:
        return 'Completado';
    }
  }

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return Colors.yellow.shade700;
      case OrderStatus.enPreparacion:
        return Colors.blue.shade700;
      case OrderStatus.listo:
        return Colors.green.shade700;
    }
  }

  String getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays} día${diff.inDays > 1 ? 's' : ''} atrás';
    if (diff.inHours > 0) return '${diff.inHours} hora${diff.inHours > 1 ? 's' : ''} atrás';
    if (diff.inMinutes > 0) return '${diff.inMinutes} min atrás';
    return 'Ahora';
  }

  @override
  Widget build(BuildContext context) {
    final totalOrders = filteredOrders.length;
    final totalSold = filteredOrders.fold(0, (sum, o) => sum + o.total);
    final avgPerOrder = totalOrders > 0 ? (totalSold ~/ totalOrders) : 0;
    final uniqueTables = filteredOrders.map((o) => o.tableNumber).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pedidos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtros
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Fecha',
                              hintText: 'YYYY-MM-DD',
                            ),
                            onChanged: (v) => setState(() => searchDate = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Mesa',
                              hintText: 'Número de mesa',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() => searchTable = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: statusFilter,
                            items: const [
                              DropdownMenuItem(value: 'todos', child: Text('Todos los estados')),
                              DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                              DropdownMenuItem(value: 'en_preparacion', child: Text('En preparación')),
                              DropdownMenuItem(value: 'listo', child: Text('Completado')),
                            ],
                            onChanged: (v) => setState(() => statusFilter = v ?? 'todos'),
                            decoration: const InputDecoration(labelText: 'Estado'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              searchDate = '';
                              searchTable = '';
                              statusFilter = 'todos';
                            });
                          },
                          child: const Text('Limpiar filtros'),
                        ),
                        const SizedBox(width: 12),
                        Text('$totalOrders pedido${totalOrders != 1 ? 's' : ''} encontrado${totalOrders != 1 ? 's' : ''}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Resumen estadístico
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              children: [
                summaryCard('Total Pedidos', '$totalOrders'),
                summaryCard('Total Vendido', '\$${totalSold.toString()}'),
                summaryCard('Promedio por Pedido', '\$${avgPerOrder.toString()}'),
                summaryCard('Mesas Atendidas', '$uniqueTables'),
              ],
            ),
            const SizedBox(height: 16),
            // Lista de pedidos
            if (filteredOrders.isEmpty)
              Center(
                child: Column(
                  children: const [
                    Icon(Icons.calendar_today, size: 60, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No se encontraron pedidos con los filtros aplicados'),
                  ],
                ),
              )
            else
              Column(
                children: filteredOrders
                    .map(
                      (order) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Pedido #${order.id} - Mesa ${order.tableNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Mesero: ${order.waiter} • ${getRelativeTime(order.timestamp)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(order.status),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(getStatusText(order.status), style: const TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Productos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        ...order.items.map((item) => Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('${item.quantity}x ${item.name}', style: const TextStyle(fontSize: 12)),
                                                Text('\$${(item.price * item.quantity).toString()}', style: const TextStyle(fontSize: 12)),
                                              ],
                                            )),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Resumen:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        summaryRow('Items', '${order.items.fold(0, (sum, i) => sum + i.quantity)}'),
                                        summaryRow('Fecha', '${order.timestamp.toLocal().toIso8601String().split('T')[0]}'),
                                        summaryRow('Hora', '${order.timestamp.toLocal().toIso8601String().split('T')[1].split('.')[0]}'),
                                        const Divider(),
                                        summaryRow('Total', '\$${order.total}'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget summaryCard(String title, String value) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(fontSize: 12)), Text(value, style: const TextStyle(fontSize: 12))],
      ),
    );
  }
}
