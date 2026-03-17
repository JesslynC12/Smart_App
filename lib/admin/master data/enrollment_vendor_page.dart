import 'package:flutter/material.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorEnrollmentPage extends StatefulWidget {
  const VendorEnrollmentPage({super.key});

  @override
  State<VendorEnrollmentPage> createState() => _VendorEnrollmentPageState();
}

class _VendorEnrollmentPageState extends State<VendorEnrollmentPage> {
  final _supabase = Supabase.instance.client;

  Future<void> _handleAction(String id, String name, String status) async {
    final actionText = status == 'verified' ? 'Memverifikasi' : 'Menolak';
    final confirmColor = status == 'verified' ? Colors.green : Colors.red;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi $actionText'),
        content: Text('Apakah Anda yakin ingin $status vendor "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
            child: Text('Ya, $status'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService.updateVendorStatus(id, status);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vendor $name telah di-$status'),
              backgroundColor: confirmColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Enrollment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Stream memantau tabel profiles dengan filter status pending
        stream: _supabase
            .from('profiles')
            .stream(primaryKey: ['id'])
            //.eq('role', 'vendor')
            .eq('status', 'pending')
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada pendaftaran vendor baru.'));
          }

          final vendors = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendorProfile = vendors[index];
              final String vendorId = vendorProfile['id'];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _supabase
                    .from('profiles_vendor')
                    .select()
                    .eq('profile_id', vendorId)
                    .maybeSingle(),
                builder: (context, detailSnapshot) {
                  final detail = detailSnapshot.data;
                  final String namaPT = detail?['nama_perusahaan'] ?? 
                                       (detailSnapshot.connectionState == ConnectionState.waiting ? 'Loading...' : 'Nama Tidak Ada');
                  
                  // UI Card
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(namaPT, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                              ),
                              _buildStatusChip('pending'),
                            ],
                          ),
                          const Divider(),
                          _rowDetail(Icons.badge, "NIK", vendorProfile['nik'] ?? '-'),
                          _rowDetail(Icons.email, "Email", vendorProfile['email'] ?? '-'),
                          const SizedBox(height: 8),
                          const Text("Detail Perusahaan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          _rowDetail(Icons.location_on, "Alamat", detail?['alamat'] ?? '-'),
                          _rowDetail(Icons.phone, "No. Telp", detail?['phone'] ?? '-'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleAction(vendorId, namaPT, 'rejected'),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text("REJECT"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleAction(vendorId, namaPT, 'verified'),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text("VERIFY"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _rowDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: const Text("PENDING", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}