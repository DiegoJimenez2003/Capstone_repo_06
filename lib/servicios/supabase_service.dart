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
  /// 🔹 CREAR PEDIDO (Inserta en la tabla 'pedidos')
  /// =====================
  Future<String> createOrder({
    required int tableNumber,
    required String waiterId, // id_usuario del mesero (TEXT)
    required String customerGender,
    required int total,
    required String status,
  }) async {
    // Usamos millisecondsSinceEpoch como ID temporal (TEXT)
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final insertPayload = {
      'id': id,
      'numero_mesa': tableNumber, // Columna: numero_mesa
      'estado': status,           // Columna: estado
      'total': total,             // Columna: total
      'mesero_id': waiterId,      // Columna: mesero_id (ID del usuario)
      'genero_cliente': customerGender, // Columna: genero_cliente
      'fecha_pedido': DateTime.now().toIso8601String(), // Columna: fecha_pedido
    };

    final response = await _client
        .from('pedidos') // Tabla: pedidos
        .insert(insertPayload)
        .select('id')
        .maybeSingle();

    if (response == null || response['id'] == null) {
      throw Exception('❌ No se pudo crear el pedido.');
    }

    return response['id'].toString();
  }

  /// =====================
  /// 🔹 AGREGAR PRODUCTOS (Inserta en la tabla 'detalle_pedido')
  /// =====================
  Future<void> addOrderItems(
      String orderId, List<Map<String, dynamic>> itemsRows) async {
    final mappedItems = itemsRows.map((m) {
      // Usamos microsecondsSinceEpoch para asegurar unicidad del id de detalle
      final id = DateTime.now().microsecondsSinceEpoch.toString(); 
      return {
        'id': id,
        'id_pedido': orderId,             // FK a pedidos(id)
        'nombre_producto': m['name'],     // Columna: nombre_producto
        'categoria': m['category'],       // Columna: categoria
        'precio': m['price'],             // Columna: precio
        'cantidad': m['quantity'],        // Columna: cantidad
        'estado_producto': m['product_status'], // Columna: estado_producto
      };
    }).toList();

    await _client.from('detalle_pedido').insert(mappedItems); // Tabla: detalle_pedido
  }

  /// =====================
  /// 🔹 OBTENER PEDIDOS DEL MESERO
  /// =====================
  Future<List<Map<String, dynamic>>> fetchMyOrdersWithItems(
      String waiterId) async { // Recibe el ID del mesero como String
    final data = await _client
        .from('pedidos') // Tabla: pedidos
        .select(''' 
          id,
          numero_mesa,
          mesero_id,
          estado,
          total,
          fecha_pedido,
          detalle_pedido(
            id,
            nombre_producto,
            categoria,
            precio,
            cantidad,
            estado_producto
          )
        ''')
        .eq('mesero_id', waiterId) // Filtra por la columna mesero_id
        .order('fecha_pedido', ascending: false); // Columna: fecha_pedido

    return List<Map<String, dynamic>>.from(data);
  }

  /// =====================
  /// 🔹 OBTENER TODOS LOS PEDIDOS (COCINA)
  /// =====================
  Future<List<Map<String, dynamic>>> fetchAllOrdersWithItems() async {
    final data = await _client
        .from('pedidos') // Tabla: pedidos
        .select(''' 
          id,
          numero_mesa,
          mesero_id,
          estado,
          total,
          detalle_pedido(
            id,
            nombre_producto,
            categoria,
            precio,
            cantidad,
            estado_producto
          )
        ''')
        .order('fecha_pedido', ascending: false); // Columna: fecha_pedido

    return List<Map<String, dynamic>>.from(data);
  }

  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE UN PRODUCTO
  /// =====================
  Future<void> updateProductStatus(String itemId, String newStatus) async {
    final normalizedStatus = OrderStatusMapper.normalize(newStatus);

    final updatedRow = await _client
        .from('detalle_pedido') // Tabla: detalle_pedido
        .update({'estado_producto': normalizedStatus}) // Columna: estado_producto
        .eq('id', itemId) // Columna: id (del detalle)
        .select('id_pedido') // Columna: id_pedido
        .maybeSingle();

    if (updatedRow == null || updatedRow['id_pedido'] == null) {
      return;
    }

    final orderId = updatedRow['id_pedido'] as String; // Columna: id_pedido

    final items = await _client
        .from('detalle_pedido') // Tabla: detalle_pedido
        .select('estado_producto') // Columna: estado_producto
        .eq('id_pedido', orderId); // Columna: id_pedido

    final orderStatus = _determineOrderStatusFromItems(items);

    await updateOrderStatus(orderId, orderStatus);
  }

  OrderStatus _determineOrderStatusFromItems(dynamic itemsResponse) {
    // La lógica de determinar el estado de la orden principal (pedidos.estado)
    // a partir de los estados de los ítems (detalle_pedido.estado_producto)
    // se mantiene igual.
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
      final rawStatus = (item['estado_producto'] as String?) ?? 'pendiente'; // Columna: estado_producto
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
        .from('mesa')  // Tabla: mesa
        .select()
        .eq('id_mesero', waiterId)  // Columna: id_mesero
        .order('numero_mesa', ascending: true); // Columna: numero_mesa

    // Mapeamos los datos a objetos TableData
    final List<TableData> tables = List<TableData>.from(
      data.map((mesa) => TableData(
        id: mesa['id_mesa'] as int,           // Columna: id_mesa
        number: mesa['numero_mesa'] as int,   // Columna: numero_mesa
        status: mesa['estado'] as String,     // Columna: estado
        capacity: mesa['capacidad'] as int,   // Columna: capacidad
        waiter: mesa['id_mesero'] != null ? "Mesero ${mesa['id_mesero']}" : null,
        waiterId: mesa['id_mesero'] as int?,  // Columna: id_mesero
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
          .from('mesa') // Tabla: mesa
          .update({'estado': status.toDb()})  // Columna: estado
          .eq('id_mesa', tableId); // Columna: id_mesa
    } catch (e) {
      rethrow;
    }
  }

  /// =====================
  /// 🔹 ACTUALIZAR ESTADO DE PEDIDO
  /// =====================
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _client
        .from('pedidos') // Tabla: pedidos
        .update({'estado': status.toDb()}) // Columna: estado
        .eq('id', orderId); // Columna: id
  }
  
  /// =====================
  /// 🔹 CERRAR SESIÓN
  /// =====================
  Future<void> logOut() async {
    await _client.auth.signOut();
  }
}