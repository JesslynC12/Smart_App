import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_app/login.dart';
import '../auth/auth_service.dart';

class RegisterVendorPage extends StatefulWidget {
  const RegisterVendorPage({super.key});

  @override
  State<RegisterVendorPage> createState() => _RegisterVendorPageState();
}

class _RegisterVendorPageState extends State<RegisterVendorPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final emailController = TextEditingController();
  final nikController = TextEditingController();
  final nameController = TextEditingController();
  final registCodeController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscurePasswordConfirm = true;

  @override
  void dispose() {
    emailController.dispose();
    nikController.dispose();
    nameController.dispose();
    registCodeController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  // --- LOGIKA REGISTRASI ---
  // Disesuaikan dengan AuthService: registerVendor(email, password, name, nikInput, registCodeInput)
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      await AuthService.registerVendor(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        name: nameController.text.trim(),
        nikInput: nikController.text.trim(),
        registCodeInput: registCodeController.text.trim().toUpperCase(),
      );

      if (!mounted) return;

      _showSuccessDialog();
    } catch (e) {
      // Menghilangkan prefix 'Exception: ' agar pesan lebih bersih di SnackBar
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pendaftaran Berhasil'),
        content: const Text(
            'Akun Anda telah didaftarkan. Silakan cek email untuk verifikasi, lalu tunggu persetujuan admin untuk bisa login.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('SAYA MENGERTI',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating),
    );
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _customTextField(
                      label: 'NIK Vendor (ID 8 Karakter)',
                      controller: nikController,
                      hint: 'Masukkan 8 karakter NIK',
                      icon: Icons.badge_outlined,
                      inputFormatters: [LengthLimitingTextInputFormatter(8)],
                      validator: (v) =>
                          v!.length != 8 ? 'NIK harus 8 karakter' : null,
                    ),
                    _customTextField(
                      label: 'Nama Admin Vendor',
                      controller: nameController,
                      hint: 'Nama penanggung jawab',
                      icon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    _customTextField(
                      label: 'Registration Code',
                      controller: registCodeController,
                      hint: 'Masukkan kode registrasi dari Admin',
                      icon: Icons.vpn_key_outlined,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    _customTextField(
                      label: 'Email Perusahaan',
                      controller: emailController,
                      hint: 'email@perusahaan.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          !v!.contains('@') ? 'Email tidak valid' : null,
                    ),
                    _customTextField(
                      label: 'Password',
                      controller: passwordController,
                      hint: 'Minimal 6 karakter',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscure: obscurePassword,
                      onToggle: () =>
                          setState(() => obscurePassword = !obscurePassword),
                      validator: (v) =>
                          v!.length < 6 ? 'Password minimal 6 karakter' : null,
                    ),
                    _customTextField(
                      label: 'Konfirmasi Password',
                      controller: passwordConfirmController,
                      hint: 'Ulangi password',
                      icon: Icons.lock_reset,
                      isPassword: true,
                      obscure: obscurePasswordConfirm,
                      onToggle: () => setState(() =>
                          obscurePasswordConfirm = !obscurePasswordConfirm),
                      validator: (v) => v != passwordController.text
                          ? 'Password tidak cocok'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _buildRegisterButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.business_outlined, size: 60, color: Colors.red.shade700),
        const SizedBox(height: 16),
        Text(
          'Registrasi Vendor',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade900),
        ),
        const Text('Lengkapi data untuk mendaftarkan akun',
            style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'DAFTAR SEKARANG',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
      ),
    );
  }

  Widget _customTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.red.shade700),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggle)
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade700, width: 2)),
        ),
      ),
    );
  }
}