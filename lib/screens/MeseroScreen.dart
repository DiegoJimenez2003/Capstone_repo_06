import 'package:flutter/material.dart';
import '../servicios/supabase_service.dart';
import '../models/order_status.dart';
import '../models/mesa_status.dart';
import '../models/mesa_data.dart'; // Importamos la clase TableData desde mesa_data.dart

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

class MeseroScreen extends StatefulWidget {
  const MeseroScreen({super.key});

  @override
  State<MeseroScreen> createState() => _MeseroScreenState();
}

class _MeseroScreenState extends State<MeseroScreen> {
  final _svc = SupabaseService();
  final String waiterName = 'Mesero1';

  List<Map<String, dynamic>> myOrders = [];
  List<OrderItem> currentOrder = [];
  List<TableData> tables = [];  // Usamos TableData importada desde mesa_data.dart
  int? selectedTable;
  String customerGender = '';

  @override
  void initState() {
    super.initState();
    _cargarMesas();  // Cargar mesas desde la base de datos
    _cargarMisPedidos();
  }

  final Map<String, List<Map<String, dynamic>>> menuItems = {
    'Entradas': [
      {'id': '1', 'name': 'Ensalada', 'price': 5000},
      {'id': '2', 'name': 'Sopa', 'price': 3500},
    ],
    'Platos': [
      {'id': '3', 'name': 'Pasta', 'price': 7000},
      {'id': '4', 'name': 'Pizza', 'price': 8500},
    ],
    'Postres': [
      {'id': '5', 'name': 'Tarta', 'price': 4500},
      {'id': '6', 'name': 'Helado', 'price': 3000},
    ],
  };

  Future<void> _cargarMesas() async {
    try {
      final List<TableData> data = await _svc.fetchTables(waiterName);
      setState(() {
        tables = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar mesas: $e")),
        );
      }
    }
  }

  Future<void> _cargarMisPedidos() async {
    try {
      final data = await _svc.fetchMyOrdersWithItems(waiterName);
      setState(() {
        myOrders = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar pedidos: $e")),
        );
      }
    }
  }

  Future<void> _actualizarEstadoMesa(int tableId, String newStatus) async {
    try {
      TableStatus status = TableStatusMapper.fromDb(newStatus);
      await _svc.updateTableStatus(tableId, status);
      await _cargarMesas();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mesa actualizada")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar mesa: $e")),
      );
    }
  }

  Future<void> _marcarComoEntregado(String orderId) async {
    try {
      await _svc.updateOrderStatus(orderId, OrderStatus.entregado);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido marcado como entregado")),
      );
      await _cargarMisPedidos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al marcar como entregado: $e")),
      );
    }
  }

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendiente:
        return Colors.yellow.shade600;
      case OrderStatus.preparacion:
        return Colors.blue.shade600;
      case OrderStatus.horno:
        return Colors.orange.shade600;
      case OrderStatus.listo:
        return Colors.green.shade600;
      case OrderStatus.entregado:
        return Color.fromARGB(255, 83, 146, 228);
      case OrderStatus.cancelado:
        return Colors.red.shade600;
    }
  }

  String getStatusText(OrderStatus status) => status.label;

  void addItemToOrder(Map<String, dynamic> item, String category) {
    final idx = currentOrder.indexWhere((i) => i.id == item['id']);
    setState(() {
      if (idx >= 0) {
        currentOrder[idx].quantity++;
      } else {
        currentOrder.add(OrderItem(
          id: item['id'],
          name: item['name'],
          price: item['price'],
          category: category,
        ));
      }
    });
  }

  void removeItemFromOrder(OrderItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        currentOrder.remove(item);
      }
    });
  }

  Future<void> submitOrder() async {
    if (selectedTable == null || currentOrder.isEmpty || customerGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Completa todos los datos antes de enviar.")),
      );
      return;
    }

    try {
      final total = currentOrder.fold<int>(0, (sum, i) => sum + i.price * i.quantity);
      final orderId = await _svc.createOrder(
        tableNumber: selectedTable!,
        waiter: waiterName,
        customerGender: customerGender.toLowerCase(),
        total: total,
        status: OrderStatus.pendiente.toDb(),
      );

      final itemsRows = currentOrder.map((i) {
        return {
          'name': i.name,
          'category': i.category,
          'price': i.price,
          'quantity': i.quantity,
          'product_status': 'pendiente',
        };
      }).toList();

      await _svc.addOrderItems(orderId, itemsRows);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Pedido enviado con éxito")),
      );

      setState(() {
        currentOrder.clear();
        selectedTable = null;
        customerGender = '';
      });

      await _cargarMisPedidos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al crear pedido: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel del Mesero"),
        backgroundColor: Colors.orangeAccent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarMisPedidos),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Mesas Disponibles:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
            ),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: table.status == 'ocupada' ? Colors.grey : Colors.white,
                  foregroundColor: Colors.black,
                  side: table.status == 'ocupada' ? null : const BorderSide(color: Colors.orange),
                ),
                onPressed: table.status == 'ocupada'
                    ? null
                    : () {
                        selectedTable = table.number;
                        currentOrder.clear();
                        customerGender = '';
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => StatefulBuilder(
                            builder: (context, setDialogState) {
                              return AlertDialog(
                                title: Text('Nuevo Pedido - Mesa ${table.number}'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 400,
                                  child: Column(
                                    children: [
                                      DropdownButton<String>(
                                        value: customerGender.isEmpty ? null : customerGender,
                                        hint: const Text('Selecciona género del cliente'),
                                        items: const ['Hombre', 'Mujer']
                                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                            .toList(),
                                        onChanged: (v) => setDialogState(() {
                                          customerGender = v ?? '';
                                        }),
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
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        addItemToOrder(item, entry.key);
                                                      });
                                                    },
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      const Divider(),
                                      if (currentOrder.isNotEmpty)
                                        Expanded(
                                          child: ListView(
                                            children: currentOrder.map((item) {
                                              return ListTile(
                                                title: Text("${item.name} x${item.quantity}"),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.remove),
                                                      onPressed: () =>
                                                          setDialogState(() => removeItemFromOrder(item)),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.add),
                                                      onPressed: () =>
                                                          setDialogState(() => addItemToOrder({
                                                                'id': item.id,
                                                                'name': item.name,
                                                                'price': item.price
                                                              }, item.category)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Total: \$${currentOrder.fold<int>(0, (s, i) => s + i.price * i.quantity)}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 18),
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
                                        : () async {
                                            await submitOrder();
                                            if (mounted) Navigator.of(context).pop();
                                          },
                                    child: const Text('Enviar'),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                child: Text('Mesa ${table.number}'),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text("Mis Pedidos:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          myOrders.isEmpty
              ? const Center(child: Text("No tienes pedidos activos"))
              : Column(
                  children: myOrders.map((orderRow) {
                    final status = OrderStatusMapper.fromDb(orderRow['status'] as String);
                    final total = (orderRow['total'] as num?)?.toInt() ?? 0;
                    final items =
                        List<Map<String, dynamic>>.from(orderRow['order_items'] ?? const []); 
                    final mesa = "Mesa ${orderRow['table_number']}";

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.restaurant),
                              title: Text(mesa),
                              subtitle: Text("${items.length} productos - \$${total.toString()}"),
                              trailing: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: getStatusColor(status),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  getStatusText(status),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (status != OrderStatus.entregado)
                              Center(
                                child: ElevatedButton(
                                  onPressed: () => _marcarComoEntregado(orderRow['id'].toString()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 83, 146, 228),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    minimumSize: const Size(100, 36),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    "Entregado",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
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
}
