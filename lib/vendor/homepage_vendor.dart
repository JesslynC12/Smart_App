import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:project_app/vendor/booking_antrian.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_service.dart' as model;
import '../auth/auth_service.dart';
import '../login.dart';

class HomepageVendor extends StatefulWidget {
  const HomepageVendor({super.key});

  @override
  State<HomepageVendor> createState() => _HomepageVendorState();
}

class _HomepageVendorState extends State<HomepageVendor> {
  final supabase = Supabase.instance.client;
  model.User? currentUser;
  bool isLoading = true;
  bool _isOrderLoading = false;
  List<int> _vendorDetailIds = [];
Timer? _timer;

// tambahkan variabel subscription untuk mengontrol realtime stream
  StreamSubscription? _realtimeSubscription;
  // Variabel Statistik
  int totalRequests = 0;
  int ongoingCount = 0;
  int completedCount = 0;
  int rejectedCount = 0;

// Variabel List Order Baru (Pindahan dari VendorOrderListPage)
  List<Map<String, dynamic>> _newOrdersList = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Jalankan timer setiap detik untuk memperbarui countdown di UI
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

@override
  void dispose() {
    _timer?.cancel();
    // WAJIB: Batalkan subscription realtime agar tidak terjadi kebocoran memori (memory leak)
    _realtimeSubscription?.cancel();
    super.dispose();
  }
  // Memastikan User terisi sebelum mengambil statistik
  Future<void> _loadInitialData() async {
    await _loadUserData();
    final nik = currentUser?.nikVendor;
    if (nik != null) {
      _vendorDetailIds = await AuthService.getVendorDetailIds(nik);
      if (_vendorDetailIds.isNotEmpty) {
        await Future.wait([
          _fetchStatistics(),
          _fetchNewOrders(),
        ]);
      }
      // 2. Setup listener realtime setelah data user (NIK) tersedia
      _setupRealtime();
    }
  }
// Fungsi baru untuk setup Realtime menggunakan Supabase Stream
  void _setupRealtime() {
    if (_vendorDetailIds.isEmpty) return;

    // Batalkan subscription lama jika ada sebelum membuat yang baru
    _realtimeSubscription?.cancel();

    // Memantau tabel shipping_assignments secara realtime
    _realtimeSubscription = supabase
        .from('shipping_assignments')
        .stream(primaryKey: ['id_assignment'])
        .inFilter('id_vendor_details', _vendorDetailIds) // Filter agar hanya memantau data milik vendor ini saja
        .listen((_) {
          debugPrint("Realtime Update Terdeteksi di shipping_assignments!");
          // Jalankan fetch data ulang setiap kali ada perubahan data (INSERT/UPDATE/DELETE) di database
          _fetchStatistics();
          _fetchNewOrders();
        });
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          currentUser = user;
        });
      }
    } catch (e) {
      debugPrint("Error loading user: $e");
    }
  }

  // List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
  //   Map<int, Map<String, dynamic>> groupedMap = {};
  //   List<Map<String, dynamic>> finalResult = [];
  //   for (var req in source) {
  //     final dynamic rawGroupId = req['group_id'];
  //     if (rawGroupId == null) {
  //       Map<String, dynamic> singleItem = Map<String, dynamic>.from(req);
  //       if (singleItem['delivery_order'] != null) {
  //         for (var doItem in singleItem['delivery_order']) {
  //           doItem['parent_so'] = singleItem['so']?.toString() ?? "-";
  //         }
  //       }
  //       finalResult.add(singleItem);
  //     } else {
  //       int gId = rawGroupId is String ? int.parse(rawGroupId) : rawGroupId as int;
  //       if (!groupedMap.containsKey(gId)) {
  //         groupedMap[gId] = Map<String, dynamic>.from(req);
  //         groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
  //         if (groupedMap[gId]!['delivery_order'] != null) {
  //           for (var doItem in groupedMap[gId]!['delivery_order']) {
  //             doItem['parent_so'] = req['so']?.toString(); 
  //           }
  //         }
  //       } else {
  //         groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
  //         List newDos = List.from(req['delivery_order'] ?? []);
  //         for (var ndo in newDos) { ndo['parent_so'] = req['so']?.toString(); }
  //         List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
  //         currentDos.addAll(newDos);
  //         groupedMap[gId]!['delivery_order'] = currentDos;
  //       }
  //     }
  //   }
  //   finalResult.addAll(groupedMap.values);
  //   finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
  //   return finalResult;
  // }
//   List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
//   Map<int, Map<String, dynamic>> groupedMap = {};
//   List<Map<String, dynamic>> finalResult = [];

//   for (var req in source) {
//     // Suntik RDD origin ke tiap DO
//     if (req['delivery_order'] != null) {
//       for (var doItem in req['delivery_order']) {
//         doItem['rdd_origin'] = req['rdd'];
//       }
//     }

//     final dynamic rawGroupId = req['group_id'];

//     if (rawGroupId == null) {
//       Map<String, dynamic> singleItem = Map<String, dynamic>.from(req);
//       // Simpan ID assignment tunggal dalam list agar seragam dengan grup
//       singleItem['grouped_assignment_ids'] = [req['id_assignment']];
      
//       if (singleItem['delivery_order'] != null) {
//         for (var doItem in singleItem['delivery_order']) {
//           doItem['parent_so'] = singleItem['so']?.toString() ?? "-";
//         }
//       }
//       finalResult.add(singleItem);
//     } else {
//       int gId = rawGroupId is String ? int.parse(rawGroupId) : rawGroupId as int;
      
