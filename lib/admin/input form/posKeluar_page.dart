import 'package:flutter/material.dart';
import 'package:project_app/admin/input%20form/loadingform_page.dart'; // Pastikan import ini benar
import 'package:project_app/dynamic_tab_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SecurityPosKeluarState extends StatefulWidget {
  final Map<String, dynamic> item;
  const SecurityPosKeluarState({super.key, required this.item});

  @override
  State<SecurityPosKeluarState> createState() => _SecurityPosKeluarState();
}

class _SecurityPosKeluarState extends State<SecurityPosKeluarState> {
 //Widget? _currentActiveContent;
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _planningList = [];
  //String? _currentUser;
final TextEditingController _noSuratJalanController = TextEditingController();
bool _isSegelSmart = false;
bool _isSegelPelayaran = false;
// Variabel Filter Baru
  DateTime _selectedDate = DateTime.now();
  String _dateFilterType = 'stuffing_date'; // Default: Shipping Date
  //final TextEditingController _searchController = TextEditingController();
RealtimeChannel? _channel;
int? _expandedId; // Melacak ID yang sedang di-expand
int? _selectedSLoc; // Untuk nilai dropdown di form
List<dynamic> _warehouseList = []; // Pastikan Anda memanggil data warehouse di initState
final TextEditingController _noSegelController = TextEditingController();
final TextEditingController _noGanjalController = TextEditingController();
String _statusSegel = ""; // "Terpasang" atau "Tidak Terpasang"
String _statusGanjal = ""; // "Pengambilan" atau "Pengembalian"

