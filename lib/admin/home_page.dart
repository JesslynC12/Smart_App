import 'package:flutter/material.dart';
// Gunakan alias 'model' untuk menghindari konflik dengan class User milik package Supabase
import '../auth/auth_service.dart' as model;
import '../auth/auth_service.dart'; // Import untuk akses static method AuthService
import '../login.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});


  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  // Gunakan model.User sesuai definisi class User buatan kita
  model.User? currentUser;
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }


  Future<void> _loadCurrentUser() async {
    setState(() => isLoading = true);
    try {
      // Mengambil data user terbaru
      final user = await AuthService.getCurrentUser();


      if (mounted) {
        if (user == null) {
          // JIKA USER NULL (Sesi Habis/Token Invalid), Lempar ke Login
          _handleSessionExpired();
        } else {
          // JIKA SUKSES
          setState(() {
            currentUser = user;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Gagal memuat profil: $e', Colors.red);
      }
    }
  }


  void _handleSessionExpired() {
    _showSnackBar('Sesi berakhir, silakan login kembali.', Colors.orange);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }


  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')
          ),
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
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.red.shade700;
   
    // Logika menampilkan Nama Role di Appbar agar lebih rapi
    String roleDisplay = "Admin";
    if (currentUser?.role != null && currentUser!.role!.isNotEmpty) {
      roleDisplay = currentUser!.role![0].toUpperCase() + currentUser!.role!.substring(1);
    }


    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          '$roleDisplay Dashboard',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
                         
                          // Kartu Profil Utama
                          _buildProfileCard(primaryColor),
                         
                          // Menampilkan Privileges (Hak Akses) jika ada
                          if (currentUser?.privileges.isNotEmpty ?? false) ...[
                             const SizedBox(height: 20),
                             const Text("Hak Akses", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 10),
                             Wrap(
                               spacing: 8,
                               runSpacing: 8,
                               children: currentUser!.privileges.map((priv) => Chip(
                                 label: Text(priv, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                 backgroundColor: Colors.grey.shade700,
                                 visualDensity: VisualDensity.compact,
                               )).toList(),
                             )
                          ]
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
            accountEmail: Text(currentUser?.email ?? '-'),
          ),
         
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


          ExpansionTile(
            leading: const Icon(Icons.settings_suggest_outlined),
            title: const Text("Entry", style: TextStyle(fontWeight: FontWeight.w600)),
            initiallyExpanded: true,
            children: [
              _menuItem(Icons.assignment_ind_outlined, "Presensi", Colors.blue),
              _menuItem(Icons.local_shipping_outlined, "Loading Barang", Colors.orange),
             
              // LOGIKA: Sembunyikan 'Manajemen User' jika role adalah 'vendor'
              if (currentUser?.role != 'vendor')
                _menuItem(Icons.manage_accounts_outlined, "Manajemen User", Colors.purple),
             
              _menuItem(Icons.inventory_2_outlined, "Master Produk", Colors.teal),
            ],
          ),
         
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text("Keluar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }


  Widget _menuItem(IconData icon, String title, Color color) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
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
            currentUser?.nik ?? 'User',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Badge Role
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
              const SizedBox(width: 8),
             
              // Badge Status Aktif/Non-Aktif
              if (currentUser != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    // Warna Hijau jika true, Merah jika false
                    color: currentUser!.isActive ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentUser!.isActive ? Icons.check_circle : Icons.cancel,
                        size: 12, color: Colors.white
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentUser!.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
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
          _infoRow(Icons.email_outlined, 'Email', currentUser?.email ?? '-', themeColor),
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