//       if (!groupedMap.containsKey(gId)) {
//         groupedMap[gId] = Map<String, dynamic>.from(req);
//         groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
//         groupedMap[gId]!['grouped_assignment_ids'] = [req['id_assignment']]; // Mulai kumpulkan ID assignment
        
//         if (groupedMap[gId]!['delivery_order'] != null) {
//           for (var doItem in groupedMap[gId]!['delivery_order']) {
//             doItem['parent_so'] = req['so']?.toString(); 
//           }
//         }
//       } else {
//         groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
//         groupedMap[gId]!['grouped_assignment_ids'].add(req['id_assignment']); // Tambah ID assignment anggota grup lain
        
//         List newDos = List.from(req['delivery_order'] ?? []);
//         for (var ndo in newDos) { 
//           ndo['parent_so'] = req['so']?.toString(); 
//         }
//         List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
//         currentDos.addAll(newDos);
//         groupedMap[gId]!['delivery_order'] = currentDos;
//       }
//     }
//   }
//   finalResult.addAll(groupedMap.values);
//   finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
//   return finalResult;
// }
List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
  Map<int, Map<String, dynamic>> groupedMap = {};
  List<Map<String, dynamic>> finalResult = [];

  for (var req in source) {
    // 1. Inisialisasi rdd_origin untuk data mentah
    if (req['delivery_order'] != null) {
      for (var doItem in req['delivery_order']) {
        doItem['rdd_origin'] = req['rdd'];
      }
    }

    final dynamic rawGroupId = req['group_id'];

    if (rawGroupId == null) {
      // --- PENANGANAN SINGLE SHIPMENT ---
      Map<String, dynamic> singleItem = Map<String, dynamic>.from(req);
      singleItem['grouped_assignment_ids'] = [req['id_assignment']];
      
      if (singleItem['delivery_order'] != null) {
        for (var doItem in singleItem['delivery_order']) {
          doItem['parent_so'] = singleItem['so']?.toString() ?? "-";
        }
      }
      finalResult.add(singleItem);
    } else {
      // --- PENANGANAN GROUP SHIPMENT ---
      int gId = rawGroupId is String ? int.parse(rawGroupId) : rawGroupId as int;
      
      if (!groupedMap.containsKey(gId)) {
        // Data pertama dalam grup
        Map<String, dynamic> firstInGroup = Map<String, dynamic>.from(req);
        firstInGroup['grouped_ids'] = [req['shipping_id']];
        firstInGroup['grouped_assignment_ids'] = [req['id_assignment']];
        
        if (firstInGroup['delivery_order'] != null) {
          for (var doItem in firstInGroup['delivery_order']) {
            doItem['parent_so'] = req['so']?.toString(); 
          }
        }
        groupedMap[gId] = firstInGroup;
      } else {
        // Data pendamping dalam grup (Proses Merge)
        if (!groupedMap[gId]!['grouped_ids'].contains(req['shipping_id'])) {
          groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
        }
        if (!groupedMap[gId]!['grouped_assignment_ids'].contains(req['id_assignment'])) {
          groupedMap[gId]!['grouped_assignment_ids'].add(req['id_assignment']);
        }
        
        List existingDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
        List newDos = List.from(req['delivery_order'] ?? []);

        for (var ndo in newDos) {
          // FIX: Cek apakah do_number sudah ada sebelum ditambah (mencegah duplikat tampilan)
          bool isDuplicate = existingDos.any((existing) => 
            existing['do_number'] == ndo['do_number']
          );

          if (!isDuplicate) {
            ndo['parent_so'] = req['so']?.toString();
            ndo['rdd_origin'] = req['rdd']; // Pastikan RDD asli terbawa
            existingDos.add(ndo);
          }
        }
        groupedMap[gId]!['delivery_order'] = existingDos;
      }
    }
  }
  
  finalResult.addAll(groupedMap.values);
  
  // Urutkan berdasarkan ID terbaru agar pesanan baru di atas
  finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
  return finalResult;
}
Future<void> _updateAssignment(List<int> assignmentIds, String status, List<int> shipIds, String reason) async {
  try {
    setState(() => isLoading = true);

    // 1. Update tabel shipping_assignments (Massal menggunakan .inFilter)
    await supabase.from('shipping_assignments').update({
      'status_assignment': status,
      'reason_rejected': status == 'rejected' ? reason : null,
      'responded_at': DateTime.now().toIso8601String(),
    }).inFilter('id_assignment', assignmentIds);

    // 2. Tentukan status untuk shipping_request
    String finalStatusRequest = status == 'accepted' ? 'on process' : 'waiting assign vendor delivery';

    // 3. Update tabel shipping_request (Massal menggunakan .inFilter)
    await supabase.from('shipping_request').update({
      'status': finalStatusRequest
    }).inFilter('shipping_id', shipIds);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Berhasil $status order"), 
          backgroundColor: status == 'accepted' ? Colors.green : Colors.orange
        )
      );
      _loadInitialData(); // Refresh data statistik dan list
    }
  } catch (e) {
    if (mounted) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal update: $e"), backgroundColor: Colors.red)
      );
    }
  }
}
// // --- FETCH ORDER BARU (Pindahan & Modifikasi) ---
//   Future<void> _fetchNewOrders() async {
//     try {
//       final nik = currentUser?.nikVendor;
//       if (nik == null) return;

//       setState(() => _isOrderLoading = true);

//       final response = await supabase.from('shipping_assignments').select('''
//             *,
//             request:shipping_id (
//               *,
//               warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
//               delivery_order(
//                 do_number,
//                 customer(customer_id, customer_name),
//                 do_details(qty, material:material_id (material_id, material_name))
//               )
//             )
//           ''')
//           .eq('nik', nik)
//           .eq('status_assignment', 'offered')
//           .order('assigned_at', ascending: false);