  @override
  void initState() {
    super.initState();
  
    _fetchPlanningData();

  _channel = supabase
      .channel('shipping_assignments_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shipping_assignments',
        callback: (payload) async {
          await _fetchPlanningData();
        },
      )
      .subscribe();

  }

@override
void dispose() {
  _channel?.unsubscribe();
  super.dispose();
}

// // Fungsi untuk memproses Check-in
// Future<void> _handleCheckIn(Map<String, dynamic> item) async {
//   final request = item['request'] ?? {};
//   final String jamBookingStr = item['jam_booking'] ?? "00:00 - 00:00";
  
//   // 1. Ambil Jam Mulai (misal '11:00' dari '11:00 - 13:00')
//   String startTimeStr = jamBookingStr.split(" - ")[0];
  
//   // 2. Buat objek DateTime untuk jam booking hari ini
//   DateTime now = DateTime.now();
//   DateTime bookingTime = DateTime(
//     now.year, now.month, now.day,
//     int.parse(startTimeStr.split(":")[0]),
//     int.parse(startTimeStr.split(":")[1]),
//   );

//   // 3. Cek apakah tanggal stuffing adalah hari ini
//   String stuffingDateStr = request['stuffing_date'] ?? "";
//   bool isToday = DateFormat('yyyy-MM-dd').format(now) == stuffingDateStr;

//   if (!isToday) {
//     _showSnackBar("Check-in hanya bisa dilakukan pada tanggal Stuffing!", Colors.orange);
//     return;
//   }

//   // 4. Deteksi Terlambat (Jika waktu sekarang > jam booking)
//   if (now.isAfter(bookingTime)) {
//     _showLateCheckInDialog(item);
//   } else {
//     _openCheckInTab(item);
//     // PINDAH KE HALAMAN FORM (Normal)
//     //Navigator.push(context, MaterialPageRoute(builder: (c) => CheckInFormPage(item: item, onBack: () {  },)));
//   //_navigateToForm(item);
   
//   }
// }

// Fungsi untuk membuka Tab Form
  void _handleGoToLoading(Map<String, dynamic> item) {
    final groupId = item['request']['group_id'];
    final shipId = item['request']['shipping_id'];

    String tabTitle = groupId != null 
        ? "Loading Grup #$groupId" 
        : "Loading Ship #$shipId";

    DynamicTabPage.of(context)?.openTab(
      tabTitle,
      LoadingFormPage(
        item: item,
        //lateReason: reason,
        // Jika CheckInFormPage butuh callback onBack, tambahkan di sini
      ),
    );
  }
Future<void> _submitData(Map<String, dynamic> item, String actionType) async {
  try {
    // 1. Validasi
    if (_noSuratJalanController.text.trim().isEmpty) {
      _showSnackBar("Harap isi No. Surat Jalan!", Colors.orange);
      return;
    }
    if (!_isSegelSmart && !_isSegelPelayaran) {
      _showSnackBar("Minimal satu segel harus dicentang!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final List<int> assignmentIds = List<int>.from(item['grouped_assignment_ids'] ?? [item['id_assignment']]);
    final List<int> shippingIds = List<int>.from(item['grouped_shipping_ids'] ?? [item['request']['shipping_id']]);

    // 2. Update Assignments
    await supabase.from('shipping_assignments').update({
      'no_surat_jalan': _noSuratJalanController.text.trim(),
      'is_segel_smart': _isSegelSmart,
      'is_segel_pelayaran': _isSegelPelayaran,
      'keluar_at': DateTime.now().toIso8601String(),
      'status_assignment': 'keluar', 
    }).inFilter('id_assignment', assignmentIds);

    // 3. Update Request Utama ke status 'keluar'
    await supabase.from('shipping_request').update({
      'status': 'keluar', 
    }).inFilter('shipping_id', shippingIds);

    // 4. Reset & Feedback
    _noSuratJalanController.clear();
    _isSegelSmart = false;
    _isSegelPelayaran = false;
    _expandedId = null;

    _showSnackBar("Data tersimpan. Unit diizinkan keluar!", Colors.green);
    await _fetchPlanningData(); 

  } catch (e) {
    _showSnackBar("Gagal simpan: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

// Helper untuk menampilkan pesan
void _showSnackBar(String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// Fungsi untuk status Pending (Jika diperlukan)
Future<void> _pendingRequest(Map<String, dynamic> item) async {
  _showSnackBar("Status pengiriman dipending.", Colors.orange);
  setState(() => _expandedId = null);
}
// void _getUserData() {
//     final user = supabase.auth.currentUser;
//     if (user != null) {
//       setState(() {
//         _currentUser = user.email;
//       });
//     }
//   }
  
//   void _navigateToForm(Map<String, dynamic> item, {String? lateReason}) {
//   setState(() {
//     _currentActiveContent = CheckInFormPage(
//       item: item,
//       lateReason: lateReason,
//       // Tambahkan callback onBack agar bisa kembali ke list antrian
//       onBack: () {
//         setState(() {
//           _currentActiveContent = null;
//         });
//       },
//     );
//   });
// // }
// // Dialog Pop-up Alasan Terlambat
// void _showLateCheckInDialog(Map<String, dynamic> item) {
//   final TextEditingController reasonController = TextEditingController();
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (context) => AlertDialog(
//       title: const Text("⚠️ Check-in Terlambat", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text("Anda telah melewati batas jam booking. Silakan masukkan alasan keterlambatan:"),
//           const SizedBox(height: 10),
//           TextField(
//             controller: reasonController,
//             decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Contoh: Macet, Ban Bocor, dll"),
//             maxLines: 3,
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//           onPressed: () {
//             if (reasonController.text.trim().isEmpty) {
//               _showSnackBar("Alasan harus diisi!", Colors.orange);
//               return;
//             }
           
//     //   Navigator.push(
//     //     context,
//     //     MaterialPageRoute(
//     //       builder: (context) => AssignVendorPage(shippingId: item['shipping_id']),
//     //     ),
//     //   );
//     // },
//   //  final String shipId = item['shipping_id'].toString();
              
//   //             DynamicTabPage.of(context)?.openTab(
//   //               "Assign Vendor Shipping #$shipId", 
//   //               AssignVendorPage(shippingId: item['shipping_id']),
//   //             );
//   //           },
//   // final groupId = item['group_id'];
//   // final shipId = item['shipping_id'];
  
//   // // 2. Tentukan Judul Tab secara dinamis
//   // String tabTitle;
//   // if (groupId != null) {
//   //   tabTitle = "Assign Vendor Grup #$groupId";
//   // } else {
//   //   tabTitle = "Assign Vendor Shipping #$shipId";
//   // }

//   // 3. Panggil DynamicTab untuk membuka halaman di dalam bingkai
//   // DynamicTabPage.of(context)?.openTab(
//   //   tabTitle, 
//   //   CheckInFormPage(item: item, lateReason: reasonController.text), // ID yang dikirim tetap shippingId utama
//   // );

//             //Navigator.pop(context);
//            // PINDAH KE HALAMAN FORM (Membawa alasan terlambat)
//             // Navigator.push(context, MaterialPageRoute(builder: (c) => 
//             //    CheckInFormPage(item: item, lateReason: reasonController.text)));
//             //_navigateToForm(item, lateReason: reasonController.text);
//              Navigator.pop(context); // Tutup dialog
//               _openCheckInTab(item, reason: reasonController.text);
            
//           },
//           child: const Text("LANJUT KE FORM", style: TextStyle(color: Colors.white)),
//         ),
//       ],
//     ),
//   );
// }

// // Fungsi Eksekusi Update ke Database
// Future<void> _processCheckIn(Map<String, dynamic> item, String? lateReason) async {
//   try {
//     setState(() => _isLoading = true);
    
//     // Ambil semua ID jika ini adalah grup
//     final List<int> assignmentIds = List<int>.from(item['grouped_assignment_ids'] ?? [item['id_assignment']]);

//     await supabase.from('shipping_assignments').update({
//       'status_assignment': 'check in',
//       'checkIn_at': DateTime.now().toIso8601String(),
//       'latecheckIn_reason': lateReason, // Simpan alasan jika terlambat
//     }).inFilter('id_assignment', assignmentIds);

//     _showSnackBar("Berhasil Check-in!", Colors.green);
//     _fetchPlanningData(); // Refresh list
//   } catch (e) {
//     setState(() => _isLoading = false);
//     _showSnackBar("Gagal Check-in: $e", Colors.red);
//   }
// }

// Future<void> _processCheckIn(Map<String, dynamic> item, String? lateReason) async {
//   try {
//     setState(() => _isLoading = true);
    
//     final List<int> assignmentIds = List<int>.from(item['grouped_assignment_ids'] ?? [item['id_assignment']]);
//     final List<int> shipIds = List<int>.from(item['grouped_shipping_ids'] ?? [item['shipping_id']]);

// // UPDATE 1: Tabel Assignments (Data Detail Eksekusi)
//     // await supabase.from('shipping_assignments').update({
//     //   'status_assignment': 'check in',
//     //   'checkin_at': DateTime.now().toIso8601String(),
//     //   'late_reason': lateReason,
//     // }).inFilter('id_assignment', assignmentIds);

//     // 1. Simpan Milestone Kedatangan di tabel Assignments (Tanpa ubah status)
//     await supabase.from('shipping_assignments').update({
//       'checkIn_at': DateTime.now().toIso8601String(),
//       'latecheckIn_reason': lateReason, 
//       'checkIn_by': _currentUser ?? 'admin',
//       // Status assignment dibiarkan 'accepted' sesuai permintaan Anda
//     }).inFilter('id_assignment', assignmentIds);

//     // 2. Update Status Utama di tabel Request (Sesuai keinginan Anda)
//     await supabase.from('shipping_request').update({
//       'status': 'check in', 
//     }).inFilter('shipping_id', shipIds);

//     if (mounted) {
//       _showSnackBar("Berhasil Check-in!", Colors.green);
//       _fetchPlanningData(); // Refresh data
//     }
//   } catch (e) {
//     if (mounted) {
//       setState(() => _isLoading = false);
//       _showSnackBar("Gagal Check-in: $e", Colors.red);
//     }
//   }
// }

// void _showSnackBar(String msg, Color color) {
//   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
// }
  // Future<void> _fetchPlanningData() async {
  //   try {
  //     setState(() => _isLoading = true);
  //     final response = await supabase
  //         .from('shipping_assignments')
  //         .select('*, request:shipping_id(*, delivery_order(*, customer(*)))')
  //         .eq('status_assignment', 'accepted')
  //         .not('jam_booking', 'is', null)
  //         .order('jam_booking', ascending: true);

  //     setState(() {
  //       _planningList = response;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     debugPrint("Error: $e");
  //   }
  // }

//   Future<void> _fetchPlanningData() async {
//   try {
//     setState(() => _isLoading = true);

//     // Format tanggal ke string YYYY-MM-DD untuk filter database
//     String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
//     String columnPath = "request.$_dateFilterType";
//     // Query dengan join lengkap ke vendor, customer, dan material
//    final response = await supabase
//         .from('shipping_assignments')
//         .select('''
//           *,
//           master_vendor:nik (vendor_name), 
//           request:shipping_id (
//             shipping_id,
//             so,
//             rdd,
//             stuffing_date,
//             group_id,
//             storage_location,
//             is_dedicated,
//             warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
//             delivery_order (
//               do_number,
//               customer (customer_id, customer_name),
//               do_details (
//                 qty,
//                 material:material_id (material_id, material_name)
//               )
//             )
//           )
//         ''')
//         .eq('status_assignment', 'accepted')
//         .not('jam_booking', 'is', null)
//         // Filter tepat pada tanggal yang dipilih
//        .eq('request.$_dateFilterType', formattedDate)
//        .order('jam_booking', ascending: true);
    
//     // --- PROSES SUNTIK RDD KE TIAP DO ---
//     final List<dynamic> processedData = List.from(response);
//     for (var item in processedData) {
//       final req = item['request'];
//       if (req != null && req['delivery_order'] != null) {
//         for (var doItem in req['delivery_order']) {
//           // Suntikkan RDD dari request ke level DO
//           doItem['rdd_origin'] = req['rdd'];
//         }
//       }
//     }

//     setState(() {
//       _planningList = response;
//       _isLoading = false;
//     });
//   } catch (e) {
//     setState(() => _isLoading = false);
//     debugPrint("Error Fetch Planning: $e");
//   }
// }

// Future<void> _fetchPlanningData() async {
//   try {
//     setState(() => _isLoading = true);

//     String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
//     final response = await supabase
//         .from('shipping_assignments')
//         .select('''
//           *,
//           master_vendor:nik (vendor_name), 
//           request:shipping_id (
//             shipping_id, so, rdd, stuffing_date, group_id, storage_location, is_dedicated,
//             warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
//             delivery_order (
//               do_number,
//               customer (customer_id, customer_name),
//               do_details (
//                 qty,
//                 material:material_id (material_id, material_name)
//               )
//             )
//           )
//         ''')
//         .eq('status_assignment', 'accepted')
//         .not('jam_booking', 'is', null)
//         .eq('request.$_dateFilterType', formattedDate)
//         .neq('request.status', 'check in')
//         .order('jam_booking', ascending: true);

//     // --- PROSES GROUPING MANUAL AGAR TIDAK DUPLIKAT ---
//     Map<String, dynamic> groupedData = {};

//     for (var item in response) {
//       final req = item['request'];
//       if (req == null) continue;

//       // Tentukan Unique Key (Jika ada group_id pakai itu, jika tidak pakai shipping_id)
//       String key = req['group_id'] != null 
//           ? "GROUP_${req['group_id']}" 
//           : "SINGLE_${req['shipping_id']}";

//       if (!groupedData.containsKey(key)) {
//         // Jika key belum ada, masukkan data pertama
//         groupedData[key] = Map<String, dynamic>.from(item);
        
//         // Inisialisasi rdd_origin untuk setiap DO di item pertama ini
//         if (groupedData[key]['request']['delivery_order'] != null) {
//           for (var d in groupedData[key]['request']['delivery_order']) {
//             d['rdd_origin'] = req['rdd'];
//           }
//         }
//       } else {
//         // Jika key sudah ada (berarti ini anggota grup yang lain), gabungkan DO-nya
//         List currentDOs = List.from(groupedData[key]['request']['delivery_order'] ?? []);
//         List newDOs = List.from(req['delivery_order'] ?? []);

//         for (var ndo in newDOs) {
//           ndo['rdd_origin'] = req['rdd']; // Tetap simpan RDD aslinya
//           currentDOs.add(ndo);
//         }
//         groupedData[key]['request']['delivery_order'] = currentDOs;
//       }
//     }

//     setState(() {
//       _planningList = groupedData.values.toList();
//       _isLoading = false;
//     });
//   } catch (e) {
//     setState(() => _isLoading = false);
//     debugPrint("Error Fetch Planning: $e");
//   }
// }

Future<void> _fetchPlanningData() async {
  try {
    setState(() => _isLoading = true);

    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    final response = await supabase
        .from('shipping_assignments')
        .select('''
          *,
          master_vendor:nik (vendor_name), 
          request:shipping_id (
            shipping_id, so, rdd, stuffing_date, group_id, storage_location, is_dedicated,
            warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order (
              do_id,
              do_number,
              customer (customer_id, customer_name),
              do_details (
                qty,
                material:material_id (material_id, material_name,net_weight)
              )
            )
          )
        ''')
        .eq('status_assignment', 'weighbridge')
        .not('jam_booking', 'is', null)
        .eq('request.stuffing_date', formattedDate)
        .neq('request.status', 'keluar')
        .order('jam_booking', ascending: true);

    Map<String, dynamic> groupedData = {};

    for (var item in response) {
      final req = item['request'];
      if (req == null) continue;

      String key = req['group_id'] != null 
          ? "GROUP_${req['group_id']}" 
          : "SINGLE_${req['shipping_id']}";

      if (!groupedData.containsKey(key)) {
        groupedData[key] = Map<String, dynamic>.from(item);
        groupedData[key]['grouped_assignment_ids'] = [item['id_assignment']];
        groupedData[key]['grouped_shipping_ids'] = [req['shipping_id']];
        
        // Inisialisasi rdd_origin
        if (groupedData[key]['request']['delivery_order'] != null) {
          for (var d in groupedData[key]['request']['delivery_order']) {
            d['rdd_origin'] = req['rdd'];
          }
        }
      } else {
        // Jika sudah ada (Grup), tambahkan ID untuk keperluan update nanti
        groupedData[key]['grouped_assignment_ids'].add(item['id_assignment']);
        groupedData[key]['grouped_shipping_ids'].add(req['shipping_id']);

        // --- CEK DUPLIKASI DO SEBELUM MENGGABUNGKAN ---
        List currentDOs = groupedData[key]['request']['delivery_order'] ?? [];
        List newDOs = req['delivery_order'] ?? [];

        for (var ndo in newDOs) {
          // Hanya tambahkan jika do_number belum ada di list saat ini
          bool isDuplicate = currentDOs.any((existing) => 
            existing['do_number'] == ndo['do_number']);
          
          if (!isDuplicate) {
            ndo['rdd_origin'] = req['rdd'];
            currentDOs.add(ndo);
          }
        }
        groupedData[key]['request']['delivery_order'] = currentDOs;
      }
    }

    setState(() {
      _planningList = groupedData.values.toList();
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    debugPrint("Error Fetch Planning: $e");
  }
}

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     // appBar: AppBar(
  //     //   title: const Text("ANTRIAN PLANNING BOOKING", 
  //     //     style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
  //     //   backgroundColor: Colors.red.shade800,
  //     // ),
  //     body: _isLoading
  //         ? const Center(child: CircularProgressIndicator())
  //         : RefreshIndicator(
  //             onRefresh: _fetchPlanningData,
  //             child: _planningList.isEmpty
  //                 ? _buildEmptyState()
  //                 : ListView.builder(
  //                     padding: const EdgeInsets.all(12),
  //                     itemCount: _planningList.length,
  //                     itemBuilder: (context, index) => _buildPlanningCard(_planningList[index]),
  //                   ),
  //           ),
  //   );
  // }
  @override
  Widget build(BuildContext context) {
  //   if (_currentActiveContent != null) {
  //   return _currentActiveContent!;
  // }
    return Scaffold(
      body: Column(
        children: [
          _buildTopFilterBar(), // Tambahkan baris filter
          Expanded(
            child:  _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchPlanningData,
                  child: _planningList.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _planningList.length,
                          itemBuilder: (context, index) {
                          final item = _planningList[index];
                            final request = item['request'] ?? {};
                            // Mengambil ID unik untuk toggle expand
                            final int sid = request['group_id'] ?? request['shipping_id'] ?? 0;
                            final bool isExpanded = _expandedId == sid;
                              return _buildPlanningCard(item, sid, isExpanded);
                          },
                        ),
                ),
        ),
      ],
    ),
  );
}
  
// Widget _buildTopFilterBar() {
//   // Mengecek apakah tanggal yang dipilih adalah hari ini untuk menentukan warna
//   bool isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == 
//                  DateFormat('yyyy-MM-dd').format(DateTime.now());

//   return Container(
//     padding: const EdgeInsets.all(12),
//     color: Colors.white,
//     child: Row(
//       children: [
//         Expanded(
//           child: Container(
//             decoration: BoxDecoration(
//               // Beri warna merah jika bukan hari ini (menandakan filter aktif)
//               color: !isToday ? Colors.red.shade700 : Colors.grey.shade200,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Row(
//               children: [
//                 // 1. Dropdown Tipe Tanggal
//                 Container(
//                   padding: const EdgeInsets.only(left: 12, right: 8),
//                   decoration: BoxDecoration(
//                     border: Border(
//                       right: BorderSide(
//                         color: !isToday ? Colors.white30 : Colors.grey.shade400,
//                         width: 1,
//                       ),
//                     ),
//                   ),
//                   child: DropdownButtonHideUnderline(
//                     child: DropdownButton<String>(
//                       value: _dateFilterType == 'stuffing_date' ? "Stuffing" : "RDD",
//                       isDense: true,
//                       dropdownColor: !isToday ? Colors.orange[300] : Colors.white,
//                       iconEnabledColor: !isToday ? Colors.white : Colors.black87,
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                         color: !isToday ? Colors.white : Colors.black87,
//                       ),
//                       items: ["RDD", "Stuffing"].map((String value) {
//                         return DropdownMenuItem<String>(
//                           value: value,
//                           child: Text(value),
//                         );
//                       }).toList(),
//                       onChanged: (val) {
//                         setState(() {
//                           _dateFilterType = val == "RDD" ? "rdd" : "stuffing_date";
//                         });
//                         _fetchPlanningData();
//                       },
//                     ),
//                   ),
//                 ),
//                 // 2. Tombol Pilih Tanggal Tunggal
//                 Expanded(
//                   child: InkWell(
//                     onTap: _selectSingleDate,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.calendar_today,
//                             size: 16,
//                             color: !isToday ? Colors.white : Colors.black87,
//                           ),
//                           const SizedBox(width: 10),
//                           Text(
//                             DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
//                             style: TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                               color: !isToday ? Colors.white : Colors.black87,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         // Tombol Reset ke Hari Ini
//         if (!isToday)
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.red),
//             onPressed: () {
//               setState(() {
//                 _selectedDate = DateTime.now();
//                 _dateFilterType = "stuffing_date";
//               });
//               _fetchPlanningData();
//             },
//           ),
//       ],
//     ),
//   );
// }
Widget _buildTopFilterBar() {
  bool isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                 DateFormat('yyyy-MM-dd').format(DateTime.now());

  return Container(
    padding: const EdgeInsets.all(12),
    color: Colors.white,
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: !isToday ? Colors.red.shade700 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              onTap: _selectSingleDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: !isToday ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "STUFFING: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !isToday ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down,
                      color: !isToday ? Colors.white : Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isToday)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
              _fetchPlanningData();
            },
          ),
      ],
    ),
  );
}


Future<void> _selectSingleDate() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(2023),
    lastDate: DateTime(2100),
    locale: const Locale('id', 'ID'),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Colors.red.shade700),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: child!,
          ),
        ),
      );
    },
  );

  if (picked != null && picked != _selectedDate) {
    setState(() => _selectedDate = picked);
    _fetchPlanningData();
  }
}

