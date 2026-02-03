import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() => isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          currentUser = user;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Gagal memuat profil: $e', Colors.red);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Logout gagal: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definisi warna utama aplikasi
    final primaryColor = Colors.red.shade700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
  // Menghapus 'const' karena isinya dinamis
  title: Text(
    // Logika penyesuaian nama dashboard
    '${currentUser?.role != null ? currentUser!.role![0].toUpperCase() + currentUser!.role!.substring(1) : "Smart Admin"} Dashboard', 
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
  ),
  backgroundColor: primaryColor,
  foregroundColor: Colors.white,
  elevation: 0,
  actions: [
    IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout),
  ],
),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadCurrentUser,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeaderSection(primaryColor),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMenuGrid(primaryColor),
                          const SizedBox(height: 25),
                          _buildProfileCard(primaryColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSection(Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20, top: 10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selamat Datang,',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          currentUser?.nik ?? 'Memuat Data...',
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 24, // Diperbesar karena inisial dihapus
            fontWeight: FontWeight.bold
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            currentUser?.role?.toUpperCase() ?? 'STAFF',
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.2
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildMenuGrid(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Manajemen Sistem", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.4,
          ),
          children: [
            _menuItem(Icons.people_alt_outlined, "Approval Vendor", Colors.orange, color),
            _menuItem(Icons.inventory_2_outlined, "Master Produk", Colors.blue, color),
            _menuItem(Icons.assignment_turned_in_outlined, "Validasi PO", Colors.green, color),
            _menuItem(Icons.settings_suggest_outlined, "Konfigurasi", Colors.grey, color),
          ],
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, Color iconColor, Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _infoRow(Icons.badge_outlined, 'NIK / ID Pegawai', currentUser?.nik ?? '-', themeColor),
          _infoRow(Icons.email_outlined, 'Email Internal', currentUser?.email ?? '-', themeColor),
          _infoRow(Icons.security_outlined, 'Role Akses', currentUser?.role ?? '-', themeColor),
          if (currentUser?.privileges.isNotEmpty ?? false)
            _infoRow(Icons.lock_open_rounded, 'Hak Akses Tambahan', currentUser!.privileges.join(', '), themeColor),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}