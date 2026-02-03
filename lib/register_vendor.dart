import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_app/login.dart';
import 'auth_service.dart';

class RegisterVendorPage extends StatefulWidget {
  const RegisterVendorPage({super.key});

  @override
  State<RegisterVendorPage> createState() => _RegisterVendorPageState();
}

class _RegisterVendorPageState extends State<RegisterVendorPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final emailController = TextEditingController();
  final nikController = TextEditingController(); // Sudah disesuaikan ke NIK
  final companyNameController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscurePasswordConfirm = true;
  int currentStep = 0;

  @override
  void dispose() {
    emailController.dispose();
    nikController.dispose();
    companyNameController.dispose();
    addressController.dispose();
    cityController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  // --- LOGIKA REGISTRASI ---
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);

    try {
      await AuthService.registerVendor(
        email: emailController.text.trim(),
        nik: nikController.text.trim().toUpperCase(), // NIK otomatis Uppercase
        password: passwordController.text.trim(),
        companyName: companyNameController.text.trim(),
        address: addressController.text.trim(),
        city: cityController.text.trim(),
        phone: phoneController.text.trim(),
      );

      if (!mounted) return;

      _showSuccessDialog();
    } catch (e) {
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
        content: const Text('Akun Anda telah didaftarkan. Silakan tunggu persetujuan admin untuk bisa login.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('SAYA MENGERTI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStepProgress(),
                const SizedBox(height: 32),
                
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentStep == 0 ? _buildAccountStep() : _buildCompanyStep(),
                ),

                const SizedBox(height: 24),
                _buildNavigationButtons(),
                const SizedBox(height: 16),
              ],
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
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900),
        ),
        const Text('Daftarkan perusahaan Anda ke sistem', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildStepProgress() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepCircle(1, "Akun", currentStep >= 0),
        _stepLine(currentStep >= 1),
        _stepCircle(2, "Profil", currentStep >= 1),
      ],
    );
  }

  Widget _stepCircle(int step, String label, bool isActive) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isActive ? Colors.red.shade700 : Colors.grey.shade300,
          child: Text('$step', style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _stepLine(bool isActive) => Container(width: 50, height: 2, color: isActive ? Colors.red.shade700 : Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _buildAccountStep() {
    return Column(
      key: const ValueKey(0),
      children: [
        _customTextField(
          label: 'NIK Vendor (ID 8 Karakter)',
          controller: nikController,
          hint: 'Contoh: VEND0001',
          icon: Icons.badge_outlined,
          inputFormatters: [LengthLimitingTextInputFormatter(8)],
          validator: (v) => v!.length != 8 ? 'NIK harus 8 karakter' : null,
        ),
        _customTextField(
          label: 'Email Perusahaan',
          controller: emailController,
          hint: 'email@perusahaan.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => !v!.contains('@') ? 'Email tidak valid' : null,
        ),
        _customTextField(
          label: 'Password',
          controller: passwordController,
          hint: 'Minimal 6 karakter',
          icon: Icons.lock_outline,
          isPassword: true,
          obscure: obscurePassword,
          onToggle: () => setState(() => obscurePassword = !obscurePassword),
          validator: (v) => v!.length < 6 ? 'Password terlalu pendek' : null,
        ),
        _customTextField(
          label: 'Konfirmasi Password',
          controller: passwordConfirmController,
          hint: 'Ulangi password',
          icon: Icons.lock_reset,
          isPassword: true,
          obscure: obscurePasswordConfirm,
          onToggle: () => setState(() => obscurePasswordConfirm = !obscurePasswordConfirm),
          validator: (v) => v != passwordController.text ? 'Password tidak cocok' : null,
        ),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Column(
      key: const ValueKey(1),
      children: [
        _customTextField(
          label: 'Nama Perusahaan',
          controller: companyNameController,
          hint: 'PT. Maju Bersama',
          icon: Icons.business,
          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
        ),
        _customTextField(
          label: 'Alamat Lengkap',
          controller: addressController,
          hint: 'Jl. Industri No. 12',
          icon: Icons.location_on_outlined,
          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
        ),
        _customTextField(
          label: 'Kota',
          controller: cityController,
          hint: 'Jakarta Selatan',
          icon: Icons.location_city,
          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
        ),
        _customTextField(
          label: 'Nomor WhatsApp/Telepon',
          controller: phoneController,
          hint: '0812xxxxxxxx',
          icon: Icons.phone_android,
          keyboardType: TextInputType.phone,
          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
        ),
      ],
    );
  }
Widget _buildNavigationButtons() {
  return Column(
    children: [
      Row(
  children: [
    if (currentStep > 0)
      Expanded(
        child: SizedBox(
          height: 55,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () => setState(() => currentStep = 0),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.shade700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Kembali',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
          if (currentStep > 0) const SizedBox(width: 12),

          Expanded(
            child: SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        if (currentStep == 0) {
                          if (_formKey.currentState!.validate()) {
                            setState(() => currentStep = 1);
                          }
                        } else {
                          _register();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        currentStep == 0
                            ? 'Lanjutkan'
                            : 'Daftar Sekarang',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ],
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.red.shade700),
          suffixIcon: isPassword ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: onToggle) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade700, width: 2)),
        ),
      ),
    );
  }
}