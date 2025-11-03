import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_status.dart';
import '../models/mesa_status.dart'; 
import '../models/mesa_data.dart'; 

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

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
  /// 🔹 OBTENER PEDIDOS DEL MESERO
  /// =====================
  Future<List<Map<String, dynamic>>> fetchMyOrdersWithItems(
      String waiter) async {
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
        .eq('waiter', waiter)
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
  /// 🔹 OBTENER MESAS
  /// =====================
  Future<List<TableData>> fetchTables(String waiter) async {
  try {
    final data = await _client
        .from('mesa')  // Nombre de la tabla
        .select()
        .eq('id_mesero', waiter)  // Filtrar por mesero si es necesario
        .order('numero', ascending: true);  // Asegúrate de que el campo sea 'numero' en lugar de 'numero_mesa'

    // Agregar un print para inspeccionar los datos
    print("Mesas obtenidas: $data");

    // Mapeamos los datos a objetos TableData
    final List<TableData> tables = List<TableData>.from(
      data.map((mesa) => TableData(
        id: mesa['id'] as int,  // Cambiar 'id' según tu base de datos
        number: mesa['numero'] as int,  // Cambiar 'numero' según tu base de datos
        status: mesa['estado'] as String,  // Cambiar 'estado' según tu base de datos
        capacity: mesa['capacidad'] as int,  // Cambiar 'capacidad' según tu base de datos
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
          .eq('id_mesa', tableId);
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