Widget _buildPlanningCard(Map<String, dynamic> item,int sid, bool isExpanded) {
  final Map<String, dynamic> request = item['request'] ?? {};
  final vendor = item['master_vendor'] ?? {};

  if (request.isEmpty) return const SizedBox.shrink();
  
  final List dos = request['delivery_order'] as List? ?? [];
  final bool isGroup = request['group_id'] != null;
  final warehouse = request['warehouse'];
  
  String warehouseDisplay = warehouse != null 
      ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 
      : "-";

// --- LOGIKA HITUNG TOTAL TONASE (Sesuai contoh yang Anda berikan) ---
  double sumNW = 0;
  for (var doItem in dos) {
    for (var det in doItem['do_details'] ?? []) {
      double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
      double unitWeight = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
      sumNW += (qty * unitWeight);
    }
  }
  double totalTonase = sumNW / 1000;

 return Card(
  elevation: isExpanded ? 4 : 1,
  margin: const EdgeInsets.only(bottom: 16),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  clipBehavior: Clip.antiAlias,
  child: InkWell(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    onTap: () {
      setState(() {
        _expandedId = isExpanded ? null : sid;
      });
    },
    child: Column(
      children: [
        // Header (Jam & Label)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    item['jam_booking'] ?? "-",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  isGroup ? "GROUP SHIP ${request['group_id']}" : "SINGLE SHIP ${request['shipping_id']}",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Log
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Assigned: ${_formatDateTime(item['assigned_at'])}",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                  Text("Responded: ${_formatDateTime(item['responded_at'])}",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                ],
              ),
              const SizedBox(height: 8),
              
              // Baris Info Umum
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoBox("STUFFING DATE", _formatDate(request['stuffing_date'])),
                  _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase()),
                  _infoBox("TYPE", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
                ],
              ),
              const Divider(height: 24),

              // Info Vendor
              Row(
                children: [
                  const Icon(Icons.store, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${item['nik']} - ${vendor['vendor_name'] ?? 'Unknown Vendor'}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                 // _infoBox("STATUS", item['status_assignment'].toString().toUpperCase()),
                  //_infoBox("CHECK-IN AT", _formatDateTime(item['checkIn_at'])),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          "Check-in At: ${_formatDateTime(item['checkIn_at'])}",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
// Tampilkan info jika dia check-in terlambat
               if (item['latecheckIn_reason'] != null) ...[
                          const SizedBox(width: 12),
                          const Text("|", style: TextStyle(color: Colors.orange, fontSize: 11)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Terlambat: ${item['latecheckIn_reason']}",
                              style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // TAMBAHKAN PEMBATAS TIPIS
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 1, color: Colors.orange),
      ),

      // BARIS LOADING & CHECKER (BARU)
      Row(
        children: [
          const Icon(Icons.hourglass_bottom, size: 14, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            "Loading At: ${_formatDateTime(item['loading_at'])}",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
          ),
          const SizedBox(width: 12),
          const Text("|", style: TextStyle(color: Colors.orange, fontSize: 11)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Checker: ${item['loading_by'] ?? '-'}", // Sesuaikan field 'loading_by' dengan DB Anda
              style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
           ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
              if (isExpanded) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // --- LOOPING DETAIL DO (Sudah Gabung) ---
              ...dos.map((doItem) {
                final List details = doItem['do_details'] ?? [];
                final String rddSpesifik = _formatDate(doItem['rdd_origin']);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Text("RDD: $rddSpesifik",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFCE4EC),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                                Text("SO: ${request['so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text("${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", 
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Table(
                            columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(4), 2: FlexColumnWidth(1)},
                            children: details.map((det) {
                              final mat = det['material'] ?? {};
                              return TableRow(
                                children: [
                                  _tableCell(mat['material_id']?.toString() ?? "-"),
                                  _tableCell(mat['material_name'] ?? "-"),
                                  _tableCell(det['qty']?.toString() ?? "0", align: TextAlign.right, isBold: true),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
              //const Divider(height: 24),

      // TAMPILAN TOTAL TONASE (Pojok Kanan)
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Total Tonase:",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              Text(
                "${totalTonase.toStringAsFixed(3)} TON",
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.blueAccent
                ),
              ),
            ],
          ),
          
        ),
      ),
       // Form Action (Input Gudang, Tombol Proses)
            _buildActionForm(item),
      
//               SizedBox(
//   width: double.infinity,
//   child: ElevatedButton.icon(
//     onPressed: () =>_handleGoToLoading(item),
//     icon: const Icon(Icons.outbound, color: Colors.white),
//     label: const Text("SIMPAN & LANJUT KE POS KELUAR", 
//         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
//     style: ElevatedButton.styleFrom(
//       backgroundColor: Colors.green.shade700,
//       padding: const EdgeInsets.symmetric(vertical: 12),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//     ),
//   ),
// ),
            ],
          ),
            ),
              ],
              ],
          ),
        ),          
    );

    
}

Widget _buildActionForm(Map<String, dynamic> item) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 12),
        // const Row(
        //   children: [
        //     Icon(Icons.security, size: 18, color: Colors.blueGrey),
        //     SizedBox(width: 8),
        //     // Text("4. DIISI OLEH SECURITY WEIGHBRIDGE",
        //     //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
        //   ],
        // ),
        // const SizedBox(height: 16),
        
        // --- BARIS INPUT ---
       // --- BARIS INPUT ---
