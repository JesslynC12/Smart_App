import 'package:flutter/material.dart';
// import 'package:project_app/admin/main_drawer.dart';
// import 'package:project_app/admin/display/listDO_page.dart' show ListDOPage;
// import 'package:project_app/admin/display/listDOdetailsGBJ_page.dart';
// import 'package:project_app/admin/display/listVendorRequest_page.dart';
// import 'package:project_app/admin/input%20form/formComplain_page.dart';
// import 'package:project_app/admin/input%20form/formOccupancy_page.dart';
// import 'package:project_app/admin/input%20form/formDO_page.dart';
// import 'package:project_app/admin/input%20form/formKelayakanunit_page.dart';
// import 'package:project_app/admin/master%20data/checker_master.dart';
// import 'package:project_app/admin/master%20data/customer_master.dart';
// import 'package:project_app/admin/master%20data/manage_user_vendor.dart';
// import 'package:project_app/admin/master%20data/material_master.dart';
// import 'package:project_app/admin/master%20data/vendor_transportasi_master.dart';
// import 'package:project_app/admin/master%20data/enrollment_vendor_page.dart';
// import 'package:project_app/admin/master%20data/warehouse_master.dart';
// import 'package:project_app/dynamic_tab_page.dart';
// Gunakan alias 'model' untuk menghindari konflik dengan class User milik package Supabase
// import '../auth/auth_service.dart' as model;
import '../auth/auth_service.dart'; 
import '../login.dart';
// import 'package:project_app/admin/master%20data/manage_user.dart'; 


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
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();

      if (mounted) {
        if (user == null) {
          _handleSessionExpired();
        } else {
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

  // --- HELPER UNTUK CEK HAK AKSES ---
  // bool _hasAccess(String privilegeName) {
  //   // 1. Jika Admin, anggap punya semua akses (Opsional, untuk kemudahan)
  //   if (currentUser?.role == 'admin') return true; 

  //   // 2. Cek apakah privilegeName ada di list privileges user
  //   // Pastikan string ini SAMA PERSIS dengan kolom 'name' di Database Supabase
  //   return currentUser?.privileges.contains(privilegeName) ?? false;
  // }

//   bool _hasAccess(String privilegeName) {
//   // Pengecekan ketat: Hanya cek daftar privileges yang dimiliki user
//   // Tidak peduli apakah dia Admin, Staff, atau Manager.
//   return currentUser?.privileges.contains(privilegeName) ?? false;
// }

  // Future<void> _logout() async {
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  //       title: const Text('Konfirmasi Logout'),
  //       content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text('Batal')
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirm != true) return;

  //   try {
  //     await AuthService.logout();
  //     if (mounted) {
  //       Navigator.of(context).pushAndRemoveUntil(
  //         MaterialPageRoute(builder: (context) => const LoginPage()),
  //         (route) => false,
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) _showSnackBar('Logout gagal: $e', Colors.red);
  //   }
  // }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   final primaryColor = Colors.red.shade700;
    
  //   String roleDisplay = "Admin";
  //   if (currentUser?.role != null && currentUser!.role!.isNotEmpty) {
  //     roleDisplay = currentUser!.role![0].toUpperCase() + currentUser!.role!.substring(1);
  //   }

  //   return Scaffold(
  //     backgroundColor: Colors.grey.shade50,
  //     appBar: AppBar(
  //       title: Text(
  //         '$roleDisplay Dashboard',
  //         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
  //       ),
  //       backgroundColor: primaryColor,
  //       foregroundColor: Colors.white,
  //       elevation: 0,
  //       // Tambahkan tombol menu manual jika Drawer tidak muncul otomatis
  //       leading: Builder(
  //         builder: (context) => IconButton(
  //           icon: const Icon(Icons.menu),
  //           onPressed: () => Scaffold.of(context).openDrawer(),
  //         ),
  //       ),
    
  //     ),
  //     drawer: _buildDrawer(primaryColor, roleDisplay),
  //     body: isLoading
  //         ? Center(child: CircularProgressIndicator(color: primaryColor))
  //         : RefreshIndicator(
  //             onRefresh: _loadCurrentUser,
  //             color: primaryColor,
  //             child: SingleChildScrollView(
  //               physics: const AlwaysScrollableScrollPhysics(),
  //               child: Column(
  //                 children: [
  //                   _buildHeaderSection(primaryColor, roleDisplay),
  //                   Padding(
  //                     padding: const EdgeInsets.all(20),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         const Text("Informasi Akun", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //                         const SizedBox(height: 15),
                          
  //                         _buildProfileCard(primaryColor),
                          
  //                         // Menampilkan Chip Privileges (Hak Akses)
  //                         // if (currentUser?.privileges.isNotEmpty ?? false) ...[
  //                         //    const SizedBox(height: 20),
  //                         //    const Text("Hak Akses Fitur", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //                         //    const SizedBox(height: 10),
  //                         //    Wrap(
  //                         //      spacing: 8,
  //                         //      runSpacing: 8,
  //                         //      children: currentUser!.privileges.map((priv) => Chip(
  //                         //        avatar: const Icon(Icons.check_circle, size: 16, color: Colors.white),
  //                         //        label: Text(priv, style: const TextStyle(fontSize: 11, color: Colors.white)),
  //                         //        backgroundColor: Colors.grey.shade700,
  //                         //        visualDensity: VisualDensity.compact,
  //                         //      )).toList(),
  //                         //    )
  //                         // ]
  //                       ],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //   );
