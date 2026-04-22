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

final TextEditingController _reasonController = TextEditingController();

@override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
  
  Future<void> _handleAction(String id, String name, String status) async {
    String? rejectReason;
  //   final actionText = status == 'verified' ? 'Memverifikasi' : 'Menolak';
  //   final confirmColor = status == 'verified' ? Colors.green : Colors.red;

  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('Konfirmasi $actionText'),
  //       content: Text('Apakah Anda yakin ingin $status vendor "$name"?'),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
  //           child: Text('Ya, $status'),
  //         ),
  //       ],
  //     ),
  //   );

  //   // if (confirm == true) {
  //   //   try {
  //   //     await AuthService.updateVendorStatus(id, status);
  //   //     if (mounted) {
  //   //       ScaffoldMessenger.of(context).showSnackBar(
  //   //         SnackBar(
  //   //           content: Text('Vendor $name telah di-$status'),
  //   //           backgroundColor: confirmColor,
  //   //           behavior: SnackBarBehavior.floating,
  //   //         ),
  //   //       );
  //   //     }
  //   //   } catch (e) {

  //   if (confirm == true) {
  //   try {
  //     // UPDATE KE TABEL PROFILES_VENDOR
  //     await _supabase
  //         .from('profiles_vendor')
  //         .update({'status': status})
  //         .eq('profile_id', id);

  //     if (mounted) {
  //       setState(() {}); // MEMAKSA UI REBUILD
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Vendor $name telah di-$status'), backgroundColor: confirmColor),
  //       );
  //     }
  //   } catch (e) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
  //         );
  //       }
  //     }
  //   }
  // }
  // Tambahkan controller di dalam _VendorEnrollmentPageState

  if (status == 'rejected') {
    // Tampilkan Dialog Input Alasan
    rejectReason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alasan Menolak $name'),
        content: TextField(
          controller: _reasonController,
          decoration: const InputDecoration(
            hintText: "Contoh: NIK tidak valid",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,),
            onPressed: () {
              if (_reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Alasan wajib diisi!"))
                );
                return;
              }
              Navigator.pop(context, _reasonController.text.trim());
            },
            child: const Text('Kirim & Tolak')
          ),
        ],
      ),
    );

    if (rejectReason == null) return; // User membatalkan dialog
  } else {
    // Jika verify, tampilkan konfirmasi biasa seperti kode lama Anda
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Verifikasi'),
        content: Text('Setujui pendaftaran vendor "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Verifikasi'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
  }

  // --- PROSES UPDATE KE DATABASE ---
  try {
    Map<String, dynamic> updateData = {'status': status};
    if (status == 'rejected') {
      updateData['reject_reason'] = rejectReason; // Simpan alasan ke kolom notes
    }

    await _supabase
        .from('profiles')
        .update(updateData)
        .eq('id', id);

    // Jika status rejected, panggil fungsi di AuthService untuk nonaktifkan profile
    if (status == 'rejected' || status == 'verified') {
       await AuthService.updateVendorStatus(id, status);
    }

    if (mounted) {
     setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vendor $name telah di-${status == 'verified' ? 'verifikasi' : 'tolak'}'),
          backgroundColor: status == 'verified' ? Colors.green : Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Vendor Enrollment', style: TextStyle(fontWeight: FontWeight.bold)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Stream memantau tabel profiles dengan filter status pending
        stream: _supabase
            .from('profiles')
            .stream(primaryKey: ['id'])
            .eq('role', 'vendor')
            .order('created_at', ascending: false),

      //       .from('profiles') // Stream ke tabel yang punya kolom 'status'
      // .stream(primaryKey: ['id'])
      // .eq('status', 'pending')
      // .order('nama_perusahaan', ascending: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada pendaftaran vendor baru.'));
          }

final vendors = snapshot.data!
              .where((data) => data['status'] == 'pending')
              .toList();

          // Jika setelah difilter hasilnya kosong, tampilkan pesan kosong
          if (vendors.isEmpty) {
            return const Center(child: Text('Semua pendaftaran telah diproses.'));
          }

          //final vendors = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendorProfile = vendors[index];
              final String vendorId = vendorProfile['id'];
final String currentStatus = vendorProfile['status'] ?? 'pending';
final String registCode = vendorProfile['regist_code'] ?? '';
              final String nameUser = vendorProfile['name'] ?? '-';
              final String nik = vendorProfile['nik'] ?? '-';
              final String email = vendorProfile['email'] ?? '-';
                return FutureBuilder<Map<String, dynamic>?>(
                  key: ValueKey(vendorId),
                future: _supabase
                    .from('master_vendor')
                    .select('vendor_name')
                    .eq('regist_code', registCode)
                    .maybeSingle(),
                builder: (context, masterSnapshot) {
                  if (masterSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(child: Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()));
                  }
                  final String vendorName = masterSnapshot.data?['vendor_name'] ?? 'Loading...';
      //           key: ValueKey(vendorId),
      //           future: _supabase
      //               // .from('profiles_vendor')
      //               // .select()
      //               // .eq('profile_id', vendorId)
      //               // .maybeSingle(),
      //               .from('profiles')
      //         .select()
      //         .eq('id', vendorId)
      //         .maybeSingle(),
      //           builder: (context, detailSnapshot) {
      //             final String namaPT = vendorProfile['nama_perusahaan'] ?? 'Nama Tidak Ada';
      // final String alamat = vendorProfile['alamat'] ?? '-';
      // final String phone = vendorProfile['phone'] ?? '-';

      // // 2. Ambil data dari tabel profiles (Future Snapshot)
      // final profile = detailSnapshot.data;
      // final String nik = profile?['nik'] ?? '-';
      // final String email = profile?['email'] ?? '-';

      // if (detailSnapshot.connectionState == ConnectionState.waiting) {
      //   return const Card(child: Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()));
      // }
    
                  // final detail = detailSnapshot.data;
                  // final String namaPT = detail?['nama_perusahaan'] ?? 
                  //                      (detailSnapshot.connectionState == ConnectionState.waiting ? 'Loading...' : 'Nama Tidak Ada');
                  
                  // UI Card
                  return Card(
                    key: ValueKey(vendorId),
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
                                child: Text(vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                              ),
                              // _buildStatusChip('pending'),
                              _buildStatusChip(currentStatus),
                            ],
                          ),
                          // const Divider(),
                          // _rowDetail(Icons.badge, "NIK", vendorProfile['nik'] ?? '-'),
                          // _rowDetail(Icons.email, "Email", vendorProfile['email'] ?? '-'),
                          // const SizedBox(height: 8),
                          // const Text("Detail Perusahaan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          // _rowDetail(Icons.location_on, "Alamat", vendorProfile['alamat'] ?? '-'),
                          // _rowDetail(Icons.phone, "No. Telp", vendorProfile['phone'] ?? '-'),
                          const Divider(),
              _rowDetail(Icons.badge, "Nama Pendaftar", nameUser), 
              _rowDetail(Icons.badge, "NIK", nik), // Pakai variabel nik hasil fetch
              _rowDetail(Icons.email, "Email", email),
              _rowDetail(Icons.vpn_key, "Regist Code", registCode), // Pakai variabel email hasil fetch
              //const SizedBox(height: 8),
              //const Text("Detail Perusahaan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              // _rowDetail(Icons.location_on, "Alamat", alamat),
              // _rowDetail(Icons.phone, "No. Telp", phone),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleAction(vendorId, vendorName, 'rejected'),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text("REJECT"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleAction(vendorId, vendorName, 'verified'),
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

  // Widget _buildStatusChip(String status) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: Colors.orange.withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(20),
  //       border: Border.all(color: Colors.orange, width: 1),
  //     ),
  //     child: const Text("PENDING", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
  //   );
  // }

  Widget _buildStatusChip(String status) {
  // Kita buat warna dinamis jika nanti Anda ingin menampilkan status lain
  Color statusColor = status.toLowerCase() == 'pending' ? Colors.orange : Colors.green;
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: statusColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: statusColor, width: 1),
    ),
    // Menampilkan status langsung dari kolom database (diubah ke uppercase)
    child: Text(
      status.toUpperCase(), 
      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
}