//       if (mounted) {
//         final List<Map<String, dynamic>> flattenedData = (response as List).map((e) {
//           final Map<String, dynamic> req = Map<String, dynamic>.from(e['request']);
//           req['id_assignment'] = e['id_assignment'];
//           req['assigned_at'] = e['assigned_at'];
//           req['jam_booking'] = e['jam_booking'];
//           return req;
//         }).toList();

//         setState(() {
//           _newOrdersList = _getGroupedDisplayData(flattenedData);
//           _isOrderLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() => _isOrderLoading = false);
//     }
//   }
Future<void> _fetchNewOrders() async {
  try {
    if (_vendorDetailIds.isEmpty) return;

    setState(() => _isOrderLoading = true);

    // Ambil data assignment
    final response = await supabase.from('shipping_assignments').select('''
          *,
           vendor_transportasi:id_vendor_details (
        qcf,
        city,
        area,
        type_unit
      ),
          request:shipping_id (
            *,
            warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order(
              do_number,
              customer(customer_id, customer_name),
              do_details(qty, material:material_id (material_id, material_name))
            )
          )
        ''')
        .inFilter('id_vendor_details', _vendorDetailIds)
        .eq('status_assignment', 'offered')
        .order('assigned_at', ascending: false);

    if (mounted) {
      List<Map<String, dynamic>> rawList = [];
      for (var e in (response as List)) {
        if (e['request'] == null) continue;
        final Map<String, dynamic> req = Map<String, dynamic>.from(e['request']);
        // Simpan assignment_id asli ke dalam request untuk tracking
        req['id_assignment'] = e['id_assignment'];
        req['assigned_at'] = e['assigned_at'];
        req['vendor_transportasi'] = e['vendor_transportasi'];
        rawList.add(req);
      }

      setState(() {
        // Gunakan fungsi grouping yang sudah diperbaiki di bawah
        _newOrdersList = _getGroupedDisplayData(rawList);
        _isOrderLoading = false;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _isOrderLoading = false);
  }
}

  Future<void> _fetchStatistics() async {
    try {
      if (_vendorDetailIds.isEmpty) return;
      
// 1. Dapatkan range waktu bulan sekarang (Awal bulan s/d Akhir bulan)
    DateTime now = DateTime.now();
    // Tanggal 1 di bulan sekarang, jam 00:00:00
    DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
    // Tanggal 1 di bulan depan, jam 00:00:00 (sebagai batas akhir)
    DateTime firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);
      // Mengambil data status dalam satu kali panggil (Lebih Efisien)
      final List<dynamic> data = await supabase
          .from('shipping_assignments')
          // .select('status_assignment')
          .select('''
          status_assignment,
          request:shipping_id (group_id)
        ''')
          .inFilter('id_vendor_details', _vendorDetailIds)
          // Filter: assigned_at >= awal bulan AND assigned_at < awal bulan depan
        .gte('assigned_at', firstDayOfMonth.toIso8601String())
        .lt('assigned_at', firstDayOfNextMonth.toIso8601String());

if (mounted) {
      // Fungsi bantuan untuk menghitung penugasan unik (Group dihitung 1)
      int countUniqueAssignments(List<dynamic> list) {
        Set<String> uniqueKeys = {};
        int singleShipmentCount = 0;

        for (var item in list) {
          final request = item['request'];
          final int? groupId = request != null ? request['group_id'] : null;

          if (groupId != null) {
            // Jika ada Group ID, masukkan ke Set (Set otomatis menghapus duplikat)
            uniqueKeys.add("group_$groupId");
          } else {
            // Jika Single Shipment, hitung manual per baris
            singleShipmentCount++;
          }
        }
        // Total = Jumlah Group unik + Jumlah Single Shipment
        return uniqueKeys.length + singleShipmentCount;
      }

      //if (mounted) {
        setState(() {
          // 1. Total Request (Semua status)
        totalRequests = countUniqueAssignments(data);
          // 2. On Going (Hanya yang status accepted)
        // 2. On Going (PERBAIKAN: Sertakan status proses operasional)
        final ongoingList = data.where((item) {
          final status = item['status_assignment']?.toString().toLowerCase();
          return status == 'accepted' || 
                 status == 'check in' || 
                 status == 'kelayakan unit' || 
                 status == 'loading' || 
                 status == 'weighbridge' || 
                 status == 'keluar';
        }).toList();
        ongoingCount = countUniqueAssignments(ongoingList);

        // 3. Completed (Hanya yang status completed)
        final completedList = data.where((item) => item['status_assignment'] == 'completed').toList();
        completedCount = countUniqueAssignments(completedList);

        // // 4. Rejected (Hanya yang status rejected)
        // final rejectedList = data.where((item) => item['status_assignment'] == 'rejected').toList();
        // rejectedCount = countUniqueAssignments(rejectedList);
        final failedList = data.where((item) {
          final status = item['status_assignment']?.toString().toLowerCase();
          // Menggunakan operator OR (||) untuk mengumpulkan semua status yang gagal/batal
          return status == 'rejected' || 
                 status == 'no response' || 
                 status == 'cancel booking';
        }).toList();
        
        rejectedCount = countUniqueAssignments(failedList);

        isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Stats: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda ingin keluar dari Portal Vendor?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
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

  // @override
  // Widget build(BuildContext context) {
  //   final primaryColor = Colors.red.shade700;
  //   final bool isApproved = currentUser?.status == 'verified';

  //   return Scaffold(
  //     backgroundColor: Colors.grey.shade50,
  //     body: isLoading
  //         ? Center(child: CircularProgressIndicator(color: primaryColor))
  //         : RefreshIndicator(
  //             onRefresh: _loadInitialData,
  //             color: primaryColor,
  //             child: SingleChildScrollView(
  //               physics: const AlwaysScrollableScrollPhysics(),
  //               child: Column(
  //                 children: [
  //                   _buildHeaderSection(primaryColor),
  //                   Padding(
  //                     padding: const EdgeInsets.all(20.0),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         //_buildStatusBanner(isApproved),
  //                         //const SizedBox(height: 25),
  //                         // const Text(
  //                         //   "Aktivitas Pengiriman",
  //                         //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //                         // ),
  //                         Text(
  //       "Aktivitas Pengiriman (${DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())})",
  //       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //     ),
  //                         const SizedBox(height: 15),
  //                         _buildStatisticGrid(),
  //                       const SizedBox(height: 30),
                          
  //                         // --- BAGIAN ORDER BARU ---
  //                         Row(
  //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                           children: [
  //                             const Text("Pesanan Baru Tersedia", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //                             if (_isOrderLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
  //                           ],
  //                         ),
  //                         const SizedBox(height: 15),
                          
  //                         if (_newOrdersList.isEmpty && !_isOrderLoading)
  //                           _buildEmptyState()
  //                         else
  //                           ListView.builder(
  //                             shrinkWrap: true,
  //                             physics: const NeverScrollableScrollPhysics(),
  //                             itemCount: _newOrdersList.length,
  //                             itemBuilder: (context, index) => _buildOrderCard(_newOrdersList[index]),
  //                           ),
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

  return Scaffold(
    backgroundColor: Colors.grey.shade50,
    body: isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : RefreshIndicator(
           onRefresh: () async {
                await _fetchStatistics();
                await _fetchNewOrders();
              },
              color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeaderSection(primaryColor),
                  // Batasi lebar maksimal konten agar bagus di Laptop
                  // Center(
                  //   child: Container(
                  //     constraints: const BoxConstraints(maxWidth: 1000), // Maksimal lebar 1000px
                  Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Aktivitas Pengiriman (${DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())})",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          
                          // Widget Statistik Responsif
                          _buildStatisticGrid(),
                          
                          const SizedBox(height: 35),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Pesanan Baru Tersedia", 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              if (_isOrderLoading) 
                                const SizedBox(width: 20, height: 20, 
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          if (_newOrdersList.isEmpty && !_isOrderLoading)
                            _buildEmptyState()
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _newOrdersList.length,
                              itemBuilder: (context, index) => _buildOrderCard(_newOrdersList[index]),
                            ),
                        ],
                      ),
                    ),
                
                ],
              ),
            ),
          ),
  );
}
  // --- UI KARTU PESANAN (Pindahan VendorOrderListPage) ---
  // Widget _buildOrderCard(Map<String, dynamic> item) {
  //   final bool isGroup = item['group_id'] != null;
  //   final List dos = item['delivery_order'] ?? [];
  //   final wh = item['warehouse'];
  //   final String warehouseDisplay = wh != null ? "${wh['lokasi']} - ${wh['warehouse_name']}" : "-";

  //   return Card(
  //     elevation: 3,
  //     margin: const EdgeInsets.only(bottom: 16),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Column(
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //           decoration: BoxDecoration(
  //             color: isGroup ? Colors.blue.shade700 : Colors.red.shade700,
  //             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(isGroup ? Icons.layers : Icons.local_shipping, size: 18, color: Colors.white),
  //               const SizedBox(width: 8),
  //               Text(isGroup ? "GROUP ID: ${item['group_id']}" : "SHIP ID: ${item['shipping_id']}",
  //                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
  //               const Spacer(),
  //               Text(warehouseDisplay.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  //             ],
  //           ),
  //         ),
  //         Padding(
  //           padding: const EdgeInsets.all(12),
  //           child: Column(
  //             children: [
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   _infoLabel("📅 RDD", _formatDate(item['rdd'])),
  //                   _infoLabel("🚛 Stuffing", _formatDate(item['stuffing_date'])),
  //                   _infoLabel("🛠️ Status", item['is_dedicated'] == true ? "DEDICATED" : "REGULAR"),
  //                 ],
  //               ),
  //               const Divider(height: 25),
  //               ...dos.map((doItem) => _buildDoMiniCard(doItem, item['so'])),
  //               const SizedBox(height: 10),
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: OutlinedButton(
  //                       onPressed: () => _showRejectDialog(item),
  //                       style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
  //                       child: const Text("REJECT", style: TextStyle(fontSize: 12)),
  //                     ),
  //                   ),
  //                   const SizedBox(width: 12),
  //                   Expanded(
  //                     child: ElevatedButton(
  //                       onPressed: () => _openBookingTab(item),
  //                       style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
  //                       child: const Text("ACCEPT & PILIH JAM", style: TextStyle(color: Colors.white, fontSize: 11)),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

//   Widget _buildOrderCard(Map<String, dynamic> item) {
//     final bool isGroup = item['group_id'] != null;
//     final List dos = item['delivery_order'] ?? [];
    
//     // Ambil info warehouse dari objek join
//     final wh = item['warehouse'];
//     final String warehouseDisplay = wh != null 
//         ? "${wh['lokasi'] ?? ''} - ${wh['warehouse_name'] ?? ''}" 
//         : "-";
// final bool expired = _isExpired(item['assigned_at']);
//     return Card(
//       elevation: 3,
//       margin: const EdgeInsets.only(bottom: 16),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             decoration: BoxDecoration(
//               color: isGroup ? Colors.blue.shade50 : Colors.red.shade50,
//               borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
//             ),
//             child: Row(
//               children: [
//                 Icon(isGroup ? Icons.layers : Icons.local_shipping, size: 18, color: Colors.red.shade700),
//                 const SizedBox(width: 8),
//                 Text(
//                   isGroup ? "GROUP ID: ${item['group_id']}" : "SHIP ID: ${item['shipping_id']}",
//                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
//                 ),
//                 const Spacer(),
//                 // Badge Warehouse sesuai style VendorOrderListPage
//                 _buildBadge(warehouseDisplay.toUpperCase(), Colors.red.shade700),
//               ],
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               children: [
//                 // Di dalam Column pada _buildOrderCard
// Row(
//   children: [
//     Icon(Icons.timer_outlined, size: 14, color: Colors.orange.shade900),
//     const SizedBox(width: 4),
//     Text(
//       "Batas Respon: ",
//       style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
//     ),
//     Text(
//       _getRemainingTime(item['assigned_at']), // Mengambil jam assign dari database
//       style: TextStyle(
//         fontSize: 11, 
//         fontWeight: FontWeight.bold, 
//         color: Colors.red.shade900
//       ),
//     ),
//   ],
// ),
// const SizedBox(height: 10),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     _infoText("📅 RDD:", _formatDate(item['rdd'])),
//                     // STATUS: Mengambil nilai string langsung dari is_dedicated (Dedicated/Regular)
//                     _infoText("🛠️ Status:", (item['is_dedicated'] ?? "-").toString().toUpperCase()),
//                     _infoText("🚛 Stuffing:", _formatDate(item['stuffing_date'])),
//                   ],
//                 ),
//                 const Divider(height: 25),
                
//                 // Me-render list DO dengan info Customer ID & Name
//                 ...dos.map((doItem) => _buildDoMiniCard(doItem, item['so'])),
                
//                 const SizedBox(height: 12),
//                 // Row(
//                 //   children: [
//                 //     Expanded(
//                 //       child: OutlinedButton(
//                 //         onPressed: () => _showRejectDialog(item),
//                 //         style: OutlinedButton.styleFrom(
//                 //           side: const BorderSide(color: Colors.red), 
//                 //           foregroundColor: Colors.red,
//                 //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 //         ),
//                 //         child: const Text("REJECT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
//                 //       ),
//                 //     ),
//                 //     const SizedBox(width: 12),
//                 //     Expanded(
//                 //       child: ElevatedButton(
//                 //         onPressed: () => _openBookingTab(item),
//                 //         style: ElevatedButton.styleFrom(
//                 //           backgroundColor: Colors.green,
//                 //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 //         ),
//                 //         child: const Text("ACCEPT & PILIH JAM", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
//                 //      ),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: expired ? null : () => _showRejectDialog(item),
//                         style: OutlinedButton.styleFrom(side: BorderSide(color: expired ? Colors.grey : Colors.red), foregroundColor: Colors.red),
//                         child: const Text("REJECT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: expired ? null : () => _openBookingTab(item),
//                         style: ElevatedButton.styleFrom(backgroundColor: expired ? Colors.grey : Colors.green),
//                         child: Text(expired ? "EXPIRED" : "ACCEPT & PILIH JAM", 
//                             style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

Widget _buildOrderCard(Map<String, dynamic> item) {
    final bool isGroup = item['group_id'] != null;
    final List dos = item['delivery_order'] ?? [];
    
    // Ambil info warehouse dari objek join
    final wh = item['warehouse'];
    final String warehouseDisplay = wh != null 
        ? "${wh['lokasi'] ?? ''} - ${wh['warehouse_name'] ?? ''}" 
        : "-";

    final bool expired = _isExpired(item['assigned_at']);
final vt = item['vendor_transportasi'];
  
  final String city = vt != null ? (vt['city'] ?? '-') : '-';
  final String area = vt != null ? (vt['area'] ?? '-') : '-';
  final String typeUnit = vt != null ? (vt['type_unit'] ?? '-') : '-';
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER: Penanda Group / Single Ship
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isGroup ? Colors.blue.shade50 : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(isGroup ? Icons.layers : Icons.local_shipping, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  isGroup ? "GROUP ID: ${item['group_id']}" : "SHIP ID: ${item['shipping_id']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Spacer(),
                // Sesuai style: Jam Booking dipindahkan ke header jika di OnProcess, 
                // Namun di Homepage kita tampilkan label identitas di sini.
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIMER: Batas Respon
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: expired ? Colors.grey : Colors.orange.shade900),
                    const SizedBox(width: 4),
                    Text(
                      "Batas Respon: ",
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                    ),
                    Text(
                      _getRemainingTime(item),
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold, 
                        color: expired ? Colors.grey : Colors.red.shade900
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // BARIS INFO: RDD, STUFFING, STATUS, WAREHOUSE (SERAGAM DENGAN ONPROCESS)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                   // _infoBox("RDD", _formatDate(item['rdd'])),
                    _infoBox("STUFFING", _formatDate(item['stuffing_date'])),
                     _infoBox("TIPE UNIT",  typeUnit.toUpperCase()),
                     _infoBox("RUTE PENGIRIMAN", "$city → $area"),
                    _infoBox("STATUS", (item['is_dedicated'] ?? "-").toString().toUpperCase()),
                    _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase(), color: Colors.red.shade700),
                  ],
                ),
                // // --- LETAKKAN DI SINI ---
                // if (item['vendor_transportasi'] != null)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
                //     child: Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         const Text(
                //           "DETAIL ALOKASI WILAYAH & UNIT", 
                //           style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
                //         ),
                //         const SizedBox(height: 6),
                //         Wrap(
                //           spacing: 8,
                //           runSpacing: 4,
                //           children: [
                //             _miniVendorDetail("City: ${item['vendor_transportasi']['city'] ?? '-'}"),
                //             _miniVendorDetail("Area: ${item['vendor_transportasi']['area'] ?? '-'}"),
                //             _miniVendorDetail("Unit: ${item['vendor_transportasi']['type_unit'] ?? '-'}"),
                //           ],
                //         ),
                //       ],
                //     ),
                //   ),
            
             
                 const Divider(height: 25),
        
                // --- LETAKKAN DI SINI ---
                const Text(
                  "RINCIAN MUATAN", 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
                ),
                const SizedBox(height: 10),
                
                // RINCIAN MUATAN (DO)
                ...dos.map((doItem) => _buildDoMiniCard(doItem, item['so'])),
                
                const SizedBox(height: 12),
                
                // TOMBOL AKSI
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: expired ? null : () => _showRejectDialog(item),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: expired ? Colors.grey : Colors.red), 
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("REJECT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: expired ? null : () => _openBookingTab(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: expired ? Colors.grey : Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          expired ? "EXPIRED" : "ACCEPT & PILIH JAM", 
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
// Fungsi helper untuk teks detail vendor yang kecil di bawah nama
Widget _miniVendorDetail(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.grey.shade300, width: 0.5),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: Colors.blueGrey.shade700,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
void _showRejectDialog(Map<String, dynamic> item) {
  final List<String> rejectReasons = [
    "Tidak Ada Supir",
    "Tidak Ada Unit",
    "Unit Rusak",
    "Jalan Macet",
    "Dokumen Expired",
    "Other"
  ];

  String? selectedReason;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Pilih Alasan Penolakan", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: rejectReasons.map((reason) => RadioListTile<String>(
              title: Text(reason, style: const TextStyle(fontSize: 13)),
              value: reason,
              groupValue: selectedReason,
              activeColor: Colors.red,
              onChanged: (val) {
                setDialogState(() => selectedReason = val);
              },
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("BATAL")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: selectedReason == null 
                ? null 
                : () {
                    Navigator.pop(context);
                    
                    // --- PERBAIKAN DI SINI: Panggil Nama Fungsinya ---
                    _updateAssignment(
                      List<int>.from(item['grouped_assignment_ids'] ?? [item['id_assignment']]), 
                      'rejected', 
                      item['group_id'] != null 
                          ? List<int>.from(item['grouped_ids']) 
                          : [item['shipping_id']], 
                      selectedReason!
                    );
                  },
              child: const Text("REJECT ORDER", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

  // Tambahkan widget _infoBox agar seragam (jika belum ada di HomepageVendor)
  Widget _infoBox(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          value, 
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: color ?? Colors.black87
          )
        ),
      ],
    );
  }

