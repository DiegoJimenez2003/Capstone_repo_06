enum OrderStatus { pendiente, enPreparacion, listo, cancelado }

extension OrderStatusMapper on OrderStatus {
  /// Convierte el enum a texto para guardar en la base de datos
  String toDb() {
    switch (this) {
      case OrderStatus.pendiente:
        return 'pendiente';
      case OrderStatus.enPreparacion:
        return 'en_preparacion';
      case OrderStatus.listo:
        return 'listo';
      case OrderStatus.cancelado:
        return 'cancelado';
    }
  }

  /// Convierte el texto de la BD a enum
  static OrderStatus fromDb(String value) {
    switch (value) {
      case 'pendiente':
        return OrderStatus.pendiente;
      case 'en_preparacion':
        return OrderStatus.enPreparacion;
      case 'listo':
        return OrderStatus.listo;
      case 'cancelado':
        return OrderStatus.cancelado;
      default:
        return OrderStatus.pendiente;
    }
  }
}
