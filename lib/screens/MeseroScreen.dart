import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../servicios/supabase_service.dart';
import '../models/order_status.dart';
import '../models/mesa_status.dart';
import '../models/mesa_data.dart';
import 'LoginScreen.dart';
import 'package:intl/intl.dart'; // Para formatear CLP

class OrderItem {
  final int idProducto;
  final String name;
  final double price;
  final String category;
  int quantity;
  OrderStatus productStatus;

  OrderItem({
    required this.idProducto,
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
  int? _currentWaiterId;
  String _currentWaiterEmail = '';

  List<Map<String, dynamic>> myOrders = [];
  List<OrderItem> currentOrder = [];
  List<TableData> tables = [];
  int? selectedTable;
  String customerGender = '';

  List<Map<String, dynamic>> _productos = [];
  bool _loadingProductos = false;

  @override
  void initState() {
    super.initState();
    _initializeMeseroData();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    setState(() => _loadingProductos = true);
    try {
      final data = await _svc.fetchProductos();
      setState(() => _productos = data);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error al cargar productos: $e")));
    } finally {
      setState(() => _loadingProductos = false);
    }
  }

  Future<void> _initializeMeseroData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuario no autenticado.")),
      );
      return;
    }

    _currentWaiterEmail = user.email!;
    try {
      final profileData = await _svc.fetchMeseroProfile(_currentWaiterEmail);
      if (profileData == null) return;

      setState(() => _currentWaiterId = profileData['id_usuario'] as int);
      await _cargarMesas();
      await _cargarMisPedidos();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _cargarMesas() async {
    if (_currentWaiterId == null) return;
    try {
      final data = await _svc.fetchTables(_currentWaiterId!);
      setState(() => tables = data);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _cargarMisPedidos() async {
    if (_currentWaiterId == null) return;
    try {
      final data =
          await _svc.fetchMyOrdersWithItems(_currentWaiterId!.toString());
      setState(() => myOrders = data);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> submitOrder() async {
    if (selectedTable == null ||
        currentOrder.isEmpty ||
        customerGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Completa todos los datos.")),
      );
      return;
    }

    try {
      final total = currentOrder.fold<double>(
          0, (sum, item) => sum + item.price * item.quantity);

      final orderId = await _svc.createOrder(
        tableNumber: selectedTable!,
        waiterId: _currentWaiterId.toString(),
        customerGender: customerGender.toLowerCase(),
        total: total.toInt(),
        status: OrderStatus.pendiente.toDb(),
      );

      final detalle = currentOrder.map((i) {
        return {
          'nombre_producto': i.name,
          'categoria': i.category,
          'precio': i.price,
          'cantidad': i.quantity,
          'estado_producto': 'pendiente',
        };
      }).toList();

      await _svc.addOrderItems(orderId, detalle);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Pedido creado con éxito")),
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

  void addItemToOrder(Map<String, dynamic> producto) {
    final idx =
        currentOrder.indexWhere((i) => i.idProducto == producto['id_producto']);
    setState(() {
      if (idx >= 0) {
        currentOrder[idx].quantity++;
      } else {
        currentOrder.add(OrderItem(
          idProducto: producto['id_producto'],
          name: producto['nombre_producto'] ?? 'Sin nombre',
          price: (producto['precio'] as num).toDouble(),
          category: producto['categoria'] ?? 'Sin categoría',
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

  /// 🔹 Marcar pedido como entregado
  Future<void> _marcarComoEntregado(String orderId) async {
    try {
      await _svc.updateOrderStatus(orderId, OrderStatus.entregado);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🍽️ Pedido marcado como entregado")),
      );
      await _cargarMisPedidos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al actualizar estado: $e")),
      );
    }
  }

  /// 🔹 Cerrar sesión y volver al login
  Future<void> _cerrarSesion() async {
    try {
      await _svc.logOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("👋 Sesión cerrada correctamente")),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Loginscreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error al cerrar sesión: $e")));
    }
  }

  // ==================== INTERFAZ ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Panel del Mesero (${_currentWaiterEmail})"),
        backgroundColor: Colors.orangeAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Loginscreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              _initializeMeseroData();
              _loadProductos();
            },
          ),
        ],
      ),
      body: _loadingProductos
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Mesas Disponibles:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // --- MESAS ---
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
                        backgroundColor:
                            table.status == 'ocupada' ? Colors.grey : Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.orange),
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
                                        height: 450,
                                        child: Column(
                                          children: [
                                            DropdownButton<String>(
                                              value: customerGender.isEmpty ? null : customerGender,
                                              hint: const Text('Género del cliente'),
                                              items: const [
                                                DropdownMenuItem(
                                                    value: 'Hombre', child: Text('Hombre')),
                                                DropdownMenuItem(
                                                    value: 'Mujer', child: Text('Mujer')),
                                              ],
                                              onChanged: (v) =>
                                                  setDialogState(() => customerGender = v ?? ''),
                                            ),
                                            const SizedBox(height: 10),
                                            Expanded(
                                              child: ListView(
                                                children: _productos.isEmpty
                                                    ? [const Text("No hay productos disponibles")]
                                                    : _productos
                                                        .fold<Map<String, List<Map<String, dynamic>>>>({}, (map, p) {
                                                            final cat = p['categoria'] ?? 'Sin categoría';
                                                            map.putIfAbsent(cat, () => []);
                                                            map[cat]!.add(p);
                                                            return map;
                                                          })
                                                        .entries
                                                        .map((entry) => ExpansionTile(
                                                              title: Text(entry.key.toUpperCase()),
                                                              children: entry.value.map((producto) {
                                                                return ListTile(
                                                                  title: Text(producto['nombre_producto']),
                                                                  subtitle: Text(
                                                                    NumberFormat.currency(
                                                                            locale: 'es_CL',
                                                                            symbol: '\$',
                                                                            decimalDigits: 0)
                                                                        .format(producto['precio']),
                                                                  ),
                                                                  trailing: IconButton(
                                                                    icon: const Icon(Icons.add_circle),
                                                                    onPressed: () {
                                                                      setDialogState(() => addItemToOrder(producto));
                                                                    },
                                                                  ),
                                                                );
                                                              }).toList(),
                                                            ))
                                                        .toList(),
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
                                                            onPressed: () => setDialogState(() => removeItemFromOrder(item)),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.add),
                                                            onPressed: () => setDialogState(() => addItemToOrder({
                                                              'id_producto': item.idProducto,
                                                              'nombre_producto': item.name,
                                                              'precio': item.price,
                                                              'categoria': item.category,
                                                            })),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Total: ${NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0).format(currentOrder.fold<double>(0, (s, i) => s + i.price * i.quantity))}",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold, fontSize: 18),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: currentOrder.isEmpty
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

                // 🔹 Pedidos existentes (con botón de entregado)
                const Text("Mis Pedidos:",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                myOrders.isEmpty
                    ? const Center(child: Text("No tienes pedidos activos"))
                    : Column(
                        children: myOrders.map((orderRow) {
                          final itemsData = List<Map<String, dynamic>>.from(orderRow['detalle_pedido'] ?? const []);
                          final total = (orderRow['total'] as num?)?.toInt() ?? 0;
                          final status = OrderStatusMapper.fromDb(orderRow['estado']?.toString() ?? 'pendiente');
                          final mesa = "Mesa ${orderRow['numero_mesa']}";

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text("$mesa - ${NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0).format(total)}"),
                              subtitle: Text("${itemsData.length} productos - ${status.label}"),
                              trailing: status == OrderStatus.entregado
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                                      icon: const Icon(Icons.check),
                                      label: const Text("Entregado"),
                                      onPressed: () async {
                                        await _marcarComoEntregado(orderRow['id']);
                                      },
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
