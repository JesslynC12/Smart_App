import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login.dart';

class HomepageVendor extends StatefulWidget {
  const HomepageVendor({super.key});

  @override
  State<HomepageVendor> createState() => _HomepageVendorState();
}

class _HomepageVendorState extends State<HomepageVendor> {
  User? currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda ingin keluar dari Portal Vendor?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Status diambil dari AuthService yang melakukan join ke vendor_details
    final bool isApproved = currentUser?.status == 'approved';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Vendor Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: _loadUserData,
              color: Colors.orange.shade800,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 20),
                    _buildStatusBanner(isApproved),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Icon(Icons.grid_view_rounded, size: 20, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        const Text(
                          "Dashboard Layanan",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildVendorMenu(isApproved),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.orange.shade800,
            child: const Icon(Icons.business_center, size: 30, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Menampilkan NIK Vendor
                  "ID: ${currentUser?.nik ?? '-'}",
                  style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  currentUser?.email ?? '-',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Vendor Partner",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isApproved) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isApproved ? Colors.green.shade300 : Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
            color: isApproved ? Colors.green : Colors.red.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApproved ? 'AKUN AKTIF' : 'MENUNGGU VERIFIKASI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isApproved ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
                Text(
                  isApproved
                      ? 'Silakan kelola transaksi dan pengiriman Anda.'
                      : 'Akun Anda sedang ditinjau. Fitur akan aktif setelah disetujui Admin.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorMenu(bool isApproved) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.1,
      children: [
        _menuCard(Icons.shopping_bag_outlined, "Pesanan Baru", Colors.blue, isApproved),
        _menuCard(Icons.receipt_long_outlined, "Riwayat PO", Colors.teal, isApproved),
        _menuCard(Icons.local_shipping_outlined, "Pengiriman", Colors.indigo, isApproved),
        _menuCard(Icons.storefront_outlined, "Katalog Produk", Colors.deepOrange, isApproved),
      ],
    );
  }

  Widget _menuCard(IconData icon, String label, Color color, bool isEnabled) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled 
          ? () { /* Navigasi ke fitur */ } 
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Akses Ditolak: Akun Anda belum diverifikasi oleh Admin.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEnabled ? color.withOpacity(0.1) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 30, color: isEnabled ? color : Colors.grey),
                  ),
                  if (!isEnabled)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(Icons.lock, size: 16, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isEnabled ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}