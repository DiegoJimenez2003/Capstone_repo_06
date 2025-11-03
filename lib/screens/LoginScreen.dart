import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importación de Supabase

import '../screens/AdminScreen.dart';
import '../screens/CocinaScreen.dart';
import '../screens/MeseroScreen.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String? _selectedRole;
  String _estado = "";

  // Función asíncrona para validar usuario con Supabase
  Future<void> validaUser(String email, String password, BuildContext context) async {
    // 1. Validación de campos vacíos
    if (email.isEmpty || password.isEmpty) {
      _estado = "Ingrese credenciales completas";
      setState(() {});
      return;
    }

    // 2. Intenta iniciar sesión con Supabase
    try {
      final SupabaseClient client = Supabase.instance.client;
      
      // Llama al método de autenticación de Supabase
      final AuthResponse response = await client.auth.signInWithPassword(
        email: email, 
        password: password,
      );

      // Si la autenticación es exitosa, response.user no será nulo.
      if (response.user != null) {
        _estado = "Inicio exitoso";
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Inicio de sesión exitoso")),
        );

        // Lógica de navegación basada en el rol seleccionado
        Widget nextScreen;
        if (_selectedRole == "Mesero") {
          nextScreen = const MeseroScreen();
        } else if (_selectedRole == "Cocinero") {
          nextScreen = const CocinaScreen();
        } else {
          nextScreen = const AdminScreen();
        }

        // Navegación con reemplazo para evitar volver a la pantalla de login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      } else {
        // En teoría, `signInWithPassword` lanza una excepción en caso de fallo,
        // pero incluimos este else por seguridad.
        _estado = "Error: Credenciales no válidas";
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ ERROR: Credenciales no válidas")),
        );
        setState(() {});
      }

    } on AuthException catch (e) {
      // 3. Manejo específico de errores de autenticación (credenciales incorrectas, etc.)
      _estado = "Error de autenticación: ${e.message}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ERROR: ${e.message}")),
      );
      setState(() {});
    } catch (e) {
      // 4. Manejo de cualquier otro error inesperado
      _estado = "Error inesperado: $e";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error inesperado. Verifique su conexión o claves de Supabase.")),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFCCBC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo circular
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: Colors.deepOrangeAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: FaIcon(
                          FontAwesomeIcons.utensils,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Restaurant SDF",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Sistema de gestión de pedidos",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Campo usuario
                    TextField(
                      controller: _loginController,
                      decoration: InputDecoration(
                        labelText: "Usuario (Email)", // Indicamos que es el Email
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo contraseña
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dropdown de rol
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: "Rol",
                        prefixIcon: const Icon(Icons.work_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      value: _selectedRole,
                      items: <String>[
                        'Mesero',
                        'Cocinero',
                        'Administrador'
                      ].map((String value) {
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
                    const SizedBox(height: 24),

                    // Botón de Inicio de Sesión (ahora asíncrono)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        // Llama a la función asíncrona
                        onPressed: () async {
                          if (_selectedRole == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Seleccione un rol")),
                            );
                            return;
                          }
                          await validaUser(_loginController.text,
                              _passController.text, context);
                        },
                        icon: const Icon(Icons.login, color: Colors.white),
                        label: const Text(
                          "Iniciar sesión",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrangeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Estado
                    Text(
                      _estado.isEmpty ? "" : "Estado: $_estado",
                      style: TextStyle(
                        color: _estado.contains("Error")
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
