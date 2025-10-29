import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // 🔹 Inicializar conexión a Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://kugghmlnwbjemreammpr.supabase.co',
      anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt1Z2dobWxud2JqZW1yZWFtbXByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2OTMzNzYsImV4cCI6MjA3NzI2OTM3Nn0.Hi8EiKTHhwnu7BGvzznOJ93uaZId8uphnH5HLp-k55Q',
  );
  }

  // 🔹 Obtener todos los pedidos
  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await client
        .from('orders')
        .select('*, order_items(*)')
        .order('timestamp', ascending: false);

    if (response.isEmpty) {
      print("No hay pedidos.");
      return [];
    }
    return response;
  }

  // 🔹 Insertar nuevo pedido
  Future<void> insertOrder(Map<String, dynamic> order) async {
    await client.from('orders').insert(order);
  }

  // 🔹 Insertar productos del pedido
  Future<void> insertOrderItems(List<Map<String, dynamic>> items) async {
    await client.from('order_items').insert(items);
  }

  // 🔹 Actualizar estado del pedido
  Future<void> updateOrderStatus(String orderId, String status) async {
    await client.from('orders').update({'status': status}).eq('id', orderId);
  }

  // 🔹 Escuchar cambios en tiempo real (Realtime)
  Stream<List<Map<String, dynamic>>> subscribeOrders() {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .map((data) => data);
  }
}
