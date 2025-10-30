import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_status.dart';

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
    await _client
        .from('order_items')
        .update({'product_status': newStatus})
        .eq('id', itemId);
  }
}