// bool _isExpired(String assignedAtStr) {
//   if (assignedAtStr == null) return true;
//     DateTime assignedAt = DateTime.parse(assignedAtStr).toLocal();
//     return DateTime.now().difference(assignedAt).inHours >= 2;
// }
bool _isExpired(String? assignedAtStr) {
  if (assignedAtStr == null) return true;
  
  try {
    DateTime assignedAt = DateTime.parse(assignedAtStr).toUtc();
    DateTime deadline = assignedAt.add(const Duration(hours: 2));
    DateTime nowUtc = DateTime.now().toUtc();
    
    return nowUtc.isAfter(deadline);
  } catch (e) {
    return true;
  }
}

Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color, width: 0.5),
      ), 
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  // String _getRemainingTime(String assignedAtStr) {
  //   if (assignedAtStr == null) return "00:00:00";
  // DateTime assignedAt = DateTime.parse(assignedAtStr).toLocal();
  // DateTime deadline = assignedAt.add(const Duration(hours: 2));
  // Duration remaining = deadline.difference(DateTime.now());

  // if (remaining.isNegative) {
  //   return "Expired";
  // }

  // String twoDigits(int n) => n.toString().padLeft(2, "0");
  // // String minutes = twoDigits(remaining.inMinutes.remainder(60));
  // // String seconds = twoDigits(remaining.inSeconds.remainder(60));
  
  // return "${twoDigits(remaining.inHours)}:${twoDigits(remaining.inMinutes.remainder(60))}:${twoDigits(remaining.inSeconds.remainder(60))}";
  // }
