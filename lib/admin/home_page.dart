import 'package:flutter/material.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_service.dart' as auth_model;
import '../login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  auth_model.User? currentUser;
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
          final supabase = Supabase.instance.client;

          final expiredAssignments = await supabase
              .from('shipping_assignments')
              .update({
                'status_assignment': 'no response',
                'responded_at': DateTime.now().toIso8601String(),
              })
              .eq('status_assignment', 'offered')
              .lt(
                'assigned_at',
                DateTime.now()
                    .subtract(const Duration(hours: 2))
                    .toIso8601String(),
              )
              .select('shipping_id');

          if ((expiredAssignments as List).isNotEmpty) {
            List<int> expiredShippingIds = List<int>.from(
              expiredAssignments.map((e) => e['shipping_id']),
            );

            await supabase
                .from('shipping_request')
                .update({'status': 'waiting assign vendor delivery'})
                .inFilter('shipping_id', expiredShippingIds);

            debugPrint(
              "Berhasil membersihkan ${expiredShippingIds.length} orderan expired secara otomatis.",
            );
          }
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.red.shade700;

    String roleDisplay = "User";
    if (currentUser?.role != null && currentUser!.role!.isNotEmpty) {
      roleDisplay =
          currentUser!.role![0].toUpperCase() + currentUser!.role!.substring(1);
    }

    return Material(
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildHeaderSection(Color color, String roleDisplay) {
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
            currentUser?.nik ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentUser?.role?.toUpperCase() ?? 'STAFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (currentUser != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: currentUser!.isActive
                        ? Colors.green.withOpacity(0.8)
                        : Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentUser!.isActive
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentUser!.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.badge_outlined,
            'NIK / ID Pegawai',
            currentUser?.nik ?? '-',
            themeColor,
          ),
          _infoRow(
            Icons.email_outlined,
            'Email',
            currentUser?.email ?? '-',
            themeColor,
          ),
          _infoRow(
            Icons.security_outlined,
            'Role Akses',
            currentUser?.role ?? '-',
            themeColor,
          ),
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
