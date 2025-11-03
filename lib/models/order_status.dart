enum OrderStatus { pendiente, preparacion, horno, listo, entregado, cancelado }

extension OrderStatusMapper on OrderStatus {
  /// Convierte el enum a texto para guardar en la base de datos
  String toDb() {
    switch (this) {
      case OrderStatus.pendiente:
        return 'pendiente';
      case OrderStatus.preparacion:
        return 'preparacion';
      case OrderStatus.horno:
        return 'horno';
      case OrderStatus.listo:
        return 'listo';
      case OrderStatus.entregado:
        return 'entregado';
      case OrderStatus.cancelado:
        return 'cancelado';
    }
  }

  /// Convierte el texto de la BD a enum
  static OrderStatus fromDb(String value) {
    switch (value) {
      case 'pendiente':
        return OrderStatus.pendiente;
      case 'preparacion':
      case 'en_preparacion':
        return OrderStatus.preparacion;
      case 'horno':
        return OrderStatus.horno;
      case 'listo':
        return OrderStatus.listo;
      case 'entregado':
        return OrderStatus.entregado;
      case 'cancelado':
        return OrderStatus.cancelado;
      default:
        return OrderStatus.pendiente;
    }
  }

  /// Nombre legible para mostrar en la interfaz
  String get label {
    switch (this) {
      case OrderStatus.pendiente:
        return 'Pendiente';
      case OrderStatus.preparacion:
        return 'Preparación';
      case OrderStatus.horno:
        return 'Horno';
      case OrderStatus.listo:
        return 'Listo';
      case OrderStatus.entregado:
        return 'Entregado';
      case OrderStatus.cancelado:
        return 'Cancelado';
    }
  }

  /// Estados principales en el flujo de preparación
  static List<OrderStatus> workflow() {
    return const [
      OrderStatus.pendiente,
      OrderStatus.preparacion,
      OrderStatus.horno,
      OrderStatus.listo,
      OrderStatus.entregado,
    ];
  }

  /// Normaliza cualquier texto recibido desde la BD
  static String normalize(String value) {
    return fromDb(value).toDb();
  }
}
