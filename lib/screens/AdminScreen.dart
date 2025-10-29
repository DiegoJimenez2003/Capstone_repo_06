import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Datos simulados
    final int todayOrders = 47;
    final int todayRevenue = 1250000;
    final int avgOrderTime = 28;
    final int activeOrders = 12;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(FontAwesomeIcons.chartLine, color: Colors.deepOrangeAccent),
            SizedBox(width: 10),
            Text(
              "Panel del Administrador",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            const Text(
              "Resumen del Día",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Tarjetas de métricas principales
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMetricCard(
                  icon: FontAwesomeIcons.receipt,
                  color: Colors.blueAccent,
                  title: "Pedidos Hoy",
                  value: "$todayOrders",
                ),
                _buildMetricCard(
                  icon: FontAwesomeIcons.dollarSign,
                  color: Colors.green,
                  title: "Ingresos del Día",
                  value: "\$${(todayRevenue / 1000).toStringAsFixed(0)}K",
                ),
                _buildMetricCard(
                  icon: FontAwesomeIcons.clock,
                  color: Colors.orange,
                  title: "Tiempo Promedio",
                  value: "$avgOrderTime min",
                ),
                _buildMetricCard(
                  icon: FontAwesomeIcons.utensils,
                  color: Colors.purple,
                  title: "Pedidos Activos",
                  value: "$activeOrders",
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(),

            // Tabla o lista de estado de pedidos
            const SizedBox(height: 20),
            const Text(
              "Pedidos Activos",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _buildOrderCard("Mesa 3", "Mesero: Ana", 3, 25000, "pendiente"),
            _buildOrderCard("Mesa 5", "Mesero: Carlos", 2, 18000, "en_preparacion"),
            _buildOrderCard("Mesa 8", "Mesero: José", 4, 42000, "listo"),

            const SizedBox(height: 40),

            // Botones de acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text("Ver Historial", style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.black87),
                  label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.black87)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets auxiliares ---

  Widget _buildMetricCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(String mesa, String mesero, int items, int total, String estado) {
    Color color;
    String label;

    switch (estado) {
      case "pendiente":
        color = Colors.amber;
        label = "Pendiente";
        break;
      case "en_preparacion":
        color = Colors.blueAccent;
        label = "En preparación";
        break;
      default:
        color = Colors.green;
        label = "Listo";
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.restaurant_menu, color: color),
        ),
        title: Text(mesa),
        subtitle: Text("$mesero - $items productos\nTotal: \$${total.toStringAsFixed(0)}"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
