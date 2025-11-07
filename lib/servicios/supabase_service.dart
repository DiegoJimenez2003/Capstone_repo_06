import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_status.dart';
import '../models/mesa_status.dart'; 
import '../models/mesa_data.dart'; 

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  /// =====================
  /// 🔹 OBTENER PERFIL DE MESERO (tabla usuario)
  ///    Usa el EMAIL de autenticación para obtener el ID de tu tabla (INTEGER).
  /// =====================
  Future<Map<String, dynamic>?> fetchMeseroProfile(String email) async {
    // Buscamos en la tabla 'usuario' donde el 'correo' coincida con el email del usuario
    final data = await _client
        .from('usuario')
        .select('id_usuario, nombre, correo, id_rol') 
        .eq('correo', email) // Filtramos por la columna 'correo' de tu tabla
        .maybeSingle();

    if (data == null) {
      return null;
    }
    return data;
  }
  
  /// =====================
  /// 🔹 CREAR PEDIDO (tabla pedidos)
  ///    Utiliza 'waiterId' para el campo 'mesero_id' (TEXT)
  /// =====================
  Future<String> createOrder({
    required int tableNumber,
    required String waiterId, // ID de mesero (INT convertido a String)
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
      'mesero_id': waiterId, // Columna en español
      'genero_cliente': customerGender, // Columna en español
      'fecha_pedido': DateTime.now().toIso8601String(), // Columna en español
    };

    final response = await _client
        .from('pedidos') // Nombre de la tabla en español
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
  ///    Mapea campos en inglés a columnas en español.
  /// =====================
  Future<void> addOrderItems(
      String orderId, List<Map<String, dynamic>> itemsRows) async {
    final withOrderId = itemsRows.map((m) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      return {
        'id': id,
        'id_pedido': orderId, // FK a la tabla 'pedidos'
        'nombre_producto': m['name'], // Mapeado de 'name'
        'categoria': m['category'], // Mapeado de 'category'
        'precio': m['price'], // Mapeado de 'price'
        'cantidad': m['quantity'], // Mapeado de 'quantity'
        'estado_producto': m['product_status'] ?? 'pendiente', // Mapeado de 'product_status'
        'hora_inicio_prep': DateTime.now().toIso8601String(), // Columna en español
      };
    }).toList();
    
    await _client.from('detalle_pedido').insert(withOrderId); // Nombre de la tabla en español
  }

  /// =====================
  /// 🔹 OBTENER PEDIDOS DEL MESERO (pedidos)
  /// =====================
  Future<List<Map<String, dynamic>>> fetchMyOrdersWithItems(
      String waiterIdString) async {
    final data = await _client
        .from('pedidos') // Nombre de la tabla en español
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
        .eq('mesero_id', waiterIdString) // Filtra por el ID de mesero
        .order('fecha_pedido', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// =====================
  /// 🔹 OBTENER TODOS LOS PEDIDOS (COCINA - pedidos)
  /// =====================
  Future<List<Map<String, dynamic>>> fetchAllOrdersWithItems() async {
    final data = await _client
        .from('pedidos') // Nombre de la tabla en español
        .select(''' 
          id,
          numero_mesa,
          mesero_id,
          estado,
          total,
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
  /// 🔹 ACTUALIZAR ESTADO DE UN PRODUCTO (detalle_pedido)
  /// =====================
  Future<void> updateProductStatus(String itemId, String newStatus) async {
    final normalizedStatus = OrderStatusMapper.normalize(newStatus);

    final updatedRow = await _client
        .from('detalle_pedido') // Nombre de la tabla en español
        .update({'estado_producto': normalizedStatus}) // Columna en español
        .eq('id', itemId)
        .select('id_pedido') // Columna en español
        .maybeSingle();

    if (updatedRow == null || updatedRow['id_pedido'] == null) {
      return;
    }

    final orderId = updatedRow['id_pedido'] as String;

    final items = await _client
        .from('detalle_pedido') // Nombre de la tabla en español
        .select('estado_producto') // Columna en español
        .eq('id_pedido', orderId); // Columna en español

    final orderStatus = _determineOrderStatusFromItems(items);

    await updateOrderStatus(orderId, orderStatus);
  }

  // Lógica de determinación de estado (usa 'estado_producto')
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
  /// 🔹 ACTUALIZAR ESTADO DE PEDIDO (pedidos)
  /// =====================
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _client
        .from('pedidos') // Nombre de la tabla en español
        .update({'estado': status.toDb()}) // Columna en español
        .eq('id', orderId);
  }


  /// =====================
  /// 🔹 OBTENER MESAS (mesa)
  /// =====================
  Future<List<TableData>> fetchTables(int waiterId) async { 
  try {
    final data = await _client
        .from('mesa') // Nombre de la tabla en español
        .select()
        .eq('id_mesero', waiterId) // Columna en español
        .order('numero_mesa', ascending: true); // Columna en español

    final List<TableData> tables = List<TableData>.from(
      data.map((mesa) => TableData(
        id: mesa['id_mesa'] as int, // Columna en español
        number: mesa['numero_mesa'] as int, // Columna en español
        status: mesa['estado'] as String, // Columna en español
        capacity: mesa['capacidad'] as int, // Columna en español
        waiter: mesa['id_mesero'] != null ? "Mesero ${mesa['id_mesero']}" : null, // Columna en español
        waiterId: mesa['id_mesero'] as int?, // Columna en español
      )),
    );

    return tables;
  } catch (e) {
    rethrow;
  }
}

  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE LA MESA (mesa)
  /// =====================
  Future<void> updateTableStatus(int tableId, TableStatus status) async {
    try {
      await _client
          .from('mesa') // Nombre de la tabla en español
          .update({'estado': status.toDb()}) // Columna en español
          .eq('id_mesa', tableId); // Columna en español
    } catch (e) {
      rethrow;
    }
  }

  /// =====================
  /// 🔹 ASIGNAR MESERO A UNA MESA (mesa)
  /// =====================
  Future<void> assignWaiterToTable(int tableId, int waiterId) async {
    await _client
        .from('mesa') // Nombre de la tabla en español
        .update({'id_mesero': waiterId}) // Columna en español
        .eq('id_mesa', tableId); // Columna en español
  }
}