//   String _getRemainingTime(String? assignedAtStr) {
//   if (assignedAtStr == null) return "00:00:00";

//   // 1. Parse string waktu dari database
//   // 2. Gunakan .toLocal() untuk mengubah UTC menjadi waktu lokal HP (WIB)
//   DateTime assignedAt = DateTime.parse(assignedAtStr).toLocal();
  
//   // 3. Tambahkan durasi deadline 2 jam
//   DateTime deadline = assignedAt.add(const Duration(hours: 2));
  
//   // 4. Hitung selisih dengan waktu saat ini (yang sudah lokal juga)
//   Duration remaining = deadline.difference(DateTime.now());

//   if (remaining.isNegative) return "Expired";

//   // 5. Format tampilan jam, menit, detik
//   String twoDigits(int n) => n.toString().padLeft(2, "0");
//   String hours = twoDigits(remaining.inHours);
//   String minutes = twoDigits(remaining.inMinutes.remainder(60));
//   String seconds = twoDigits(remaining.inSeconds.remainder(60));
  
//   return "$hours:$minutes:$seconds";
// }
String _getRemainingTime(Map<String, dynamic> item) {
  String? assignedAtStr = item['assigned_at'];
  if (assignedAtStr == null) return "00:00:00";

  try {
    // 1. Ambil teks tanggal dan jam saja, abaikan "+00" di ujungnya
    // Contoh: "2026-05-03 23:26:20"
    String cleanDateTime = assignedAtStr.split('+')[0]; 
    
    // 2. Parse sebagai waktu lokal (mengabaikan zona waktu database)
    DateTime assignedAt = DateTime.parse(cleanDateTime);
    
    // 3. Tambahkan batas 2 jam
    DateTime deadline = assignedAt.add(const Duration(hours: 2));
    
    // 4. Hitung selisih dengan waktu sekarang
    Duration remaining = deadline.difference(DateTime.now());

   if (remaining.isNegative) {
      // Jika status masih 'offered' dan waktu habis, picu auto reject
      // Kita cek status di memori agar tidak spam hit database
      _handleAutoReject(item);
      return "Expired";
    }

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(remaining.inHours);
    String minutes = twoDigits(remaining.inMinutes.remainder(60));
    String seconds = twoDigits(remaining.inSeconds.remainder(60));
    
    return "$hours:$minutes:$seconds";
  } catch (e) {
    return "00:00:00";
  }
}

