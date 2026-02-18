import 'package:flutter/material.dart';
import 'package:project_app/admin/home_page.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:project_app/vendor/homepage_vendor.dart';
import 'package:project_app/vendor/register_vendor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Menggunakan identifier karena bisa berisi NIK atau Email
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();
  
  bool isLoading = false;
  bool rememberMe = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedIdentifier();
  }

  // Memuat NIK/Email yang tersimpan
  Future<void> _loadSavedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_user_login');
    if (savedUser != null) {
      setState(() {
        identifierController.text = savedUser;
        rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    final identifier = identifierController.text.trim();
    final password = passwordController.text.trim();

    // Validasi Input Kosong
    if (identifier.isEmpty || password.isEmpty) {
      _showErrorSnackBar('NIK/Email & Password harus diisi');
      return;
    }

    // Validasi Panjang NIK (Jika input bukan email, asumsikan itu NIK)
    if (!identifier.contains('@') && identifier.length != 8) {
      _showErrorSnackBar('NIK harus berjumlah 8 karakter');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Memanggil AuthService yang sudah mendukung pencarian NIK/Email
      final user = await AuthService.login(identifier, password);

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('saved_user_login', identifier);
        } else {
          await prefs.remove('saved_user_login');
        }

        if (mounted) _navigateBasedOnRole(user);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
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
              // Header Icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.badge_outlined, size: 40, color: Colors.red.shade700),
              ),
              const SizedBox(height: 24),
              Text(
                'Selamat Datang',
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.red.shade700
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Silakan login dengan NIK atau Email',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Input NIK atau Email
              TextField(
                controller: identifierController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'NIK / Email',
                  hintText: 'Masukkan 8 digit NIK atau Email',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done, // Menampilkan tombol 'Done' atau 'Masuk'
  onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)
                  ),
                ),
              ),

              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (val) => setState(() => rememberMe = val ?? false),
                    activeColor: Colors.red.shade700,
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
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                    elevation: 0,
                  ),
                  child: isLoading 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      )
                    : const Text(
                        'Login', 
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                ),
              ),
              const SizedBox(height: 24),

              // Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Vendor baru? "),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const RegisterVendorPage())
                    ),
                    child: Text(
                      'Daftar Perusahaan', 
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)
                    ),
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