import 'package:flutter/material.dart';
import 'package:project_app/admin/home_page.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:project_app/login.dart';
import 'package:project_app/vendor/homepage_vendor.dart';
import 'package:project_app/vendor/register_vendor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      title: 'Smart App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red.shade700),
        useMaterial3: true,
      ),
      // AuthWrapper sebagai pintu masuk utama
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register-vendor': (context) => const RegisterVendorPage(),
        '/home-admin': (context) => const HomePage(),
        '/home-vendor': (context) => const HomepageVendor(),
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
    // Delay sedikit agar transisi mulus
    await Future.delayed(const Duration(seconds: 2));
    
    // Ambil data user lengkap (termasuk role & status)
    final user = await AuthService.getCurrentUser();
    
    if (!mounted) return;

    if (user != null) {
      // LOGIKA NAVIGASI BERDASARKAN ROLE
      if (user.role == 'vendor') {
        if (user.status == 'approved') {
          Navigator.pushReplacementNamed(context, '/home-vendor');
        } else {
          // Jika vendor belum di-approve, paksa logout atau arahkan ke login dengan pesan
          await AuthService.logout();
          _navigateToLoginWithMsg("Akun Vendor Anda masih menunggu persetujuan Admin.");
        }
      } else {
        // Jika Admin/PPIC/Gudang
        Navigator.pushReplacementNamed(context, '/home-admin');
      }
    } else {
      // Jika tidak ada session, arahkan ke login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _navigateToLoginWithMsg(String msg) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
    // Tampilkan pesan kenapa dia tidak bisa masuk
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange.shade800),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branding Splash (Bisa diganti Logo PT Anda)
            Icon(Icons.badge_outlined, size: 80, color: Colors.red.shade700),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Memeriksa Sesi...',
              style: TextStyle(color: Colors.grey, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}