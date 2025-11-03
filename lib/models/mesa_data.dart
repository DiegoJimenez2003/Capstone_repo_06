import 'mesa_status.dart'; 

class TableData {
  final int id;
  final int number;
  String status;  // estado de la mesa: libre, ocupada, reservada
  final int capacity;
  final String? waiter;  // Nombre del mesero asignado
  final int? waiterId;  // ID del mesero asignado (vinculado a usuario)

  // Agregamos un 'statusEnum' que es de tipo 'TableStatus'
  TableStatus get statusEnum => TableStatusMapper.fromDb(status);

  TableData({
    required this.id,
    required this.number,
    required this.status,
    required this.capacity,
    this.waiter,
    this.waiterId,
  });

  // Agregar un método para cambiar el estado de la mesa en el tipo 'TableStatus'
  set statusEnum(TableStatus newStatus) {
    status = newStatus.toDb();
  }
}