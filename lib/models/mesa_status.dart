enum TableStatus { libre, ocupada, reservada }

extension TableStatusMapper on TableStatus {
  /// Convierte el enum a texto para guardar en la base de datos
  String toDb() {
    switch (this) {
      case TableStatus.libre:
        return 'libre';
      case TableStatus.ocupada:
        return 'ocupada';
      case TableStatus.reservada:
        return 'reservada';
    }
  }

  /// Convierte el texto de la BD a enum
  static TableStatus fromDb(String value) {
    switch (value) {
      case 'libre':
        return TableStatus.libre;
      case 'ocupada':
        return TableStatus.ocupada;
      case 'reservada':
        return TableStatus.reservada;
      default:
        return TableStatus.libre; // Valor por defecto si el estado no es reconocido
    }
  }

  /// Nombre legible para mostrar en la interfaz
  String get label {
    switch (this) {
      case TableStatus.libre:
        return 'Libre';
      case TableStatus.ocupada:
        return 'Ocupada';
      case TableStatus.reservada:
        return 'Reservada';
    }
  }

  /// Normaliza cualquier texto recibido desde la BD
  static String normalize(String value) {
    return fromDb(value).toDb();
  }
}
