import 'package:flutter/material.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:project_app/login.dart';
import 'package:project_app/vendor/register_vendor.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://izjiqeoydfyhvaqfgnlx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6amlxZW95ZGZ5aHZhcWZnbmx4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4MzU2OTEsImV4cCI6MjA4NDQxMTY5MX0.5nxxKrzD_K2D9JvaADyMJcKpFEC5bLCb0_yvNXtAvKA',
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
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
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register-vendor': (context) => const RegisterVendorPage(),
        '/home-admin': (context) => const DynamicTabPage(role: 'admin'),
        '/home-vendor': (context) => const DynamicTabPage(role: 'vendor'),
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

      if (user == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (user.role?.toLowerCase() == 'vendor') {
        final status = user.status?.toLowerCase();

        if (status == 'verified') {
          Navigator.pushReplacementNamed(context, '/home-vendor');
          return;
        }

        if (status == 'pending') {
          await AuthService.logout();

          if (!mounted) return;

          _navigateToLoginWithMsg(
            'Silakan verifikasi email Anda terlebih dahulu.',
          );
          return;
        }

        if (status == 'rejected' || !user.isActive) {
          await AuthService.logout();

          if (!mounted) return;

          _navigateToLoginWithMsg(
            'Akun Vendor Anda telah ditolak atau dinonaktifkan oleh Admin.',
          );
          return;
        }
        await AuthService.logout();

        if (!mounted) return;

        _navigateToLoginWithMsg(
          'Status akun Anda tidak valid. Silakan hubungi Admin.',
        );
        return;
      }
      if (!user.isActive) {
        await AuthService.logout();

        if (!mounted) return;

        _navigateToLoginWithMsg('Akun Anda telah dinonaktifkan oleh Admin.');
        return;
      }

      Navigator.pushReplacementNamed(context, '/home-admin');
    } catch (e) {
      await AuthService.logout();

      if (!mounted) return;

      _navigateToLoginWithMsg('Terjadi kesalahan saat memeriksa sesi: $e');
    }
  }

  void _navigateToLoginWithMsg(String msg) {
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

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
