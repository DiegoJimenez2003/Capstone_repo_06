import 'package:flutter/material.dart';

class MeseroScreen extends StatelessWidget {
  const MeseroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel del Mesero"),
        backgroundColor: Colors.orangeAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text("Pedidos activos:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text("Mesa 1 - En preparación"),
              subtitle: const Text("Pedido #001"),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text("Ver"),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text("Mesa 3 - Servido"),
              subtitle: const Text("Pedido #002"),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text("Ver"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
