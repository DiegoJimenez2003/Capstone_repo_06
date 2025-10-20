import 'package:flutter/material.dart';

enum OrderStatus { pendiente, enPreparacion, listo, cancelado }

class OrderItem {
  final String id;
  final String name;
  final int price;
  final String category;
  int quantity;
  OrderStatus productStatus;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.quantity = 1,
    this.productStatus = OrderStatus.pendiente,
  });
}

class Order {
  final String id;
  final int tableNumber;
  final List<int>? tableNumbers;
  final String waiter;
  List<OrderItem> items;
  OrderStatus status;
  final DateTime timestamp;
  int total;

  Order({
    required this.id,
    required this.tableNumber,
    this.tableNumbers,
    required this.waiter,
    required this.items,
    this.status = OrderStatus.pendiente,
    required this.timestamp,
  }) : total = items.fold(0, (sum, item) => sum + item.price * item.quantity);
}

class TableData {
  final int number;
  final bool occupied;
  final String? waiter;
  final List<int>? groupedWith;

  TableData({required this.number, this.occupied = false, this.waiter, this.groupedWith});
}

class MeseroScreen extends StatefulWidget {
  const MeseroScreen({super.key});

  @override
  State<MeseroScreen> createState() => _MeseroScreenState();
}

class _MeseroScreenState extends State<MeseroScreen> {
  List<TableData> tables = List.generate(
    6,
    (index) => TableData(number: index + 1),
  );

  List<Order> orders = [];

  int? selectedTable;
  List<OrderItem> currentOrder = [];
  String customerGender = '';

  final Map<String, List<Map<String, dynamic>>> menuItems = {
    'entrada': [
      {'id': '1', 'name': 'Ensalada César', 'price': 12000},
      {'id': '2', 'name': 'Sopa del día', 'price': 10000},
    ],
    'plato': [
      {'id': '3', 'name': 'Pollo a la plancha', 'price': 25000},
      {'id': '4', 'name': 'Pescado al horno', 'price': 30000},
    ],
    'bebida': [
      {'id': '5', 'name': 'Jugo de naranja', 'price': 8000},
      {'id': '6', 'name': 'Café', 'price': 4000},
    ],
    'postre': [
      {'id': '7', 'name': 'Tiramisú', 'price': 15000},
      {'id': '8', 'name': 'Helado', 'price': 10000},
    ],
  };

  void addItemToOrder(Map<String, dynamic> item, String category) {
    final existingItem = currentOrder.where((i) => i.id == item['id']).toList();
    if (existingItem.isNotEmpty) {
      setState(() {
        existingItem.first.quantity += 1;
      });
    } else {
      setState(() {
        currentOrder.add(OrderItem(
          id: item['id'],
          name: item['name'],
          price: item['price'],
          category: category,
        ));
      });
    }
  }

  void removeItem(OrderItem item) {
    setState(() {
      currentOrder.remove(item);
    });
  }

  void submitOrder() {
    if (selectedTable != null && currentOrder.isNotEmpty && customerGender.isNotEmpty) {
      final newOrder = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tableNumber: selectedTable!,
        waiter: 'Mesero1',
        items: List.from(currentOrder),
        timestamp: DateTime.now(),
      );
      setState(() {
        orders.add(newOrder);
        currentOrder.clear();
        selectedTable = null;
        customerGender = '';
      });
    }
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

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return 'Pendiente';
      case OrderStatus.enPreparacion:
        return 'En preparación';
      case OrderStatus.listo:
        return 'Listo';
      case OrderStatus.cancelado:
        return 'Cancelado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myOrders = orders.where((o) => o.waiter == 'Mesero1' && o.status != OrderStatus.cancelado).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel del Mesero"),
        backgroundColor: Colors.orangeAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Mesas Disponibles:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: table.occupied ? Colors.grey : Colors.white,
                  foregroundColor: Colors.black,
                  side: table.occupied ? null : const BorderSide(color: Colors.orange),
                ),
                onPressed: table.occupied
                    ? null
                    : () {
                        setState(() {
                          selectedTable = table.number;
                          currentOrder.clear();
                        });
                        showDialog(
                          context: context,
                          builder: (context) => orderDialog(),
                        );
                      },
                child: Text('Mesa ${table.number}'),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text("Mis Pedidos:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          myOrders.isEmpty
              ? const Center(child: Text("No tienes pedidos activos"))
              : Column(
                  children: myOrders.map((order) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.restaurant),
                        title: Text(order.tableNumbers != null
                            ? "Mesa ${order.tableNumbers!.join(' + ')}"
                            : "Mesa ${order.tableNumber}"),
                        subtitle: Text("${order.items.length} productos - \$${order.total}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: getStatusColor(order.status),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                getStatusText(order.status),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (order.status == OrderStatus.pendiente)
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {},
                              ),
                            if (order.status == OrderStatus.pendiente)
                              IconButton(
                                icon: const Icon(Icons.cancel),
                                onPressed: () {
                                  setState(() {
                                    order.status = OrderStatus.cancelado;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget orderDialog() {
    return AlertDialog(
      title: Text('Nuevo Pedido - Mesa $selectedTable'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: customerGender.isEmpty ? null : customerGender,
              hint: const Text('Selecciona género del cliente'),
              items: ['Hombre', 'Mujer'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (value) {
                setState(() {
                  customerGender = value ?? '';
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: menuItems.entries.map((entry) {
                  return ExpansionTile(
                    title: Text(entry.key.toUpperCase()),
                    children: entry.value.map((item) {
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text('\$${item['price']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => addItemToOrder(item, entry.key),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
            if (currentOrder.isNotEmpty)
              Column(
                children: currentOrder.map((item) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${item.name} x${item.quantity}"),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.remove), onPressed: () {
                            setState(() {
                              if (item.quantity > 1) {
                                item.quantity--;
                              } else {
                                currentOrder.remove(item);
                              }
                            });
                          }),
                          IconButton(icon: const Icon(Icons.add), onPressed: () {
                            setState(() {
                              item.quantity++;
                            });
                          }),
                        ],
                      )
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: customerGender.isEmpty || currentOrder.isEmpty
                ? null
                : () {
                    submitOrder();
                    Navigator.of(context).pop();
                  },
            child: const Text('Enviar')),
      ],
    );
  }
}
