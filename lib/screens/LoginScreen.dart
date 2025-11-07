import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import '../screens/AdminScreen.dart';
import '../screens/CocinaScreen.dart';
import '../screens/MeseroScreen.dart';
import '../servicios/supabase_service.dart'; // Necesitamos el servicio para buscar el rol

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  final _svc = SupabaseService();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String? _selectedRole;
  String _estado = "";

  // Mapeo de Rol seleccionado (String) a id_rol (Integer) de la DB
  final Map<String, int> _roleMap = {
    'Administrador': 1,
    'Mesero': 2,
    'Cocinero': 3,
  };

  // Función asíncrona para validar usuario y rol
  Future<void> validaUser(String email, String password, BuildContext context) async {
    final selectedRoleId = _roleMap[_selectedRole];

    // 1. Validaciones iniciales
    if (email.isEmpty || password.isEmpty || _selectedRole == null) {
      _estado = "Ingrese credenciales completas y seleccione un rol.";
      setState(() {});
      return;
    }

    // 2. Intenta autenticar con Supabase Auth
    try {
      final SupabaseClient client = Supabase.instance.client;
      
      await client.auth.signInWithPassword(
        email: email, 
        password: password,
      );
      
      // 3. Consulta el rol real en la tabla 'usuario'
      final profileData = await _svc.fetchMeseroProfile(email);
      
      if (profileData == null) {
        throw Exception("Perfil de usuario no encontrado. Asegúrese de que el correo esté registrado en la tabla 'usuario'.");
      }

      final dbRoleId = profileData['id_rol'] as int;
      final dbRoleName = profileData['nombre'] as String; // Usaremos el nombre real

      // 4. Compara el rol de la DB con el rol seleccionado
      if (dbRoleId != selectedRoleId) {
        await client.auth.signOut(); // Cierra la sesión si el rol es incorrecto
        
        // Corregimos el mensaje para que sea conciso y no dependa del nombre
        _estado = "Acceso denegado. El rol seleccionado no coincide con el rol asignado en la base de datos.";
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ ERROR: Acceso denegado. Rol incorrecto (DB ID: ${dbRoleId})."))
        );
        setState(() {});
        return;
      }

      // 5. Autenticación y validación de rol exitosas
      _estado = "Inicio exitoso como ${_selectedRole}!";
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Inicio de sesión exitoso")),
      );

      // 6. Navegación basada en el rol validado
      Widget nextScreen;
      if (_selectedRole == "Mesero") {
        nextScreen = const MeseroScreen();
      } else if (_selectedRole == "Cocinero") {
        nextScreen = const CocinaScreen();
      } else {
        nextScreen = const AdminScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );

    } on AuthException catch (e) {
      // 7. Manejo específico de errores de autenticación
      _estado = "Error de autenticación: ${e.message}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ERROR: ${e.message}")),
      );
      setState(() {});
    } catch (e) {
      // 8. Manejo de errores de perfil/conexión
      _estado = "Error en la validación de perfil: ${e.toString()}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error en el servidor o perfil: ${e.toString()}")),
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
                        labelText: "Rol Seleccionado",
                        prefixIcon: const Icon(Icons.work_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      value: _selectedRole,
                      items: _roleMap.keys.map((String value) {
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

                    // Botón de Inicio de Sesión (ahora asíncrono y con validación de rol)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
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
                        color: _estado.contains("Error") || _estado.contains("denegado")
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