// Gunakan set untuk melacak id yang sedang diproses agar tidak duplikat request
final Set<int> _processingIds = {};

Future<void> _handleAutoReject(Map<String, dynamic> item) async {
  final int assignmentId = item['id_assignment'];
  final int shipId = item['shipping_id'];

  // Cegah eksekusi berulang untuk ID yang sama
  if (_processingIds.contains(assignmentId)) return;
  _processingIds.add(assignmentId);

  try {
    debugPrint("Otomatis mereject assignment $assignmentId karena timeout");
    
    // Update assignment dengan reason khusus
    await supabase.from('shipping_assignments').update({
      'status_assignment': 'no response',
      'reason_rejected': 'cancel by sistem', // Sesuai permintaan Anda
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('id_assignment', assignmentId);

    // Kembalikan status shipping_request ke waiting assign vendor
    String finalStatusRequest = 'waiting assign vendor delivery';
    
    if (item['group_id'] != null) {
      List<int> allIds = List<int>.from(item['grouped_ids']);
      await supabase.from('shipping_request').update({'status': finalStatusRequest}).inFilter('shipping_id', allIds);
    } else {
      await supabase.from('shipping_request').update({'status': finalStatusRequest}).eq('shipping_id', shipId);
    }

    // Refresh data UI
    _loadInitialData();
  } catch (e) {
    debugPrint("Gagal auto reject: $e");
  } finally {
    // Beri jeda sedikit sebelum menghapus dari tracker untuk stabilitas
    Future.delayed(const Duration(seconds: 5), () => _processingIds.remove(assignmentId));
  }
}

Widget _infoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: Colors.black87), 
        children: [
          TextSpan(text: "$label "), 
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  // Widget _buildDoMiniCard(Map<String, dynamic> doItem, dynamic parentSo) {
  //   // Ambil data customer
  //   final customer = doItem['customer'] ?? {};
  //   final String customerDisplay = "${customer['customer_id'] ?? ''} - ${customer['customer_name'] ?? ''}";

  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 10),
  //     decoration: BoxDecoration(
  //       color: Colors.white, 
  //       borderRadius: BorderRadius.circular(8), 
  //       border: Border.all(color: Colors.grey.shade200),
  //     ),
  //     child: Column(
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(8),
  //           decoration: BoxDecoration(
  //             color: Colors.pink.shade50, 
  //             borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue)),
  //               Text("SO: ${doItem['parent_so'] ?? parentSo ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
  //               // Menampilkan No Customer & Nama Customer
  //               Flexible(
  //                 child: Text(
  //                   customerDisplay, 
  //                   style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), 
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         Table(
  //           columnWidths: const { 0: FlexColumnWidth(1.5), 1: FlexColumnWidth(4), 2: FlexColumnWidth(1) },
  //           children: (doItem['do_details'] as List).map((det) {
  //             final mat = det['material'] ?? {};
  //             return TableRow(
  //               children: [
  //                 _tablePadding(mat['material_id']?.toString() ?? "-"),
  //                 _tablePadding(mat['material_name'] ?? "-"),
  //                 _tablePadding(det['qty']?.toString() ?? "0", isBold: true, align: TextAlign.right),
  //               ],
  //             );
  //           }).toList(),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  
Widget _buildDoMiniCard(Map<String, dynamic> doItem, dynamic parentSo) {
  // Ambil data customer dan RDD yang sudah disuntikkan tadi
  final customer = doItem['customer'] ?? {};
  final String customerDisplay = "${customer['customer_id'] ?? ''} - ${customer['customer_name'] ?? ''}";
  final List details = doItem['do_details'] ?? [];
  final String rddSpesifik = _formatDate(doItem['rdd_origin']);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- 1. Teks RDD (Muncul di atas header kotak DO) ---
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 14, color: Colors.red.shade700),
            const SizedBox(width: 6),
            Text(
              "RDD: $rddSpesifik",
              style: const TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFFB71C1C)
              ),
            ),
          ],
        ),
      ),

      // --- 2. Kontainer Box (DO, SO, Customer, & Tabel) ---
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Header: DO & SO (Style Pink Muda)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFCE4EC), // Pink Muda konsisten
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "DO: ${doItem['do_number']}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue),
                  ),
                  Text(
                    "SO: ${doItem['parent_so'] ?? parentSo ?? '-'}",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // Detail Customer & Tabel Material
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customerDisplay.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, thickness: 0.5),
                  ...details.map((det) {
                    final mat = det['material'] ?? {};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${mat['material_id'] ?? '-'} - ${mat['material_name'] ?? '-'}",
                              style: const TextStyle(fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${det['qty']}",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// --- NAVIGATION ---
  void _openBookingTab(Map<String, dynamic> item) {
    final groupId = item['group_id'];
    final shipId = item['shipping_id'];
    String tabTitle = groupId != null ? "Booking Grup #$groupId" : "Booking Ship #$shipId";

    DynamicTabPage.of(context)?.openTab(
      tabTitle, 
      ScheduleSelectionPage(
        assignmentId: item['id_assignment'],
        shippingId: shipId,
        oldTime: item['jam_booking'],
        vendorNik: currentUser!.nikVendor!,
        onSuccess: () => _loadInitialData(),
      ),
    );
  }

  // --- DIALOGS & HELPERS ---
  // void _showRejectDialog(Map<String, dynamic> item) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text("Konfirmasi Reject"),
  //       content: const Text("Anda yakin ingin menolak order ini? Order akan dikembalikan ke Admin."),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
  //         ElevatedButton(
  //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _updateAssignment(item['id_assignment'], 'rejected', item['shipping_id']);
  //           },
  //           child: const Text("YA, REJECT", style: TextStyle(color: Colors.white)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _infoLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _tablePadding(String text, {bool isBold = false, TextAlign align = TextAlign.left}) {
    return Padding(padding: const EdgeInsets.all(6), child: Text(text, textAlign: align, style: TextStyle(fontSize: 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
  }

  // Widget _buildDoMiniCard(Map<String, dynamic> doItem, dynamic parentSo) {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 8),
  //     decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
  //     child: Column(
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue)),
  //               Text("SO: ${doItem['parent_so'] ?? parentSo ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
  //             ],
  //           ),
  //         ),
  //         const Divider(height: 1),
  //         Table(
  //           columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(4), 2: FlexColumnWidth(1)},
  //           children: (doItem['do_details'] as List).map((det) => TableRow(
  //             children: [
  //               _tablePadding(det['material']?['material_id']?.toString() ?? "-"),
  //               _tablePadding(det['material']?['material_name'] ?? "-"),
  //               _tablePadding(det['qty']?.toString() ?? "0", isBold: true, align: TextAlign.right),
  //             ],
  //           )).toList(),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildStatisticGrid() {
  //   return GridView.count(
  //     shrinkWrap: true,
  //     physics: const NeverScrollableScrollPhysics(),
  //     crossAxisCount: 4,
  //     crossAxisSpacing: 15,
  //     mainAxisSpacing: 15,
  //     childAspectRatio: 2.1,
  //     children: [
  //       _statCard("Total Request", totalRequests.toString(), Colors.blue),
  //       _statCard("On Going", ongoingCount.toString(), Colors.orange),
  //       _statCard("Completed", completedCount.toString(), Colors.green),
  //       _statCard("Rejected", rejectedCount.toString(), Colors.red),
  //     ],
  //   );
  // }

  // Widget _statCard(String label, String value, Color color) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(15),
  //       border: Border(left: BorderSide(color: color, width: 5)),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Text(
  //           label,
  //           style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
  //         ),
  //         const SizedBox(height: 4),
  //         Text(
  //           value,
  //           style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildStatisticGrid() {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Jika lebar layar < 600px (HP), pakai 2 kolom. Jika > 600px (Laptop), pakai 4 kolom.
      int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
      // Sesuaikan rasio kotak agar tidak overflow
      double aspectRatio = constraints.maxWidth < 600 ? 1.5 : 2.0;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
        children: [
          _statCard("Total Request", totalRequests.toString(), Colors.blue, Icons.assignment),
          _statCard("On Going", ongoingCount.toString(), Colors.orange, Icons.pending_actions),
          _statCard("Completed", completedCount.toString(), Colors.green, Icons.check_circle),
          _statCard("Rejected", rejectedCount.toString(), Colors.red, Icons.cancel),
        ],
      );
    },
  );
}

