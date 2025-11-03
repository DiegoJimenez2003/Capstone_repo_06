import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_status.dart';
import '../models/mesa_status.dart'; 
import '../models/mesa_data.dart'; 

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  /// =====================
  /// 🔹 OBTENER DATOS DE USUARIO DESDE LA TABLA 'usuario'
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
  /// 🔹 CREAR PEDIDO
  /// =====================
  Future<String> createOrder({
    required int tableNumber,
    required String waiter,
    required String customerGender,
    required int total,
    required String status, // 'pendiente', 'listo', etc.
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final insertPayload = {
      'id': id,
      'table_number': tableNumber,
      'status': status,
      'total': total,
      'waiter': waiter,
      'customer_gender': customerGender,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('orders')
        .insert(insertPayload)
        .select('id')
        .maybeSingle();

    if (response == null || response['id'] == null) {
      throw Exception('❌ No se pudo crear el pedido.');
    }

    return response['id'].toString();
  }

  /// =====================
  /// 🔹 AGREGAR PRODUCTOS
  /// =====================
  Future<void> addOrderItems(
      String orderId, List<Map<String, dynamic>> itemsRows) async {
    final withOrderId = itemsRows.map((m) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      return {
        ...m,
        'id': id,
        'order_id': orderId,
      };
    }).toList();

    await _client.from('order_items').insert(withOrderId);
  }

  /// =====================
  /// 🔹 OBTENER PEDIDOS DEL MESERO (Filtrado por EMAIL/NOMBRE)
  /// =====================
  Future<List<Map<String, dynamic>>> fetchMyOrdersWithItems(
      String waiterEmail) async {
    final data = await _client
        .from('orders')
        .select(''' 
          id,
          table_number,
          waiter,
          customer_gender,
          status,
          total,
          timestamp,
          order_items(
            id,
            name,
            category,
            price,
            quantity,
            product_status
          )
        ''')
        .eq('waiter', waiterEmail) // Filtra por el email/nombre del mesero almacenado en 'waiter'
        .order('timestamp', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE PEDIDO
  /// =====================
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _client
        .from('orders')
        .update({'status': status.toDb()})
        .eq('id', orderId);
  }

  /// =====================
  /// 🔹 OBTENER TODOS LOS PEDIDOS (COCINA)
  /// =====================
  Future<List<Map<String, dynamic>>> fetchAllOrdersWithItems() async {
    final data = await _client
        .from('orders')
        .select(''' 
          id,
          table_number,
          waiter,
          status,
          total,
          order_items (
            id,
            name,
            category,
            price,
            quantity,
            product_status
          )
        ''')
        .order('timestamp', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE UN PRODUCTO
  /// =====================
  Future<void> updateProductStatus(String itemId, String newStatus) async {
    final normalizedStatus = OrderStatusMapper.normalize(newStatus);

    final updatedRow = await _client
        .from('order_items')
        .update({'product_status': normalizedStatus})
        .eq('id', itemId)
        .select('order_id')
        .maybeSingle();

    if (updatedRow == null || updatedRow['order_id'] == null) {
      return;
    }

    final orderId = updatedRow['order_id'] as String;

    final items = await _client
        .from('order_items')
        .select('product_status')
        .eq('order_id', orderId);

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
      final rawStatus = (item['product_status'] as String?) ?? 'pendiente';
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
        .from('mesa')  // Nombre de la tabla
        .select()
        .eq('id_mesero', waiterId)  // Filtramos por el ID_MESERO INTEGER
        .order('numero_mesa', ascending: true); // Asegúrate que es 'numero_mesa'

    // Agregar un print para inspeccionar los datos
    print("Mesas obtenidas: $data");

    // Mapeamos los datos a objetos TableData
    final List<TableData> tables = List<TableData>.from(
      data.map((mesa) => TableData(
        id: mesa['id_mesa'] as int,  // Cambiar a 'id_mesa'
        number: mesa['numero_mesa'] as int,  // Cambiar a 'numero_mesa'
        status: mesa['estado'] as String,  // Mantiene 'estado'
        capacity: mesa['capacidad'] as int,  // Mantiene 'capacidad'
        // El campo 'waiter' en el modelo TableData espera un String, 
        // pero aquí solo tenemos el ID. Por simplicidad, usamos el ID convertido a String.
        waiter: mesa['id_mesero'] != null ? "Mesero ${mesa['id_mesero']}" : null,
        waiterId: mesa['id_mesero'] as int?,
      )),
    );

    return tables;
  } catch (e) {
    rethrow;  // Propagar el error para que pueda ser manejado en la UI
  }
}


  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE LA MESA
  /// =====================
  Future<void> updateTableStatus(int tableId, TableStatus status) async {
    try {
      await _client
          .from('mesa')
          .update({'estado': status.toDb()})  // Convertir el enum a texto
          .eq('id_mesa', tableId); // Usar 'id_mesa' para el filtro
    } catch (e) {
      rethrow;
    }
  }

  /// =====================
  /// 🔹 ASIGNAR MESERO A UNA MESA
  /// =====================
  Future<void> assignWaiterToTable(int tableId, int waiterId) async {
    await _client
        .from('mesa')
        .update({'id_mesero': waiterId})
        .eq('id_mesa', tableId);
  }
}
