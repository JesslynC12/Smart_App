import 'package:flutter/material.dart';
import 'package:project_app/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import file project Anda
import 'auth_service.dart';
import 'home_page.dart';
import 'login.dart'; // Pastikan nama file sesuai (sebelumnya Anda pakai login.dart)
import 'register_vendor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://izjiqeoydfyhvaqfgnlx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6amlxZW95ZGZ5aHZhcWZnbmx4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4MzU2OTEsImV4cCI6MjA4NDQxMTY5MX0.5nxxKrzD_K2D9JvaADyMJcKpFEC5bLCb0_yvNXtAvKA',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart App - WMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade800),
        useMaterial3: true,
      ),
      // AuthWrapper menentukan apakah user harus login atau langsung ke Home
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register-vendor': (context) => const RegisterVendorPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Beri sedikit delay agar splash/indicator terlihat halus
    await Future.delayed(const Duration(seconds: 1));
    
    final isLoggedIn = await AuthService.isLoggedIn();
    
    if (mounted) {
      if (isLoggedIn) {
        // Jika sudah login, langsung ke HomePage
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Jika belum, ke LoginPage (Universal)
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Memeriksa Sesi...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}