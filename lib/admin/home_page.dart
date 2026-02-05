import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../login.dart';

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
    final primaryColor = Colors.red.shade700;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        // --- LOGIKA NAMA DASHBOARD TETAP DI SINI ---
        title: Text(
          '${currentUser?.role != null ? currentUser!.role![0].toUpperCase() + currentUser!.role!.substring(1) : "Smart Admin"} Dashboard', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // Drawer untuk menu samping
      drawer: _buildDrawer(primaryColor),
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
                          const Text("Informasi Akun", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
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

  Widget _buildDrawer(Color themeColor) {
    return Drawer(
      child: Column(
        children: [
          // Header Kategori Profil
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: themeColor),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.red),
            ),
            accountName: Text(
              currentUser?.nik ?? 'Loading...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(currentUser?.email ?? 'Smart Admin User'),
          ),
          
          // Header Kategori Menu
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "SISTEM OPERASIONAL",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          ),

          // Menu Drop-down menggunakan ExpansionTile
          ExpansionTile(
            leading: const Icon(Icons.settings_suggest_outlined),
            title: const Text("Entry", style: TextStyle(fontWeight: FontWeight.w600)),
            initiallyExpanded: true, // Biar langsung terbuka saat drawer dibuka
            children: [
              _menuItem(Icons.assignment_ind_outlined, "Presensi", Colors.blue),
              _menuItem(Icons.local_shipping_outlined, "Loading Barang", Colors.orange),
              _menuItem(Icons.manage_accounts_outlined, "Manajemen User", Colors.purple,),
              _menuItem(Icons.inventory_2_outlined, "Master Produk", Colors.teal),
            ],
          ),
          

          const Spacer(), // Dorong menu logout ke bawah
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text("Keluar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context); // Tutup drawer dulu
              _logout();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Widget helper untuk item di dalam ExpansionTile
  Widget _menuItem(IconData icon, String title, Color color) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context); // Tutup drawer
        _showSnackBar('Membuka $title...', color);
      },
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
          const Text('Selamat Datang,', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            currentUser?.nik ?? 'Memuat Data...',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentUser?.role?.toUpperCase() ?? 'STAFF',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.badge_outlined, 'NIK / ID Pegawai', currentUser?.nik ?? '-', themeColor),
          _infoRow(Icons.email_outlined, 'Email Internal', currentUser?.email ?? '-', themeColor),
          _infoRow(Icons.security_outlined, 'Role Akses', currentUser?.role ?? '-', themeColor),
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