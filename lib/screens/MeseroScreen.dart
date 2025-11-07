import 'package:flutter/material.dart';
// Importamos Supabase para obtener el ID de usuario
import 'package:supabase_flutter/supabase_flutter.dart'; 

import '../servicios/supabase_service.dart';
import '../models/order_status.dart';
import '../models/mesa_status.dart';
import '../models/mesa_data.dart'; 

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
  
  // Guardaremos el ID del mesero (INTEGER de la tabla 'usuario') y su email
  int? _currentWaiterId; 
  String _currentWaiterEmail = '';

  List<Map<String, dynamic>> myOrders = [];
  List<OrderItem> currentOrder = [];
  List<TableData> tables = [];  
  int? selectedTable;
  String customerGender = '';

  @override
  void initState() {
    super.initState();
    // Iniciamos el proceso de obtener el ID de perfil y cargar datos
    _initializeMeseroData(); 
  }

  /// Inicializa los datos, obteniendo el ID del mesero de la tabla 'usuario'.
  Future<void> _initializeMeseroData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Usuario no autenticado o email no disponible.")),
        );
      }
      return;
    }
    
    _currentWaiterEmail = user.email!;

    try {
      // 1. Obtener el id_usuario (INTEGER) usando el email
      final profileData = await _svc.fetchMeseroProfile(_currentWaiterEmail);

      if (profileData == null || profileData['id_usuario'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: Perfil de mesero no encontrado para ${_currentWaiterEmail}. Asegúrese de que el correo esté en la tabla 'usuario'.")),
          );
        }
        return;
      }

      setState(() {
        _currentWaiterId = profileData['id_usuario'] as int;
      });

      // 2. Cargar datos usando el ID INTEGER
      await _cargarMesas(); 
      await _cargarMisPedidos();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al inicializar datos: $e")),
        );
      }
    }
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
    if (_currentWaiterId == null) return; 
    try {
      // Usa el ID INTEGER para filtrar por 'id_mesero' en la tabla 'mesa'
      final List<TableData> data = await _svc.fetchTables(_currentWaiterId!); 
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

  /// Carga los pedidos activos del mesero, filtrando por su ID (como String).
  Future<void> _cargarMisPedidos() async {
    if (_currentWaiterId == null) return; 

    try {
      // Enviamos el ID del mesero (INT) como String al campo 'mesero_id' en pedidos.
      final data = await _svc.fetchMyOrdersWithItems(_currentWaiterId!.toString()); 
      setState(() {
        myOrders = data;
      });
    } catch (e) {
      if (mounted) {
        myOrders = [];
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mesa actualizada")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar mesa: $e")),
        );
      }
    }
  }

  Future<void> _marcarComoEntregado(String orderId) async {
    try {
      await _svc.updateOrderStatus(orderId, OrderStatus.entregado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pedido marcado como entregado")),
        );
      }
      await _cargarMisPedidos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al marcar como entregado: $e")),
        );
      }
    }
  }

  /// Prepara y envía la nueva orden a Supabase.
  Future<void> submitOrder() async {
    if (selectedTable == null || currentOrder.isEmpty || customerGender.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Completa todos los datos.")),
        );
      }
      return;
    }
    
    final currentWaiterId = _currentWaiterId;

    if (currentWaiterId == null) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: ID del mesero no disponible para enviar pedido.")),
            );
        }
        return;
    }

    try {
      final total = currentOrder.fold<int>(0, (sum, i) => sum + i.price * i.quantity);
      
      // 1. Crear pedido usando los nombres de columnas del servicio (en español)
      final orderId = await _svc.createOrder(
        tableNumber: selectedTable!,
        waiterId: currentWaiterId.toString(), // mesero_id (INT como String)
        customerGender: customerGender.toLowerCase(),
        total: total,
        status: OrderStatus.pendiente.toDb(),
      );

      // 2. Mapeo para la tabla `detalle_pedido` (usando claves en inglés para el mapeo del servicio)
      final itemsRows = currentOrder.map((i) {
        return {
          'name': i.name, // Se mapea a 'nombre_producto'
          'price': i.price, // Se mapea a 'precio'
          'quantity': i.quantity, // Se mapea a 'cantidad'
          'category': i.category, // Se mapea a 'categoria'
          'product_status': 'pendiente', // Se mapea a 'estado_producto'
        };
      }).toList();

      await _svc.addOrderItems(orderId, itemsRows);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Pedido enviado con éxito")),
        );
      }

      setState(() {
        currentOrder.clear();
        selectedTable = null;
        customerGender = '';
      });

      // Recargar pedidos para ver la nueva orden
      await _cargarMisPedidos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al crear pedido: $e")),
        );
      }
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
        return const Color.fromARGB(255, 83, 146, 228);
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
          price: item['price'] is int ? item['price'] : (item['price'] as num).toInt(),
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Mostramos el email en la barra para debug y confirmación
        title: Text("Panel del Mesero (${_currentWaiterEmail})"),
        backgroundColor: Colors.orangeAccent,
        actions: [
          // Al presionar refresh, inicializamos de nuevo para obtener el ID y las mesas
          IconButton(icon: const Icon(Icons.refresh), onPressed: _initializeMeseroData),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Mesas Disponibles:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_currentWaiterId == null && tables.isEmpty) 
            const Center(child: CircularProgressIndicator()) 
          else 
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
                    // Usamos la relación anidada a 'detalle_pedido'
                    final itemsData = List<Map<String, dynamic>>.from(orderRow['detalle_pedido'] ?? const []); 
                    
                    int totalItems = 0;
                    final total = (orderRow['total'] as num?)?.toInt() ?? 0;
                    
                    final List<Map<String, dynamic>> processedItems = itemsData.map((itemDetail) {
                        // Accedemos a las columnas renombradas en español
                        final name = itemDetail['nombre_producto'] ?? 'Producto Desconocido';
                        final quantity = (itemDetail['cantidad'] as num?)?.toInt() ?? 0; 
                        
                        totalItems += quantity;
                        
                        return {
                            'name': name,
                            'quantity': quantity,
                            'status': itemDetail['estado_producto']?.toString() ?? 'pendiente',
                        };
                    }).toList();


                    final status = OrderStatusMapper.fromDb(orderRow['estado']?.toString() ?? 'pendiente');
                    final mesa = "Mesa ${orderRow['numero_mesa']}"; // Usamos 'numero_mesa'

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExpansionTile(
                              leading: const Icon(Icons.restaurant),
                              title: Text('Pedido #${orderRow['id']} - $mesa'),
                              subtitle: Text("$totalItems productos - \$${total.toString()}"),
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
                              children: processedItems.map((item) {
                                final itemStatus = OrderStatusMapper.fromDb(item['status'] as String);
                                return ListTile(
                                  title: Text("${item['name']} x${item['quantity']}"),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(itemStatus),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      getStatusText(itemStatus),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 6),
                            if (status != OrderStatus.entregado)
                              Center(
                                child: ElevatedButton(
                                  onPressed: () => _marcarComoEntregado(orderRow['id']?.toString() ?? ''),
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