// --- BARIS NO SURAT JALAN ---
        // _buildLabel("No. Surat Jalan"),
        // const SizedBox(height: 4),
        //   _buildMinimalInput(_noSuratJalanController),
        
        // const SizedBox(height: 4),
        
        // // --- BARIS CHECKBOX SEGEL ---
        // Row(
        //   children: [
        //     SizedBox(
        //       width: 150, 
        //       child: 
        //       _buildLabel("Segel terpasang dengan kondisi baik:"),
        //     ),
        //     // Checkbox Segel SMART
        //     Checkbox(
        //       value: _isSegelSmart,
        //       activeColor: Colors.green.shade700,
        //       onChanged: (val) => setState(() => _isSegelSmart = val!),
        //     ),
        //     const Text("Segel SMART", style: TextStyle(fontSize: 11)),
        //     const SizedBox(width: 20),
        //     // Checkbox Segel Pelayaran
        //     Checkbox(
        //       value: _isSegelPelayaran,
        //       activeColor: Colors.green.shade700,
        //       onChanged: (val) => setState(() => _isSegelPelayaran = val!),
        //     ),
        //     const Text("Segel Pelayaran", style: TextStyle(fontSize: 11)),
        //   ],
        // ),      
        //
         // ===== INPUT NO SURAT JALAN =====
        _buildLabel("No. Surat Jalan"),
        const SizedBox(height: 6),

        SizedBox(
          width: 350,
          child: TextField(
            controller: _noSuratJalanController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Masukkan nomor surat jalan",
              hintStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              prefixIcon: Icon(
                Icons.receipt_long,
                size: 18,
                color: Colors.grey.shade600,
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.green.shade700,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ===== CHECKBOX SECTION =====
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 18,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),

                  const Text(
                    "Pemeriksaan Segel",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text(
                "Segel terpasang dengan kondisi baik",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [

                  // SEGEL SMART
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isSegelSmart,
                        activeColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _isSegelSmart = val!;
                          });
                        },
                      ),
                      const Text(
                        "Segel SMART",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),

                  // SEGEL PELAYARAN
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isSegelPelayaran,
                        activeColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _isSegelPelayaran = val!;
                          });
                        },
                      ),
                      const Text(
                        "Segel Pelayaran",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),  
        const SizedBox(height: 24),

        // --- TOMBOL ACTION ---
        SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () =>_submitData(item, 'SAVE'),
    icon: const Icon(Icons.save, color: Colors.white),
    label: const Text("SIMPAN DATA", 
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green.shade700,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
),
      ],
      //   Row(
      //     children: [
      //       Expanded(
      //         flex: 1,
      //         child: OutlinedButton(
      //           style: OutlinedButton.styleFrom(
      //             side: const BorderSide(color: Colors.orange),
      //             foregroundColor: Colors.orange,
      //             padding: const EdgeInsets.symmetric(vertical: 15),
      //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      //           ),
      //           onPressed: () => _pendingRequest(item),
      //           child: const Text("PENDING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      //         ),
      //       ),
      //       const SizedBox(width: 12),
      //       Expanded(
      //         flex: 2,
      //         child: ElevatedButton(
      //           style: ElevatedButton.styleFrom(
      //             backgroundColor: Colors.green.shade700,
      //             foregroundColor: Colors.white,
      //             padding: const EdgeInsets.symmetric(vertical: 15),
      //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      //           ),
      //           onPressed: () => _processShippingRequest(item, 'SAVE'),
      //           child: const Text("SIMPAN & LANJUT KE POS KELUAR", 
      //               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      //         ),
      //       ),
      //     ],
      //   ),
      // ],
    ),

  );
}

