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

  // --- Métricas del Dashboard (LO QUE YA TENÍAS) ---
  int _todayOrders = 0;
  double _todayRevenue = 0.0;
  int _activeOrders = 0;
  List<Map<String, dynamic>> _activeOrdersList = [];

  // --- NUEVO: Estado para Productos ---
  List<Map<String, dynamic>> _productos = [];
  bool _loadingProductos = false;

  // --- NUEVO: controladores del form de producto ---
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  String _disponible = 'S';

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _loadProductos(); // NUEVO: traer catálogo al entrar
  }

  // ---------------- MÉTRICAS / PEDIDOS  ----------------
  Future<void> _loadMetrics() async {
    _todayOrders = 0;
    _todayRevenue = 0.0;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    try {
      final allOrders = await _svc.fetchAllOrdersWithItems();

      int ordersCount = 0;
      double revenue = 0.0;
      int active = 0;
      List<Map<String, dynamic>> tempActiveList = [];

      for (var order in allOrders) {
        final rawDate = order['fecha_pedido'] as String?;
        final status = order['estado'] as String?;
        final total = (order['total'] as num?)?.toDouble() ?? 0.0;

        if (rawDate == null || status == null) continue;

        final orderDate = DateTime.tryParse(rawDate);
        if (orderDate == null) continue;

        if (orderDate.isAfter(todayStart)) {
          ordersCount++;
          revenue += total;
        }

        final isCompletedOrCanceled =
            status == 'entregado' || status == 'cancelado';
        if (!isCompletedOrCanceled) {
          active++;
          tempActiveList.add(order);
        }
      }

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

  // ---------------- NUEVO: CRUD BÁSICO DE PRODUCTOS ----------------
  Future<void> _loadProductos() async {
    setState(() => _loadingProductos = true);
    try {
      final data = await Supabase.instance.client
          .from('producto')
          .select()
          .order('id_producto', ascending: true);

      setState(() {
        _productos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al cargar productos: $e")),
      );
    } finally {
      setState(() => _loadingProductos = false);
    }
  }

  Future<void> _crearProducto() async {
    final nombre = _nombreCtrl.text.trim();
    final precio = double.tryParse(_precioCtrl.text.trim());
    final categoria = _categoriaCtrl.text.trim();
    final disponible = _disponible; // 'S' | 'N'

    if (nombre.isEmpty || precio == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Completa Nombre y Precio correctamente.')));
      return;
    }

    try {
      await Supabase.instance.client.from('producto').insert({
        'nombre_producto': nombre,
        'precio': precio,
        'categoria': categoria.isEmpty ? null : categoria,
        'disponible': disponible,
      });

      // limpiar form + recargar
      _nombreCtrl.clear();
      _precioCtrl.clear();
      _categoriaCtrl.clear();
      _disponible = 'S';

      if (mounted) {
        Navigator.pop(context); // cerrar sheet
        await _loadProductos();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Producto agregado correctamente.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al crear producto: $e')),
      );
    }
  }

  void _abrirSheetNuevoProducto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Agregar nuevo producto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _campoTexto(
                controller: _nombreCtrl,
                label: 'Nombre del producto *',
                icon: Icons.fastfood,
              ),
              const SizedBox(height: 10),
              _campoTexto(
                controller: _precioCtrl,
                label: 'Precio *',
                icon: Icons.attach_money,
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _campoTexto(
                controller: _categoriaCtrl,
                label: 'Categoría (opcional)',
                icon: Icons.category,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.toggle_on, color: Colors.deepOrangeAccent),
                  const SizedBox(width: 8),
                  const Text('Disponible'),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _disponible,
                    items: const [
                      DropdownMenuItem(value: 'S', child: Text('Sí')),
                      DropdownMenuItem(value: 'N', child: Text('No')),
                    ],
                    onChanged: (v) => setState(() => _disponible = v ?? 'S'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _crearProducto,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Guardar',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.deepOrangeAccent),
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ---------------- UI ----------------
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirSheetNuevoProducto, // NUEVO
        backgroundColor: Colors.deepOrangeAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Agregar producto', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadMetrics();
          await _loadProductos();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Encabezado ----------
              const Text(
                "Resumen del Sistema",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // ---------- Tarjetas de métricas ----------
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
                    value: "${_todayOrders}",
                  ),
                  _buildMetricCard(
                    icon: FontAwesomeIcons.dollarSign,
                    color: Colors.green,
                    title: "Ingresos (Total)",
                    value: "\$${_todayRevenue.toStringAsFixed(0)}",
                  ),
                  _buildMetricCard(
                    icon: FontAwesomeIcons.clock,
                    color: Colors.orange,
                    title: "Tiempo Promedio",
                    value: "N/A min",
                  ),
                  _buildMetricCard(
                    icon: FontAwesomeIcons.users,
                    color: Colors.purple,
                    title: "Pedidos Activos",
                    value: "${_activeOrders}",
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Divider(),

              // ---------- Lista de pedidos activos ----------
              const SizedBox(height: 20),
              Text(
                "Pedidos Activos (${_activeOrders})",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (_activeOrdersList.isEmpty)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("No hay pedidos pendientes o en preparación."),
                ))
              else
                Column(
                  children: _activeOrdersList.map((order) {
                    final status = OrderStatusMapper.fromDb(
                        order['estado']?.toString() ?? 'pendiente');
                    final total = (order['total'] as num?)?.toInt() ?? 0;
                    final mesa = "Mesa ${order['numero_mesa']}";
                    final meseroId = order['mesero_id']?.toString() ?? 'N/A';

                    final itemsCount = order['detalle_pedido'] is List
                        ? (order['detalle_pedido'] as List).length
                        : 0;

                    return _buildOrderCard(
                      mesa,
                      "Mesero ID: $meseroId",
                      itemsCount,
                      total,
                      order['estado']?.toString() ?? 'pendiente',
                    );
                  }).toList(),
                ),

              const SizedBox(height: 30),
              const Divider(),

              // ---------- NUEVO: Catálogo de productos ----------
              const SizedBox(height: 16),
              const Text(
                "Catálogo de productos",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_loadingProductos)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_productos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("Aún no hay productos. ¡Creá el primero con el botón +!"),
                )
              else
                GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: _productos.length,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 0.9, // 🔽 antes era 1.2, esto da más alto y evita overflow
  ),
  itemBuilder: (context, i) {
    final p = _productos[i];
    return _buildProductCard(
      nombre: p['nombre_producto'] ?? 'Sin nombre',
      categoria: p['categoria'] ?? 'Sin categoría',
      precio: (p['precio'] as num?)?.toDouble() ?? 0.0,
      disponible: (p['disponible']?.toString() ?? 'S') == 'S',
    );
  },
),

              const SizedBox(height: 40),

              // ---------- Botón de Cerrar Sesión ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _logOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.logout, color: Colors.black87),
                    label: const Text("Cerrar Sesión",
                        style: TextStyle(color: Colors.black87)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Widgets auxiliares ----------------
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

  Widget _buildOrderCard(
      String mesa, String mesero, int items, int total, String estado) {
    final normalized = OrderStatusMapper.normalize(estado);
    final status = OrderStatusMapper.fromDb(normalized);
    final color = _statusColor(status);
    final label =
        status == OrderStatus.cancelado ? 'Cancelado' : status.label;

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
        subtitle:
            Text("$mesero - $items productos\nTotal: \$${total.toStringAsFixed(0)}"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // NUEVO: Tarjeta para producto
  Widget _buildProductCard({
    required String nombre,
    required String categoria,
    required double precio,
    required bool disponible,
  }) {
    final chipColor =
        disponible ? Colors.green : Colors.redAccent;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icono
            Container(
              decoration: BoxDecoration(
                color: Colors.deepOrangeAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.fastfood, color: Colors.deepOrangeAccent),
            ),
            const SizedBox(height: 10),
            Text(nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text("Categoría: $categoria",
                style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            Row(
              children: [
                Text("\$${precio.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(disponible ? 'Disponible' : 'No disp.',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
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
