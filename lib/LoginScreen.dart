import 'package:flutter/material.dart';
import 'package:restaurantsdf/AdminScreen.dart';
import 'MeseroScreen.dart';
import 'Cocinascreen.dart';
import 'AdminScreen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  

  final TextEditingController _loginController =  TextEditingController();
  final TextEditingController _passController =  TextEditingController();
  static String TextEstado = "";
  String? _selectedRole; // Variable para rol seleccionado

  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  void validaUser(String login, String password, BuildContext context) {
  if (login == "duoc" && password == "duoc2025") {
    TextEstado = "TODO OK.";
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Inicio de sesión exitoso")),
    );

    Widget nextScreen;

    if (_selectedRole == "Mesero") {
        nextScreen = MeseroScreen();
      } else if (_selectedRole == "Cocinero") {
        nextScreen = CocinaScreen();
      } else {
        nextScreen = AdminScreen();
      }


    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  } else {
    TextEstado = "TODO MAL";
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ERROR DE CREDENCIALES')),
    );
    setState(() {});
  }
}


  TextField cajaTexto(String text, TextEditingController controller, bool isPass) {
    return TextField(
      obscureText: isPass,
      decoration: InputDecoration(labelText: text, border: OutlineInputBorder()),
      controller: controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Pase por el build");
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.deepOrangeAccent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            FaIcon(
              FontAwesomeIcons.utensils,
              color: Colors.white,
              size: 25,
            ),
            SizedBox(width: 8),
            Text(
              "Restaurant SDF",
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(   // <-- Hacemos scrollable todo el contenido
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sistema de gestión de pedidos",
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 20),
                
                cajaTexto("Usuario", _loginController, false),
                SizedBox(height: 20),
                
                cajaTexto("Contraseña", _passController, true),
                SizedBox(height: 20),

                Text("Rol"),
                SizedBox(height: 10),

                DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedRole,
                  hint: Text("Seleccione un rol"),
                  items: <String>['Mesero', 'Cocinero', 'Administrador']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue;
                    });
                  },
                ),

                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    if (_selectedRole == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Por favor, seleccione un rol")),
                      );
                      return;
                    }
                    validaUser(_loginController.text, _passController.text, context);
                  },
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.deepOrangeAccent),
                  ),
                  child: Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: Colors.white,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Ingresar",
                          style: TextStyle(color: Colors.white),
                        )
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text("Estado: $TextEstado"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