// 1. Helper Label (Sesuai gaya yang Anda inginkan)
Widget _buildLabel(String text) {
  return Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11, 
      color: Colors.black, 
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5
    ),
  );
}

// 2. Helper Input Field Bersih
Widget _buildMinimalInput(TextEditingController controller) {
  return SizedBox(
    height: 38,
     width: 400, 
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1),
        ),
      ),
      style: const TextStyle(fontSize: 13),
    ),
  );
}

// 3. Helper Checkbox Horizontal
Widget _buildMinimalCheckbox(List<String> options, String currentVal, Function(String?) onChanged) {
  return Wrap( // Menggunakan Wrap agar aman jika layar sempit
    spacing: 0,
    children: options.map((opt) {
      bool isSelected = currentVal == opt;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: Colors.red.shade700,
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: isSelected ? Colors.red : Colors.grey.shade400),
            onChanged: (bool? value) => onChanged(value! ? opt : ""),
          ),
          Text(opt, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 8),
        ],
      );
    }).toList(),
  );
}
// Helper untuk Input teks bergaya Baris
Widget _buildInlineInput(String label, TextEditingController controller) {
  return Row(
    children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
      const Text(" :  "),
      Expanded(
        child: SizedBox(
          height: 35,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    ],
  );
}

// Helper untuk Checkbox bergaya Baris (seperti gambar)
Widget _buildInlineCheckbox(String label, List<String> options, String currentVal, Function(String?) onChanged) {
  return Row(
    children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
      const Text(" :  "),
      ...options.map((opt) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: currentVal == opt,
            visualDensity: VisualDensity.compact,
            onChanged: (bool? value) => onChanged(value! ? opt : ""),
          ),
          Text(opt, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 8),
        ],
      )).toList(),
    ],
  );
}

Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: 11,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: isHeader ? Colors.black : Colors.black87,
      ),
    ),
  );
}
// Helper untuk format tanggal dan jam (Assigned & Responded)
// String _formatDateTime(String? dateStr) {
//   if (dateStr == null) return "-";
//   DateTime dt = DateTime.parse(dateStr).toLocal();
//   return DateFormat('dd/MM/yy HH:mm').format(dt);
// }

