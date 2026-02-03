import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'home_page.dart'; // Untuk Admin
import 'homepage_vendor.dart'; // Untuk Vendor
import 'register_vendor.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    if (email != null) {
      setState(() {
        emailController.text = email;
        rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Email & Password harus diisi');
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await AuthService.login(email, password);

      if (user != null) {
        // Simpan email jika "Remember Me"
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('saved_email', email);
        } else {
          await prefs.remove('saved_email');
        }

        if (mounted) _navigateBasedOnRole(user);
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _navigateBasedOnRole(User user) {
    if (user.role == 'vendor') {
      if (user.status == 'approved') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomepageVendor()),
        );
      } else {
        _showErrorSnackBar('Akun vendor Anda sedang dalam proses verifikasi.');
      }
    } else {
      // Role Admin (PPIC, Logistic, dll)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Logo/Icon Header
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.lock_person_rounded, size: 40, color: Colors.blue.shade600),
              ),
              const SizedBox(height: 24),
              Text(
                'Selamat Datang',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
              const Text('Silakan login untuk melanjutkan'),
              const SizedBox(height: 40),

              // Email
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Password
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (val) => setState(() => rememberMe = val ?? false),
                    activeColor: Colors.blue.shade600,
                  ),
                  const Text('Ingat saya'),
                ],
              ),
              const SizedBox(height: 32),

              // Button Login
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),

              // Khusus Link Register Vendor
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Vendor baru? "),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterVendorPage())),
                    child: Text('Daftar Perusahaan', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}