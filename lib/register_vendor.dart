import 'package:flutter/material.dart';
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
  final usernameController = TextEditingController();
  final companyNameController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  // States
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscurePasswordConfirm = true;
  int currentStep = 0;

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    companyNameController.dispose();
    addressController.dispose();
    cityController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);

    try {
      await AuthService.registerVendor(
        email: emailController.text.trim(),
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
        companyName: companyNameController.text.trim(),
        address: addressController.text.trim(),
        city: cityController.text.trim(),
        phone: phoneController.text.trim(),
      );

      if (!mounted) return;

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
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue.shade600),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildStepProgress(),
                const SizedBox(height: 32),
                
                // Animasi transisi sederhana antar step
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentStep == 0 ? _buildAccountStep() : _buildCompanyStep(),
                ),

                const SizedBox(height: 32),
                _buildNavigationButtons(),
                const SizedBox(height: 16),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.business_center_rounded, size: 40, color: Colors.blue.shade600),
        ),
        const SizedBox(height: 16),
        Text(
          'Daftar Vendor',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
        ),
        const SizedBox(height: 8),
        Text('Lengkapi data perusahaan Anda', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildStepProgress() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start, // Sejajarkan lingkaran
      children: [
        _stepCircle(1, "Akun", currentStep >= 0),
        Padding(
          padding: const EdgeInsets.only(top: 18), // Menurunkan garis agar pas di tengah lingkaran
          child: _stepLine(currentStep >= 1),
        ),
        _stepCircle(2, "Perusahaan", currentStep >= 1),
      ],
    );
  }

  Widget _stepCircle(int step, String label, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 35, height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
          child: Center(
            child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.blue.shade600 : Colors.grey)),
      ],
    );
  }

  Widget _stepLine(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 60, height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isActive ? Colors.blue.shade600 : Colors.grey.shade300,
    );
  }

  Widget _buildAccountStep() {
    return Column(
      key: const ValueKey(0),
      children: [
        _customTextField(
          label: 'Email Pengguna',
          controller: emailController,
          hint: 'nama@perusahaan.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
        _customTextField(
          label: 'Username Akun',
          controller: usernameController,
          hint: 'username_vendor',
          icon: Icons.person_outline,
          validator: (v) => v!.isEmpty ? 'Username wajib diisi' : null,
        ),
        _customTextField(
          label: 'Password',
          controller: passwordController,
          hint: 'Minimal 6 karakter',
          icon: Icons.lock_outline,
          isPassword: true,
          obscure: obscurePassword,
          onToggle: () => setState(() => obscurePassword = !obscurePassword),
          validator: (v) => v!.length < 6 ? 'Minimal 6 karakter' : null,
        ),
        _customTextField(
          label: 'Konfirmasi Password',
          controller: passwordConfirmController,
          hint: 'Ulangi password',
          icon: Icons.lock_reset,
          isPassword: true,
          obscure: obscurePasswordConfirm,
          onToggle: () => setState(() => obscurePasswordConfirm = !obscurePasswordConfirm),
          validator: (v) => v != passwordController.text ? 'Password tidak sama' : null,
        ),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Column(
      key: const ValueKey(1),
      children: [
        _customTextField(
          label: 'Nama Resmi Perusahaan',
          controller: companyNameController,
          hint: 'PT. XXX Indonesia',
          icon: Icons.business,
          validator: (v) => v!.isEmpty ? 'Nama perusahaan wajib diisi' : null,
        ),
        _customTextField(
          label: 'Alamat Kantor Pusat',
          controller: addressController,
          hint: 'Jl. Nama Jalan No. 123',
          icon: Icons.location_on_outlined,
          validator: (v) => v!.isEmpty ? 'Alamat wajib diisi' : null,
        ),
        _customTextField(
          label: 'Kota',
          controller: cityController,
          hint: 'Masukan Kota',
          icon: Icons.location_city,
          validator: (v) => v!.isEmpty ? 'Kota wajib diisi' : null,
        ),
        _customTextField(
          label: 'Nomor WhatsApp/Telepon',
          controller: phoneController,
          hint: '081234567xxx',
          icon: Icons.phone_android,
          keyboardType: TextInputType.phone,
          validator: (v) => v!.isEmpty ? 'Nomor telepon wajib diisi' : null,
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : () => setState(() => currentStep = 0),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.blue.shade600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kembali'),
            ),
          ),
        if (currentStep > 0) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : () {
              if (currentStep == 0) {
                // Hanya validasi field di step 1 sebelum lanjut
                if (_formKey.currentState!.validate()) {
                  setState(() => currentStep = 1);
                }
              } else {
                _register();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(currentStep == 0 ? 'Lanjutkan' : 'Daftar Sekarang', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Sudah punya akun?"),
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          ),
          child: const Text('Login di sini', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 20),
            suffixIcon: isPassword 
              ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: onToggle)
              : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade600)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}