// String _formatDateTime(String? dateStr) {
//   if (dateStr == null || dateStr.isEmpty) return "-";

//   try {
//     // Parse UTC dari database
//     DateTime utcTime = DateTime.parse(dateStr);

//     // Convert ke timezone device/user
//     DateTime localTime = utcTime.toLocal();

//     // Format tampilan
//     return DateFormat('dd/MM/yy HH:mm').format(localTime);
//   } catch (e) {
//     debugPrint("Error parsing datetime: $e");
//     return "-";
//   }
// }
String _formatDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return "-";

  try {
    DateTime time = DateTime.parse(dateStr);

    return DateFormat('dd/MM/yy HH:mm').format(time);
  } catch (e) {
    debugPrint("Error parsing datetime: $e");
    return "-";
  }
}
// String _formatDateTime(String? dateStr) {
//   if (dateStr == null || dateStr.isEmpty) return "-";
  
//   try {
//     // 1. Parsing string dari DB (Supabase mengirim ISO8601 dengan offset +00)
//     DateTime utcTime = DateTime.parse(dateStr);
    
//     // 2. Paksa konversi ke waktu Lokal (WIB/UTC+7 jika di Indonesia)
//     //DateTime localTime = utcTime.toLocal();
//     DateTime localTime = utcTime.add(const Duration(hours: 7));
//     // 3. Format lengkap: dd/MM/yy HH:mm (Contoh: 10/05/26 22:03)
//     return DateFormat('dd/MM/yy HH:mm').format(localTime);
//   } catch (e) {
//     debugPrint("Error parsing date: $e");
//     return "-";
//   }
// }

Widget _infoBox(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  );
} 

  // Widget _infoColumn(String label, String value, {Color? color}) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
  //       Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
  //     ],
  //   );
  // }


  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); } catch (e) { return "-"; }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Tidak ada antrian keluar saat ini", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}