//   // }
//   @override
// Widget build(BuildContext context) {
//   final primaryColor = Colors.red.shade700;

//   String roleDisplay = "Admin";
//   if (currentUser?.role != null && currentUser!.role!.isNotEmpty) {
//     roleDisplay = currentUser!.role![0].toUpperCase() +
//         currentUser!.role!.substring(1);
//   }

//   // ❌ HAPUS SCAFFOLD
//   return Container(
//     color: Colors.grey.shade50,
//     child: isLoading
//         ? Center(child: CircularProgressIndicator(color: primaryColor))
//         : RefreshIndicator(
//             onRefresh: _loadCurrentUser,
//             color: primaryColor,
//             child: SingleChildScrollView(
//               physics: const AlwaysScrollableScrollPhysics(),
//               child: Column(
//                 children: [
//                   _buildHeaderSection(primaryColor, roleDisplay),
//                   Padding(
//                     padding: const EdgeInsets.all(20),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           "Informasi Akun",
//                           style: TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold),
//                         ),
//                         const SizedBox(height: 15),
//                         _buildProfileCard(primaryColor),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//   );
// }
@override
Widget build(BuildContext context) {
  final primaryColor = Colors.red.shade700;

  String roleDisplay = "User";
  if (currentUser?.role != null && currentUser!.role!.isNotEmpty) {
    roleDisplay = currentUser!.role![0].toUpperCase() + currentUser!.role!.substring(1);
  }

  return Material(
    // 1. Tambahkan AppBar agar bisa membuka Drawer
    // appBar: AppBar(
    //   // title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
    //   backgroundColor: primaryColor,
    //   foregroundColor: Colors.white,
    //   elevation: 0,
    // ),

    // 2. Hubungkan dengan MainDrawer yang sudah dibuat sebelumnya
    // drawer: MainDrawer(currentUser: currentUser),

    color: Colors.grey.shade50,
      child: isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : RefreshIndicator(
            onRefresh: _loadCurrentUser,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeaderSection(primaryColor, roleDisplay),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Informasi Akun",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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
  


//   Widget _menuItem(IconData icon, String title, Color color, {VoidCallback? onTap}) {
//     return ListTile(
//       contentPadding: const EdgeInsets.symmetric(horizontal: 32),
//       leading: Icon(icon, color: color, size: 22),
//       title: Text(title, style: const TextStyle(fontSize: 14)),
//       onTap: () {
//         // Default action
//         Navigator.pop(context);
//        if (onTap != null) {
//         onTap();
//       } else {
//         _showSnackBar('Fitur $title belum diimplementasikan', Colors.grey);
//       }
//     },
//   );
// }

  Widget _buildHeaderSection(Color color,String roleDisplay) {
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
              if (currentUser != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
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