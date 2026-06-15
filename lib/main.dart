import 'package:flutter/material.dart';
//import 'package:project_app/admin/home_page.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:project_app/login.dart';
import 'package:project_app/vendor/register_vendor.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://izjiqeoydfyhvaqfgnlx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6amlxZW95ZGZ5aHZhcWZnbmx4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4MzU2OTEsImV4cCI6MjA4NDQxMTY5MX0.5nxxKrzD_K2D9JvaADyMJcKpFEC5bLCb0_yvNXtAvKA',
  realtimeClientOptions: const RealtimeClientOptions(
    eventsPerSecond: 10,
  ),
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia (Format dd/mm/yyyy)
        Locale('en', 'US'), // Bahasa Inggris
      ],
      // AuthWrapper sebagai pintu masuk utama
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register-vendor': (context) => const RegisterVendorPage(),
        '/home-admin': (context) => const DynamicTabPage(role: 'admin'),
        '/home-vendor': (context) => const DynamicTabPage(role: 'vendor')
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
  try {
    final user = await AuthService.getCurrentUser();

    if (!mounted) return;

    // Belum login
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Vendor
    if (user.role?.toLowerCase() == 'vendor') {
      final status = user.status?.toLowerCase();

      // Akun vendor sudah diverifikasi
      if (status == 'verified') {
        Navigator.pushReplacementNamed(context, '/home-vendor');
        return;
      }

      // Pending verifikasi email/admin
      if (status == 'pending') {
        await AuthService.logout();

        if (!mounted) return;

        _navigateToLoginWithMsg(
          'Silakan verifikasi email Anda terlebih dahulu.',
        );
        return;
      }

      // Rejected atau akun tidak aktif
      if (status == 'rejected' || !user.isActive) {
        await AuthService.logout();

        if (!mounted) return;

        _navigateToLoginWithMsg(
          'Akun Vendor Anda telah ditolak atau dinonaktifkan oleh Admin.',
        );
        return;
      }

      // Status lain yang tidak dikenal
      await AuthService.logout();

      if (!mounted) return;

      _navigateToLoginWithMsg(
        'Status akun Anda tidak valid. Silakan hubungi Admin.',
      );
      return;
    }

    // Internal User (Admin, PPIC, Gudang, dll)
    if (!user.isActive) {
      await AuthService.logout();

      if (!mounted) return;

      _navigateToLoginWithMsg(
        'Akun Anda telah dinonaktifkan oleh Admin.',
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/home-admin');
  } catch (e) {
    await AuthService.logout();

    if (!mounted) return;

    _navigateToLoginWithMsg(
      'Terjadi kesalahan saat memeriksa sesi: $e',
    );
  }
}
  void _navigateToLoginWithMsg(String msg) {
  if (!mounted) return;

  Navigator.pushNamedAndRemoveUntil(
    context,
    '/login',
    (route) => false,
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    scaffoldMessenger?.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  });
}

  @override
  Widget build(BuildContext context) {
    return Material(
     
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
      
    );
  }
}