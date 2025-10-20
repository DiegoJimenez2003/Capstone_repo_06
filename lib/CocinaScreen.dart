import 'package:flutter/material.dart';

class CocinaScreen extends StatelessWidget {
  const CocinaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel del Cocinero"),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text("Pedidos pendientes:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_dining),
              title: const Text("Pedido #001 - Mesa 1"),
              subtitle: const Text("2x Lomo Saltado, 1x Jugo Natural"),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text("Marcar listo"),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_dining),
              title: const Text("Pedido #002 - Mesa 3"),
              subtitle: const Text("1x Ensalada César"),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text("Marcar listo"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
