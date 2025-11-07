import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_status.dart';
import '../models/mesa_status.dart'; 
import '../models/mesa_data.dart'; 

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  /// =====================
  /// 🔹 OBTENER PERFIL DE MESERO (tabla usuario)
  /// =====================
  Future<Map<String, dynamic>?> fetchMeseroProfile(String email) async {
    final data = await _client
        .from('usuario')
        .select('id_usuario, nombre, correo, id_rol') 
        .eq('correo', email)
        .maybeSingle();

    if (data == null) {
      return null;
    }
    return data;
  }
  
  /// =====================
  /// 🔹 CREAR PEDIDO (tabla pedidos)
  /// =====================
  Future<String> createOrder({
    required int tableNumber,
    required String waiterId, // id_usuario del mesero (TEXT)
    required String customerGender,
    required int total,
    required String status,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final insertPayload = {
      'id': id, 
      'numero_mesa': tableNumber,
      'estado': status,
      'total': total,
      'mesero_id': waiterId,
      'genero_cliente': customerGender,
      'fecha_pedido': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('pedidos')
        .insert(insertPayload)
        .select('id')
        .maybeSingle();

    if (response == null || response['id'] == null) {
      throw Exception('❌ No se pudo crear el pedido.');
    }

    return response['id'].toString();
  }

  /// =====================
  /// 🔹 AGREGAR PRODUCTOS (tabla detalle_pedido)
  /// =====================
  Future<void> addOrderItems(
      String orderId, List<Map<String, dynamic>> itemsRows) async {
    final mappedItems = itemsRows.map((m) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      return {
        'id': id,
        'id_pedido': orderId,
        'nombre_producto': m['name'],
        'categoria': m['category'],
        'precio': m['price'],
        'cantidad': m['quantity'],
        'estado_producto': m['product_status'] ?? 'pendiente',
        'hora_inicio_prep': DateTime.now().toIso8601String(),
      };
    }).toList();

    await _client.from('detalle_pedido').insert(mappedItems);
  }

  /// =====================
  /// 🔹 OBTENER PEDIDOS DEL MESERO (pedidos)
  /// =====================
  Future<List<Map<String, dynamic>>> fetchMyOrdersWithItems(
      String waiterIdString) async {
    final data = await _client
        .from('pedidos')
        .select(''' 
          id, 
          numero_mesa,
          mesero_id,
          estado,
          total,
          fecha_pedido,
          detalle_pedido (
            id,
            nombre_producto,
            categoria,
            precio,
            cantidad,
            estado_producto
          )
        ''')
        .eq('mesero_id', waiterIdString)
        .order('fecha_pedido', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// =====================
  /// 🔹 OBTENER TODOS LOS PEDIDOS (COCINA/ADMIN)
  /// =====================
  Future<List<Map<String, dynamic>>> fetchAllOrdersWithItems() async {
    final data = await _client
        .from('pedidos')
        .select(''' 
          id,
          numero_mesa,
          mesero_id,
          estado,
          total,
          fecha_pedido,
          detalle_pedido (
            id,
            nombre_producto,
            categoria,
            precio,
            cantidad,
            estado_producto
          )
        ''')
        .order('fecha_pedido', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE UN PRODUCTO
  /// =====================
  Future<void> updateProductStatus(String itemId, String newStatus) async {
    final normalizedStatus = OrderStatusMapper.normalize(newStatus);

    final updatedRow = await _client
        .from('detalle_pedido')
        .update({'estado_producto': normalizedStatus})
        .eq('id', itemId)
        .select('id_pedido')
        .maybeSingle();

    if (updatedRow == null || updatedRow['id_pedido'] == null) {
      return;
    }

    final orderId = updatedRow['id_pedido'] as String;

    final items = await _client
        .from('detalle_pedido')
        .select('estado_producto')
        .eq('id_pedido', orderId);

    final orderStatus = _determineOrderStatusFromItems(items);

    await updateOrderStatus(orderId, orderStatus);
  }

  OrderStatus _determineOrderStatusFromItems(dynamic itemsResponse) {
    final items = List<Map<String, dynamic>>.from(itemsResponse ?? const []);
    if (items.isEmpty) {
      return OrderStatus.pendiente;
    }

    const priorities = {
      OrderStatus.pendiente: 0,
      OrderStatus.preparacion: 1,
      OrderStatus.horno: 2,
      OrderStatus.listo: 3,
      OrderStatus.entregado: 4,
    };

    var minPriority = 999;
    OrderStatus? resultingStatus;

    for (final item in items) {
      final rawStatus = (item['estado_producto'] as String?) ?? 'pendiente';
      final normalized = OrderStatusMapper.fromDb(rawStatus);

      if (!priorities.containsKey(normalized)) {
        continue;
      }

      final priority = priorities[normalized]!;

      if (priority < minPriority) {
        minPriority = priority;
        resultingStatus = normalized;
      }
    }

    return resultingStatus ?? OrderStatus.pendiente;
  }

  /// =====================
  /// 🔹 OBTENER MESAS (Filtrado por ID_MESERO INTEGER)
  /// =====================
  Future<List<TableData>> fetchTables(int waiterId) async { 
  try {
    final data = await _client
        .from('mesa')
        .select()
        .eq('id_mesero', waiterId)
        .order('numero_mesa', ascending: true);

    final List<TableData> tables = List<TableData>.from(
      data.map((mesa) => TableData(
        id: mesa['id_mesa'] as int,
        number: mesa['numero_mesa'] as int,
        status: mesa['estado'] as String,
        capacity: mesa['capacidad'] as int,
        waiter: mesa['id_mesero'] != null ? "Mesero ${mesa['id_mesero']}" : null,
        waiterId: mesa['id_mesero'] as int?,
      )),
    );

    return tables;
  } catch (e) {
    rethrow;
  }
}


  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE LA MESA
  /// =====================
  Future<void> updateTableStatus(int tableId, TableStatus status) async {
    try {
      await _client
          .from('mesa')
          .update({'estado': status.toDb()})
          .eq('id_mesa', tableId);
    } catch (e) {
      rethrow;
    }
  }

  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE PEDIDO
  /// =====================
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _client
        .from('pedidos')
        .update({'estado': status.toDb()})
        .eq('id', orderId);
  }
  
  /// =====================
  /// 🔹 CERRAR SESIÓN
  /// =====================
  Future<void> logOut() async {
    await _client.auth.signOut();
  }
}
