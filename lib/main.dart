import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantsdf/screens/loginscreen.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase
  await Supabase.initialize(
    url: 'https://kugghmlnwbjemreammpr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt1Z2dobWxud2JqZW1yZWFtbXByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2OTMzNzYsImV4cCI6MjA3NzI2OTM3Nn0.Hi8EiKTHhwnu7BGvzznOJ93uaZId8uphnH5HLp-k55Q',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Restaurant SDF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const Loginscreen(),
    );
  }
}
