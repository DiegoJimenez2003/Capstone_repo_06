// models/mesa_data.dart
import 'mesa_status.dart';  // Importa el archivo donde tienes el enum TableStatus

class TableData {
  final int id;
  final int number;
  final TableStatus status;  // Utilizamos el enum TableStatus
  final int capacity;
  final String? waiter;  // Nombre del mesero asignado
  final int? waiterId;  // ID del mesero asignado (vinculado a usuario)

  TableData({
    required this.id,
    required this.number,
    required this.status,
    required this.capacity,
    this.waiter,
    this.waiterId,
  });
}