Widget _statCard(String label, String value, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Row(
      children: [
        // Indikator Warna & Icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        // Teks
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, 
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              FittedBox(
                child: Text(value, 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
        ),
      ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selamat Datang, Vendor', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 4),
                ],
              ),
              // IconButton(
              //   onPressed: _logout,
              //   icon: const Icon(Icons.logout, color: Colors.white70),
              // )
            ],
          ),
          Text(
            currentUser?.nikVendor ?? 'Loading ID...',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser?.email ?? '-',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

Widget _buildEmptyState() => const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Belum ada pesanan baru untuk Anda.", style: TextStyle(color: Colors.grey))));

  String _formatDate(String? d) => d == null ? "-" : DateFormat('dd MMM yyyy').format(DateTime.parse(d));
  // Widget _buildStatusBanner(bool isApproved) {
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
  //       borderRadius: BorderRadius.circular(15),
  //       border: Border.all(color: isApproved ? Colors.green.shade200 : Colors.orange.shade200),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(
  //           isApproved ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
  //           color: isApproved ? Colors.green : Colors.orange.shade800,
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 isApproved ? 'AKUN TERVERIFIKASI' : 'MENUNGGU VERIFIKASI',
  //                 style: TextStyle(
  //                   fontWeight: FontWeight.bold,
  //                   fontSize: 13,
  //                   color: isApproved ? Colors.green.shade900 : Colors.orange.shade900,
  //                 ),
  //               ),
  //               Text(
  //                 isApproved
  //                     ? 'Silakan akses semua fitur operasional Anda.'
  //                     : 'Fitur akan aktif secara otomatis setelah disetujui Admin.',
  //                 style: TextStyle(
  //                   fontSize: 11,
  //                   color: isApproved ? Colors.green.shade800 : Colors.orange.shade800,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}