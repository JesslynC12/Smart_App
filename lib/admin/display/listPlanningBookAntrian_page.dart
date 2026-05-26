import 'package:flutter/material.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:project_app/vendor/booking_antrian.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookingPlanningListPage extends StatefulWidget {
  const BookingPlanningListPage({super.key});

  @override
  State<BookingPlanningListPage> createState() => _BookingPlanningListPageState();
}

class _BookingPlanningListPageState extends State<BookingPlanningListPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _planningList = [];

// Variabel Filter Baru
  DateTime _selectedDate = DateTime.now();
  String _dateFilterType = 'stuffing_date'; // Default: Shipping Date
  //final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _filteredPlanningList = [];
//RealtimeChannel? _channel;
int? _expandedId; // Melacak ID yang sedang di-expand
int? _selectedSLoc; // Untuk nilai dropdown di form
List<dynamic> _warehouseList = []; // Pastikan Anda memanggil data warehouse di initState
  final TextEditingController _searchController = TextEditingController();
RealtimeChannel? _assignmentsChannel;
  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _loadingChannel;

final TextEditingController _otherReasonController = TextEditingController();
String? _tempCancelReason;

  @override
  void initState() {
    super.initState();
  
  _fetchPlanningData(showGlobalLoading: true);
    _initRealtimeStreams();
    _searchController.addListener(_filterDataBySearch);

  }

// --- INISIALISASI REALTIME STREAM UNTUK AUTO REFRESH ---
  void _initRealtimeStreams() {
    // 1. Dengarkan Perubahan tabel shipping_assignments
    _assignmentsChannel = supabase
        .channel('shipping_assignments_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_assignments',
          callback: (payload) async {
            debugPrint("Realtime Assignment Update Terdeteksi!");
            await _fetchPlanningData(showGlobalLoading: false);
          },
        )
        .subscribe();

    // 2. Dengarkan Perubahan tabel shipping_request (Penting saat Batal/Reset Status)
    _requestsChannel = supabase
        .channel('shipping_requests_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_request',
          callback: (payload) async {
            debugPrint("Realtime Request Update Terdeteksi!");
            await _fetchPlanningData(showGlobalLoading: false);
          },
        )
        .subscribe();

    // 3. Dengarkan Perubahan tabel loading
    _loadingChannel = supabase
        .channel('loading_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'loading',
          callback: (payload) async {
            debugPrint("Realtime Loading Update Terdeteksi!");
            await _fetchPlanningData(showGlobalLoading: false);
          },
        )
        .subscribe();
  }

// @override
// void dispose() {
//   _channel?.unsubscribe();
//   super.dispose();
// }


@override
  void dispose() {
     _searchController.dispose();
    _assignmentsChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    _loadingChannel?.unsubscribe();
    super.dispose();
  }
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
final List<String> _rescheduleReasons = [
  'Tidak Ada Supir',
    'Tidak Ada Unit',
    'Unit Rusak',
    'Jalan Macet',
    'Dokumen Expired',
    'Vendor Tidak Datang',
    'Other'
];

// Future<void> _fetchPlanningData({bool showGlobalLoading = false}) async {
//   try {
//     if (showGlobalLoading) {
//     setState(() => _isLoading = true);
//     }

// // 1. Update assignment yang expired menjadi 'no response'
//     final expiredAssignments = await supabase
//         .from('shipping_assignments')
//         .update({
//           'status_assignment': 'no response',
//           'responded_at': DateTime.now().toIso8601String(),
//         })
//         .eq('status_assignment', 'offered')
//         .lt('assigned_at', DateTime.now().subtract(const Duration(hours: 2)).toIso8601String())
//         .select('shipping_id'); // Ambil list shipping_id yang hangus

//     // 2. Jika ada data yang hangus, kembalikan status shipping_request-nya agar admin bisa pilih vendor baru
//     if (expiredAssignments != null && (expiredAssignments as List).isNotEmpty) {
//       List<int> expiredShippingIds = List<int>.from(expiredAssignments.map((e) => e['shipping_id']));
      
//       await supabase
//           .from('shipping_request')
//           .update({'status': 'waiting assign vendor delivery'})
//           .inFilter('shipping_id', expiredShippingIds);
//     }

//     String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
//     final response = await supabase
//         .from('shipping_assignments')
//         .select('''
//           *,
//           master_vendor:nik (vendor_name), 
//           vendor_transportasi:id_vendor_details (
//         qcf,
//         city,
//         area,
//         type_unit
//       ),
//           loading:loading (
//             loading_at,
//             loading_by
//           ),
//           request:shipping_id (
//             shipping_id, so, rdd, status, stuffing_date, group_id, storage_location, is_dedicated,
//             warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
//             delivery_order (
//               do_number,
//               customer (customer_id, customer_name),
//               do_details (
//                 qty,
//                 material:material_id (material_id, material_name,net_weight)
//               )
//             )
//           )
//         ''')
//         // .eq('status_assignment', 'accepted')
//         // .inFilter('status_assignment', ['offered','accepted', 'check in', 'loading','weighbridge','keluar','cancel booking','rejected','on going','no response','completed','rejected unit'])
//         // .not('jam_booking', 'is', null)
//        .eq('request.stuffing_date', formattedDate)
//         .order('jam_booking', ascending: true);

// // Jika response kosong, langsung bersihkan list
//     if (response == null || (response as List).isEmpty) {
//       setState(() {
//         _planningList = [];
//         _isLoading = false;
//       });
//       return;
//     }

//     // --- PROSES GROUPING MANUAL AGAR TIDAK DUPLIKAT ---
//     Map<String, dynamic> groupedData = {};

//     for (var item in response) {
//       final req = item['request'];
//       if (req == null) continue;

//       // Tentukan Unique Key (Jika ada group_id pakai itu, jika tidak pakai shipping_id)
//       String key = req['group_id'] != null 
//           ? "GROUP_${req['group_id']}" 
//           : "SINGLE_${req['shipping_id']}";

//     // Ambal info vendor dan status saat ini
//       String currentStatus = item['status_assignment']?.toString().toLowerCase() ?? "";
//       String currentVendorName = item['master_vendor']?['vendor_name'] ?? 'Unknown Vendor';
//       String currentReason = item['reason_rejected'] ?? 'Tanpa Alasan';

//       if (!groupedData.containsKey(key)) {
//         groupedData[key] = Map<String, dynamic>.from(item);
//         groupedData[key]['grouped_assignment_ids'] = [item['id_assignment']];
//         groupedData[key]['grouped_shipping_ids'] = [req['shipping_id']];
        
//         // Buat list kosong untuk menampung riwayat log cancel/reject
//         groupedData[key]['history_logs'] = <Map<String, String>>[]; 

//         // Jika data pertama ini sudah berstatus rusak, masukkan ke log riwayat
//         if (['rejected', 'no response', 'cancel booking', 'rejected unit'].contains(currentStatus)) {
//           groupedData[key]['history_logs'].add({
//             'status': currentStatus,
//             'vendor': currentVendorName,
//             'reason': currentReason,
//           });
//         }

//         List currentDOs = List.from(groupedData[key]['request']['delivery_order'] ?? []);
//         for (var d in currentDOs) {
//           d['rdd_origin'] = req['rdd'];
//           d['parent_so'] = req['so'];
//           d['parent_shipping_id'] = req['shipping_id'];
//         }
//         groupedData[key]['request']['delivery_order'] = currentDOs;
//       } 
//       else {
   
//     // --- DATA PENDAMPING (Ditemukan penugasan lain untuk DO/Grup yang sama) ---
        
//         // A. Filter Riwayat: Agar teks tidak double di Group DO
//         List<Map<String, String>> existingLogs = List<Map<String, String>>.from(groupedData[key]['history_logs'] ?? []);
//         bool isAlreadyLogged = existingLogs.any((log) => 
//             log['vendor'] == currentVendorName && 
//             log['status'] == currentStatus &&
//             log['reason'] == currentReason);

//         if (!isAlreadyLogged && ['rejected', 'no response', 'cancel booking', 'rejected unit'].contains(currentStatus)) {
//           existingLogs.add({
//             'status': currentStatus,
//             'vendor': currentVendorName,
//             'reason': currentReason,
//           });
//         }

//         // B. Cek Update: Apakah data ini lebih baru (id_assignment lebih besar)?
//         int existingId = int.tryParse(groupedData[key]['id_assignment'].toString()) ?? 0;
//         int currentId = int.tryParse(item['id_assignment'].toString()) ?? 0;

//         if (currentId > existingId) {
//           // Jika lebih baru, data utama Card (Status & Vendor) diganti ke data baru ini
//           List oldAssignIds = List.from(groupedData[key]['grouped_assignment_ids'] ?? []);
//           List oldShipIds = List.from(groupedData[key]['grouped_shipping_ids'] ?? []);
//           List existingDOs = List.from(groupedData[key]['request']['delivery_order'] ?? []);

//           groupedData[key] = Map<String, dynamic>.from(item); // OVERWRITE
          
//           if (!oldAssignIds.contains(item['id_assignment'])) oldAssignIds.add(item['id_assignment']);
//           if (!oldShipIds.contains(req['shipping_id'])) oldShipIds.add(req['shipping_id']);
          
//           groupedData[key]['grouped_assignment_ids'] = oldAssignIds;
//           groupedData[key]['grouped_shipping_ids'] = oldShipIds;
//           groupedData[key]['history_logs'] = existingLogs;

//           // C. Merging Delivery Orders (Mencegah duplikasi item barang)
//           List newDOs = req['delivery_order'] ?? [];
//           for (var ndo in newDOs) {
//             ndo['rdd_origin'] = req['rdd'];
//             ndo['parent_so'] = req['so'];
//             ndo['parent_shipping_id'] = req['shipping_id'];

//             bool isDuplicate = existingDOs.any((existing) =>
//                 existing['do_number'] == ndo['do_number'] &&
//                 existing['parent_shipping_id'] == req['shipping_id']);

//             if (!isDuplicate) existingDOs.add(ndo);
//           }
//           groupedData[key]['request']['delivery_order'] = existingDOs;
//         } else {
//           // Jika data ini data lama, cukup update ID dan Log saja tanpa menimpa data utama Card
//           if (!groupedData[key]['grouped_assignment_ids'].contains(item['id_assignment'])) {
//             groupedData[key]['grouped_assignment_ids'].add(item['id_assignment']);
//           }
//           groupedData[key]['history_logs'] = existingLogs;
//         }
//       }
//     }
//     setState(() {
//       _planningList = groupedData.values.toList();
//       _isLoading = false;
//     });
    
//     _filterDataBySearch();
//   } catch (e) {
//     setState(() => _isLoading = false);
//     debugPrint("Error Fetch Planning: $e");
//   }
// }
Future<void> _fetchPlanningData({bool showGlobalLoading = false}) async {
    try {
      if (showGlobalLoading) {
        setState(() => _isLoading = true);
      }

      // 1. Update assignment yang expired menjadi 'no response' (Timeout 2 Jam)
      final expiredAssignments = await supabase
          .from('shipping_assignments')
          .update({
            'status_assignment': 'no response',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('status_assignment', 'offered')
          .lt('assigned_at', DateTime.now().subtract(const Duration(hours: 2)).toIso8601String())
          .select('shipping_id');

      if (expiredAssignments != null && (expiredAssignments as List).isNotEmpty) {
        List<int> expiredShippingIds = List<int>.from(expiredAssignments.map((e) => e['shipping_id']));
        await supabase
            .from('shipping_request')
            .update({'status': 'waiting assign vendor delivery'})
            .inFilter('shipping_id', expiredShippingIds);
      }

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final response = await supabase
          .from('shipping_assignments')
          .select('''
            *,
            master_vendor:nik (vendor_name), 
            vendor_transportasi:id_vendor_details (qcf, city, area, type_unit),
            loading:loading (loading_at, loading_by),
            request:shipping_id (
              shipping_id, so, rdd, status, stuffing_date, group_id, storage_location, is_dedicated,
              warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
              delivery_order (
                do_number,
                customer (customer_id, customer_name),
                do_details (
                  qty,
                  material:material_id (material_id, material_name, net_weight)
                )
              )
            )
          ''')
          .eq('request.stuffing_date', formattedDate)
          .order('jam_booking', ascending: true);

      if (response == null || (response as List).isEmpty) {
        setState(() {
          _planningList = [];
          _filteredPlanningList = [];
          _isLoading = false;
        });
        return;
      }

      // --- PROSES GROUPING MANUAL ---
      Map<String, dynamic> groupedData = {};

      for (var item in response) {
        final req = item['request'];
        if (req == null) continue;

        String key = req['group_id'] != null 
            ? "GROUP_${req['group_id']}" 
            : "SINGLE_${req['shipping_id']}";

        String currentStatus = item['status_assignment']?.toString().toLowerCase() ?? "";
        String currentVendorName = item['master_vendor']?['vendor_name'] ?? 'Unknown Vendor';
        //String currentReason = item['reason_rejected'] ?? 'Tanpa Alasan';

// --- LOGIKA PILIH KOLOM REASON DINAMIS ---
        String currentReason = 'Tanpa Alasan';
        if (currentStatus.contains('rejected')) {
          currentReason = item['reason_rejected'] ?? 'Tanpa Alasan Rejected';
        } else if (currentStatus.contains('cancel booking')) {
          currentReason = item['cancelled_reason'] ?? 'Tanpa Alasan Cancel';
        } else {
          currentReason = item['catatan'] ?? 'Tanpa Alasan';
        }

        if (!groupedData.containsKey(key)) {
          groupedData[key] = Map<String, dynamic>.from(item);
          groupedData[key]['grouped_assignment_ids'] = [item['id_assignment']];
          groupedData[key]['grouped_shipping_ids'] = [req['shipping_id']];
          groupedData[key]['history_logs'] = <Map<String, dynamic>>[]; 

          if (['rejected', 'no response', 'cancel booking', 'rejected unit'].contains(currentStatus)) {
            groupedData[key]['history_logs'].add({
              'status': currentStatus,
              'vendor': currentVendorName,
              'reason': currentReason,
            });
          }

          List currentDOs = List.from(groupedData[key]['request']['delivery_order'] ?? []);
          for (var d in currentDOs) {
            d['rdd_origin'] = req['rdd'];
            d['parent_so'] = req['so'];
            d['parent_shipping_id'] = req['shipping_id'];
          }
          groupedData[key]['request']['delivery_order'] = currentDOs;
        } else {
          List<Map<String, dynamic>> existingLogs = List<Map<String, dynamic>>.from(groupedData[key]['history_logs'] ?? []);
          bool isAlreadyLogged = existingLogs.any((log) => 
              log['vendor'] == currentVendorName && 
              log['status'] == currentStatus &&
              log['reason'] == currentReason);

          if (!isAlreadyLogged && ['rejected', 'no response', 'cancel booking', 'rejected unit'].contains(currentStatus)) {
            existingLogs.add({
              'status': currentStatus,
              'vendor': currentVendorName,
              'reason': currentReason,
            });
          }

          int existingId = int.tryParse(groupedData[key]['id_assignment'].toString()) ?? 0;
          int currentId = int.tryParse(item['id_assignment'].toString()) ?? 0;

          if (currentId > existingId) {
            List oldAssignIds = List.from(groupedData[key]['grouped_assignment_ids'] ?? []);
            List oldShipIds = List.from(groupedData[key]['grouped_shipping_ids'] ?? []);
            List existingDOs = List.from(groupedData[key]['request']['delivery_order'] ?? []);

            groupedData[key] = Map<String, dynamic>.from(item); 
            
            if (!oldAssignIds.contains(item['id_assignment'])) oldAssignIds.add(item['id_assignment']);
            if (!oldShipIds.contains(req['shipping_id'])) oldShipIds.add(req['shipping_id']);
            
            groupedData[key]['grouped_assignment_ids'] = oldAssignIds;
            groupedData[key]['grouped_shipping_ids'] = oldShipIds;
            groupedData[key]['history_logs'] = existingLogs;

            List newDOs = req['delivery_order'] ?? [];
            for (var ndo in newDOs) {
              ndo['rdd_origin'] = req['rdd'];
              ndo['parent_so'] = req['so'];
              ndo['parent_shipping_id'] = req['shipping_id'];

              bool isDuplicate = existingDOs.any((existing) =>
                  existing['do_number'] == ndo['do_number'] &&
                  existing['parent_shipping_id'] == req['shipping_id']);

              if (!isDuplicate) existingDOs.add(ndo);
            }
            groupedData[key]['request']['delivery_order'] = existingDOs;
          } else {
            if (!groupedData[key]['grouped_assignment_ids'].contains(item['id_assignment'])) {
              groupedData[key]['grouped_assignment_ids'].add(item['id_assignment']);
            }
            groupedData[key]['history_logs'] = existingLogs;
          }
        }
      }

      setState(() {
        _planningList = groupedData.values.toList();
        _isLoading = false;
      });
      
      _filterDataBySearch();
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error Fetch Planning: $e");
    }
  }


  void _filterDataBySearch() {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredPlanningList = List.from(_planningList);
      });
      return;
    }

    setState(() {
      _filteredPlanningList = _planningList.where((item) {
        // Ambil data Vendor
        final vendor = item['master_vendor'] ?? {};
        final String vendorName = (vendor['vendor_name'] ?? '').toString().toLowerCase();
        final String nikVendor = (item['nik'] ?? '').toString().toLowerCase();

        // Ambil list DO dari request
        final request = item['request'] ?? {};
        final List dos = request['delivery_order'] as List? ?? [];
        
        // Cek apakah ada salah satu nomor DO yang cocok
        bool matchDO = dos.any((doItem) {
          final String doNumber = (doItem['do_number'] ?? '').toString().toLowerCase();
          return doNumber.contains(query);
        });

        // Return true jika salah satu kondisi terpenuhi
        return matchDO || vendorName.contains(query) || nikVendor.contains(query);
      }).toList();
    });
  }
// Mendapatkan warna background status secara dinamis berdasarkan kondisi real-time
 
  void _showSnackBar(String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
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
                  child: _filteredPlanningList.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredPlanningList.length,
                            itemBuilder: (context, index) =>
                                _buildPlanningCard(_filteredPlanningList[index]),
                        ),
                ),
        ),
      ],
    ),
  );
}


Widget _buildTopFilterBar() {
  bool isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                 DateFormat('yyyy-MM-dd').format(DateTime.now());

  return Container(
    padding: const EdgeInsets.all(12),
    color: Colors.white,
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Jika layar kecil (HP), gunakan susunan Vertikal (Column)
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: !isToday ? Colors.red.shade700 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: _selectSingleDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: !isToday ? Colors.white : Colors.black87),
                            const SizedBox(width: 12),
                            Text(
                              "STUFFING: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: !isToday ? Colors.white : Colors.black87),
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_drop_down, color: !isToday ? Colors.white : Colors.black87),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10), // Jarak antar filter di HP
              Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Cari DO, Vendor, NIK...",
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? InkWell(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          );
        }

        // Jika layar lebar (Laptop/Tablet), tetap gunakan Row (Horizontal)
        return Row(
          children: [
            Expanded(
              flex: 4,
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
                        Icon(Icons.calendar_today, size: 16, color: !isToday ? Colors.white : Colors.black87),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "STUFFING: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: !isToday ? Colors.white : Colors.black87),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: !isToday ? Colors.white : Colors.black87),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Cari DO, Vendor, NIK...",
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? InkWell(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
        );
      },
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


Widget _buildPlanningCard(Map<String, dynamic> item) {
  final Map<String, dynamic> request = item['request'] ?? {};
  final vendor = item['master_vendor'] ?? {};
//final Map<String, dynamic> requestData = item['request'] ?? {};
final String requestStatus = request['status']?.toString().toLowerCase() ?? "";
// --- AMBIL DATA DARI TABEL LOADING HASIL JOIN ---
  // Jika hasil query berupa List (karena target relasi), ambil indeks pertama [0]
  // Jika berupa Map langsung, gunakan item['loading']
  final loadingData = item['loading'] is List 
      ? (item['loading'] as List).isNotEmpty ? item['loading'][0] : {}
      : item['loading'] ?? {};

  if (request.isEmpty) return const SizedBox.shrink();
  
  final List dos = request['delivery_order'] as List? ?? [];
  final bool isGroup = request['group_id'] != null;
  final warehouse = request['warehouse'];
  
  String warehouseDisplay = warehouse != null 
      ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 
      : "-";
// Ambil status untuk logika tampilan kondisional
  final String status = item['status_assignment']?.toString().toLowerCase() ?? "";
  final String vendorName = vendor['vendor_name'] ?? 'Unknown Vendor';
  final String reasonrejected = item['reason_rejected'] ?? 'Unknown Reason';
    final String vendorNik = item['nik'] ?? '-';

// --- LOGIKA KONDISIONAL MENGOSONGKAN NAMA VENDOR ---
  // Jika status bermasalah, kosongkan nama vendor (ditampilkan "-")
  // final String vendorName = (status == 'rejected' || status == 'no response' || status == 'cancel booking')
  //     ? "-" 
  //     : (vendor['vendor_name'] ?? 'Unknown Vendor');
      
  // final String vendorNik = (status == 'rejected' || status == 'no response' || status == 'cancel booking')
  //     ? "-" 
  //     : (item['nik'] ?? '-');

// --- LOGIKA MENENTUKAN WARNA CARD ---
  Color getCardColor() {
    // List status yang memicu warna merah
    const redStatuses = ['offered', 'no response', 'rejected', 'cancel booking'];
    
    if (redStatuses.contains(status)) {
      return Colors.red.shade600; // Merah muda/soft red agar teks di atasnya tetap terbaca
    } else if (isGroup) {
      return Colors.red; // Warna dasar untuk group do (merah muda/purple soft)
    }
    return isGroup ? Colors.purple.shade700 : Colors.blue.shade800; // Warna default jika tidak memenuhi kondisi di atas
  }

 Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted': return Colors.blue.shade800;
      case 'check in': return Colors.orange;
      case 'kelayakan unit': return Colors.orange;
      case 'loading': return Colors.orange;
      case 'weighbridge': return Colors.orange;
      case 'keluar': return Colors.orange;
      case 'no response': return Colors.grey.shade700;
      case 'rejected':return Colors.red.shade600;
      case 'rejected unit': return Colors.red.shade600;
      case 'cancel booking': return Colors.red.shade600;
      case 'completed': return Colors.green.shade500;
      default: return Colors.blueGrey;
    }
  }
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
    //clipBehavior: Clip.antiAlias, // Memastikan sudut container dalam ikut melengkung
    child: Column(
      children: [
        // Header (Jam & Label) - PERBAIKAN: Menggunakan Wrap agar tidak tabrakan di layar kecil
        Container(
           width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Wrap(
    spacing: 12, // Jarak horizontal antar elemen jika sejajar
    runSpacing: 8, // Jarak vertikal otomatis jika teks melipat ke bawah
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_filled, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible( // Flexible memastikan teks menyesuaikan ruang yang ada
              child: Text(
                "CHECK-IN: ${_getCheckInTime(item['jam_booking'] ?? "-")} | LOADING: ${item['jam_booking'] ?? "-"}",
                overflow: TextOverflow.ellipsis, // Jika terlalu panjang, akan jadi titik-titik (...)
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 14, // Ukuran sedikit diperkecil agar pas
                ),
              ),
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
                   child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status == 'rejected' || status == 'no response' || status == 'cancel booking'
                ? "Belum Ada Vendor"
                : "${item['nik']} - ${vendor['vendor_name'] ?? 'Unknown Vendor'}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
                    // --- TAMBAHKAN DETAIL VENDOR TRANSPORTASI DI SINI ---
          if (item['vendor_transportasi'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap( // Gunakan Wrap agar rapi saat dibuka di HP
                spacing: 8,
                runSpacing: 2,
                children: [
                  _miniVendorDetail("QCF: ${item['vendor_transportasi']['qcf'] ?? '-'}"),
                  _miniVendorDetail("City: ${item['vendor_transportasi']['city'] ?? '-'}"),
                  _miniVendorDetail("Area: ${item['vendor_transportasi']['area'] ?? '-'}"),
                  _miniVendorDetail("Unit: ${item['vendor_transportasi']['type_unit'] ?? '-'}"),
                ],
              ),
            ),
                           
        ],
                   ),
              ),
      
                  
                  _infoStatus("STATUS",status.toUpperCase()),
                  //_infoBox("CHECK-IN AT", _formatDateTime(item['checkIn_at'])),
                ],
              ),
    
              const SizedBox(height: 14),
              // --- TRACKING BOX UNTUK CONDITIONAL STATUS (No Response, Rejected, Rejected Unit) ---
               // if (status == 'no response' || status == 'rejected' || status == 'rejected unit' || status == 'cancel booking')
                 if (['no response', 'rejected', 'rejected unit', 'cancel booking'].contains(status) || 
    (item['history_logs'] != null && (item['history_logs'] as List).isNotEmpty))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16, top: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.report_problem, color: Colors.red.shade900, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "KETERANGAN", 
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade900)
                              ),
                              const SizedBox(height: 2),
                              
  //                    Text(
  // () {
  //   if (status == 'no response') {
  //     return "Vendor ($vendorName) tidak merespon penugasan hingga batas waktu.";
  //   } 
    
  //   else if (status == 'rejected') {
  //     // --- PENGECEKAN KONDISI BERDASARKAN STATUS SHIPPING REQUEST ---
  //     if (requestStatus == 'waiting assign vendor delivery') {
  //       return "Penugasan ditolak oleh Vendor: $vendorName karena $reasonrejected. - Menunggu assignment vendor baru.";
  //     } else if (requestStatus == 'waiting vendor approval') {
  //       return "Penugasan ditolak oleh Vendor: $vendorName karena $reasonrejected. - Menunggu jawaban vendor baru.";
  //     } else {
  //       return "Penugasan ditolak oleh Vendor: $vendorName karena $reasonrejected.";
  //     }
  //   } 
    
  //   else if (status == 'cancel booking') {
  //     if (requestStatus == 'waiting assign vendor delivery') {
  //       return "Booking dibatalkan oleh Vendor ($vendorName) karena $reasonrejected. - Menunggu assignment vendor baru.";
  //     } else if (requestStatus == 'waiting vendor approval') {
  //       return "Booking dibatalkan oleh Vendor ($vendorName) karena $reasonrejected. - Menunggu jawaban vendor baru.";
  //     } else {
  //       return "Booking dibatalkan oleh Vendor ($vendorName) karena $reasonrejected.";
  //     }
  //   } 
    
  //   else if (status == 'rejected unit') {
  //     return "Unit Feasibility Check ditolak untuk Vendor: $vendorName.";
  //   } 
    
  //   else {
  //     return "Unit Ditolak saat Check In Kelayakan Unit";
  //   }
  // }(),
  //                               style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade900),
  //                             ),
  //                             // Text(
  //                             //   status == 'no response' 
  //                             //     ? "Vendor ($vendorName) tidak merespon penugasan hingga batas waktu."
  //                             //     : status == 'rejected'
  //                             //     ? "Penugasan ditolak oleh Vendor: $vendorName karena $reasonrejected. - Menunggu assignment vendor baru."
  //                             //     : status == 'rejected unit'
  //                             //     ? "Unit Feasibility Check ditolak untuk Vendor: $vendorName."
  //                             //     : "Booking dibatalkan oleh Vendor ($vendorName) karena $reasonrejected.",
  //                             //   style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade900),
  //                             // ),
  //                           ],
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  // 1. TAMPILKAN LOG RIWAYAT MASA LALU (JIKA ADA VENDOR SEBELUMNYA YANG GAGAL)
              if (item['history_logs'] != null)
                ...(item['history_logs'] as List).map((log) {
                  String hStatus = log['status'] ?? '';
                  String hVendor = log['vendor'] ?? '';
                  String hReason = log['reason'] ?? '';
                  
                  String msg = "";
                  if (hStatus == 'no response') {
                    msg = "Vendor ($hVendor) tidak merespon penugasan hingga batas waktu.";
                  } else if (hStatus == 'rejected') {
                    msg = "Penugasan ditolak oleh Vendor $hVendor karena $hReason.";
                  } else if (hStatus == 'cancel booking') {
                    //msg = "Booking dibatalkan oleh Vendor ($hVendor) karena $hReason.";
                    String r = item['cancelled_reason'] ?? log['reason'] ?? 'Tanpa alasan';
  String by = item['cancelled_by'] ?? 'System';
  msg = "Booking dibatalkan oleh $by karena $r.";
                  } else if (hStatus == 'rejected unit') {
                    msg = "Unit Feasibility Check ditolak untuk Vendor $hVendor.";
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      "• $msg",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.red.shade900),
                    ),
                  );
                }).toList(),

              // 2. TAMPILKAN KONDISI STATUS AKTIF SAAT INI (JIKA CARD SEDANG BERSTATUS MERAH)
              if (['no response', 'rejected', 'rejected unit', 'cancel booking'].contains(status))
                Text(
                  () {
                    if (status == 'no response') {
                       if (requestStatus == 'waiting assign vendor delivery') {
                        return "Status Saat Ini: Menunggu assignment vendor baru.";
                      } else if (requestStatus == 'waiting vendor approval') {
                        return "Status Saat Ini: Menunggu jawaban vendor baru.";
                      } else {
                        return "Status Saat Ini: Penugasan ditolak oleh Vendor $vendorName karena $reasonrejected.";
                      }
                    } 
                    else if (status == 'rejected') {
                      if (requestStatus == 'waiting assign vendor delivery') {
                        return "Status Saat Ini: Menunggu assignment vendor baru.";
                      } else if (requestStatus == 'waiting vendor approval') {
                        return "Status Saat Ini: Menunggu jawaban vendor baru.";
                      } else {
                        return "Status Saat Ini: Penugasan ditolak oleh Vendor: $vendorName karena $reasonrejected.";
                      }
                    } 
                    else if (status == 'cancel booking') {
                      if (requestStatus == 'waiting assign vendor delivery') {
                        return "Status Saat Ini: Menunggu assignment vendor baru.";
                      } else if (requestStatus == 'waiting vendor approval') {
                        return "Status Saat Ini: Menunggu jawaban vendor baru.";
                      } else {
                        return "Status Saat Ini: Booking dibatalkan oleh Vendor ($vendorName) karena $reasonrejected.";
                      }
                    } 
                    else if (status == 'rejected unit') {
                      return "Status Saat Ini: Unit Feasibility Check ditolak untuk Vendor: $vendorName.";
                    } 
                    else {
                      return "Status Saat Ini: Unit Ditolak saat Check In Kelayakan Unit";
                    }
                  }(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                ),
            ],
          ),
        ),
      ],
    ),
  ),
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(10),
//                 margin: const EdgeInsets.only(bottom: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.shade50,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.orange.shade200),
//                 ),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, size: 14, color: Colors.orange),
//                         const SizedBox(width: 6),
//                         Text(
//                           "Check-in At: ${_formatDateTime(item['checkIn_at'])}",
//                           style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
//                         ),
// // Tampilkan info jika dia check-in terlambat
//                if (item['latecheckIn_reason'] != null) ...[
//                           const SizedBox(width: 12),
//                           const Text("|", style: TextStyle(color: Colors.orange, fontSize: 11)),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Text(
//                               "Terlambat: ${item['latecheckIn_reason']}",
//                               style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                     const Padding(
//         padding: EdgeInsets.symmetric(vertical: 4),
//         child: Divider(height: 1, color: Colors.orange),
//       ),

//       // BARIS LOADING & CHECKER (BARU)
//       Row(
//         children: [
//           const Icon(Icons.hourglass_bottom, size: 14, color: Colors.orange),
//           const SizedBox(width: 6),
//           Text(
//             "Loading At: ${_formatDateTime(item['loading_at'])}",
//             style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
//           ),
//           const SizedBox(width: 12),
//           const Text("|", style: TextStyle(color: Colors.orange, fontSize: 11)),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               "Checker: ${item['loading_by'] ?? '-'}", // Sesuaikan field 'loading_by' dengan DB Anda
//               style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
//               overflow: TextOverflow.ellipsis,
//            ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
                 // --- LOGIKA KONDISIONAL CHECK-IN & LOADING ---
              // Hanya muncul jika status BUKAN 'accepted' (berarti sudah check-in/loading/dst)
              //if (status != 'accepted') 
              if (status != 'accepted' && status != 'offered' && status != 'no response' && status != 'rejected'  && status != 'cancel booking')
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
                      // INFO CHECK IN: Selalu muncul jika status bukan accepted
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            "Check-in At: ${_formatDateTime(item['checkIn_at'])}",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                          ),
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

                      // INFO LOADING: Hanya muncul jika status sudah 'loading', 'weighbridge', atau 'keluar'
                      if (status == 'loading' || status == 'weighbridge' || status == 'keluar') ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Divider(height: 1, color: Colors.orange),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.hourglass_bottom, size: 14, color: Colors.orange),
                            const SizedBox(width: 6),
                            Text(
                              "Loading At: ${_formatDateTime(loadingData['loading_at'])}",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                            ),
                            const SizedBox(width: 12),
                            const Text("|", style: TextStyle(color: Colors.orange, fontSize: 11)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Checker: ${loadingData['loading_by'] ?? '-'}",
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              
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
                                Text( "SO: ${doItem['parent_so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                    // --- TOMBOL EDIT JAM UNTUK ADMIN ---
    // Hanya tampilkan jika status belum masuk ke gerbang (check-in)
    // if (status == 'accepted')
    //   SizedBox(
    //     width: double.infinity,
    //     child: ElevatedButton.icon(
    //       onPressed: () {
    //         // Membuka tab baru untuk edit jam
    //         DynamicTabPage.of(context)?.openTab(
    //           "Edit Jam Ship #${request['shipping_id']}",
    //           ScheduleSelectionPage(
    //             assignmentId: item['id_assignment'],
    //             shippingId: request['shipping_id'],
    //             oldTime: item['jam_booking'],
    //             // Admin mengedit, nik dikirim dari data item
    //             vendorNik: item['nik'], 
    //             onSuccess: () {
    //               _fetchPlanningData(); // Refresh list setelah berhasil
    //               _showSnackBar("Jadwal berhasil diperbarui", Colors.green);
    //             },
    //           ),
    //         );
    //       },
    //       icon: const Icon(Icons.edit_calendar, size: 18, color: Colors.white),
    //       label: const Text("EDIT JAM BOOKING", 
    //           style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    //       style: ElevatedButton.styleFrom(
    //         backgroundColor: Colors.blue.shade700,
    //         padding: const EdgeInsets.symmetric(vertical: 12),
    //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    //       ),
    //     ),
    //   ),
      
    // const SizedBox(height: 16),
    // --- TOMBOL AKSI ADMIN (Hanya muncul jika status 'accepted') ---
             // if (status == 'accepted') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmCancelBooking(item),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text("BATALKAN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                     if (status == 'accepted') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _openEditTab(item),
                        icon: const Icon(Icons.edit_calendar, color: Colors.white, size: 18),
                        label: const Text("EDIT JAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                      ],  
                  ],  
                ), 

              const SizedBox(height: 16),
                
//      
      ],
  ),
        ),
      ],
    ),
  );
   
          
}
// 1. Fungsi Navigasi ke Halaman Edit Jam
void _openEditTab(Map<String, dynamic> item) {
  final request = item['request'] ?? {};
  
  //final List<int> allAssignmentIds = List<int>.from(item['grouped_assignment_ids'] ?? [item['id_assignment']]);
   final int? groupId = request['group_id'];
          final int shipId = request['shipping_id'];
          String tabTitle;

          if (groupId != null) {
            tabTitle = "Reschedule Grup #$groupId";
          } else {
            tabTitle = "Reschedule Shipping #$shipId";
          }
  DynamicTabPage.of(context)?.openTab(
    tabTitle,
    ScheduleSelectionPage(
      assignmentId:item['id_assignment'],
      shippingId: request['shipping_id'],
      oldTime: item['jam_booking'],
      vendorNik: item['nik'],
      onSuccess: () {
        _fetchPlanningData(); // Refresh list utama
        _showSnackBar("Jadwal Berhasil Diperbarui", Colors.green);
      }, 
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

String _getCheckInTime(String? timeSlot) {
  // 1. Cek keamanan awal: jika null, kosong, atau tidak mengandung pemisah " - "
  if (timeSlot == null || timeSlot.isEmpty || timeSlot == "-" || !timeSlot.contains(" - ")) {
    return "00:00 - 00:00";
  }

  try {
    // 2. Pecah string (misal: "19:00 - 21:00")
    List<String> parts = timeSlot.split(" - ");
    if (parts.length < 2) return "00:00 - 00:00";

    String startTimeStr = parts[0]; // "19:00"
    String endTimeStr = parts[1];   // "21:00"

    // 3. Ambil jam (handle jika split ":" gagal)
    List<String> startSplit = startTimeStr.split(":");
    List<String> endSplit = endTimeStr.split(":");
    
    if (startSplit.isEmpty || endSplit.isEmpty) return "00:00 - 00:00";

    int startHour = int.parse(startSplit[0]);
    int endHour = int.parse(endSplit[0]);

    // 4. Kurangi 2 jam (dengan logika putaran 24 jam agar tidak negatif)
    // Misal: jam 1 pagi dikurang 2 jam menjadi jam 23 malam
    int newStart = (startHour - 2) < 0 ? (24 + (startHour - 2)) : (startHour - 2);
    int newEnd = (endHour - 2) < 0 ? (24 + (endHour - 2)) : (endHour - 2);

    // 5. Kembalikan format HH:00
    String checkInStart = "${newStart.toString().padLeft(2, '0')}:00";
    String checkInEnd = "${newEnd.toString().padLeft(2, '0')}:00";

    return "$checkInStart - $checkInEnd";
  } catch (e) {
    // Jika ada eror parsing di tengah jalan, tampilkan default alih-alih crash
    debugPrint("Error kalkulasi jam check-in: $e");
    return "00:00 - 00:00";
  }
}

// Future<void> _saveReschedule(String newTime) async {
//   try {
//     final List<int> idsToUpdate = widget.assignmentIds; // List ID dari parameter tadi
//     final String changedBy = supabase.auth.currentUser?.email ?? 'admin';

//     // 1. Update Jam di penugasan (Bulk Update)
//     await supabase.from('shipping_assignments').update({
//       'jam_booking': newTime,
//       'responded_at': DateTime.now().toIso8601String(),
//     }).inFilter('id_assignment', idsToUpdate);

//     // 2. Simpan ke History (Satu per satu atau loop)
//     final List<Map<String, dynamic>> historyData = idsToUpdate.map((id) => {
//       'id_assignment': id,
//       'jam_lama': widget.oldTime,
//       'jam_baru': newTime,
//       'changed_by': changedBy,
//       'reason_reschedule': 'Reschedule Grup by Admin',
//     }).toList();

//     await supabase.from('booking_history').insert(historyData);

//     widget.onSuccess();
//     Navigator.pop(context);
//   } catch (e) {
//     _showSnackBar("Gagal Reschedule Grup: $e", Colors.red);
//   }
// }
// 2. Fungsi Konfirmasi Pembatalan oleh Admin
void _confirmCancelBooking(Map<String, dynamic> item) {
  _tempCancelReason = null;
  _otherReasonController.clear();
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
builder: (context, setStateDialog) => AlertDialog(
        title: const Text("Alasan Pembatalan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._rescheduleReasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: const TextStyle(fontSize: 13)),
                value: reason,
                groupValue: _tempCancelReason,
                activeColor: Colors.red,
                onChanged: (val) => setStateDialog(() => _tempCancelReason = val),
              )).toList(),
              if (_tempCancelReason == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: _otherReasonController,
                    decoration: InputDecoration(
                      hintText: "Tulis alasan pembatalan...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _tempCancelReason == null ? null : () async {
              String finalReason = _tempCancelReason == 'Other' 
                  ? _otherReasonController.text.trim() 
                  : _tempCancelReason!;
              
              if (finalReason.isEmpty) {
                _showSnackBar("Alasan tidak boleh kosong!", Colors.orange);
                return;
              }

              Navigator.pop(context); // Tutup dialog alasan
              await _executeCancelBooking(item, finalReason);
            },
            child: const Text("KONFIRMASI BATAL", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

// 3. Logika Eksekusi Pembatalan ke Database
Future<void> _executeCancelBooking(Map<String, dynamic> item,String reason) async {
  try {
    setState(() => _isLoading = true);
    
    // Ambil Nama dari Profile (cancelled_by)
    final currentUser = supabase.auth.currentUser;
    final profileRes = await supabase
        .from('profiles')
        .select('name')
        .eq('id', currentUser?.id ?? '')
        .maybeSingle();

        final String activeUserName = profileRes?['name'] ?? currentUser?.email ?? 'Admin';
    // Ambil semua ID jika ini adalah grup
    //final List<int> assignmentIds = List<int>.from(item['grouped_assignment_ids'] ?? [item['id_assignment']]);
    final List<int> shippingIds = List<int>.from(item['grouped_shipping_ids'] ?? [item['request']['shipping_id']]);
    List<int> assignmentIds = [];
    // 2. PROTEKSI GANDA: Cari ID assignment yang benar-benar aktif ('offered' / 'accepted') di database
    final req = item['request'];
    if (req != null && req['group_id'] != null) {
      final assignmentRes = await supabase
          .from('shipping_assignments')
          .select('id_assignment')
          .inFilter('shipping_id', shippingIds)
          .inFilter('status_assignment', ['offered', 'accepted']); // Hanya sasar yang aktif!

      assignmentIds = (assignmentRes as List)
          .map((e) => e['id_assignment'] as int)
          .toList();
          
      // Antisipasi jika kosong, masukkan ID utama dari card yang ditekan
      if (assignmentIds.isEmpty && item['id_assignment'] != null) {
        assignmentIds.add(int.parse(item['id_assignment'].toString()));
      }
    } else {
      // Jika Single Shipment, langsung pakai ID utama card
      assignmentIds = [int.parse(item['id_assignment'].toString())];
    }

    // Jaga-jaga jika assignmentIds kosong agar tidak melempar error query kosong
    if (assignmentIds.isEmpty) {
      _showSnackBar("Tidak ada penugasan aktif yang bisa dibatalkan", Colors.orange);
      return;
    }
    // Update Assignment: Hapus jam dan ubah status ke cancel
    await supabase.from('shipping_assignments').update({
      'status_assignment': 'cancel booking',
      'jam_booking': null,
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancelled_by': activeUserName, // Simpan Nama Pembatal
      'cancelled_reason': reason,    // Simpan Alasan Pembatalan
    }).inFilter('id_assignment', assignmentIds);

    // Update Request: Kembalikan ke tahap pemilihan vendor
    await supabase.from('shipping_request').update({
      'status': 'waiting assign vendor delivery',
    }).inFilter('shipping_id', shippingIds);

    _showSnackBar("Booking berhasil dibatalkan", Colors.orange);
    _fetchPlanningData();
  } catch (e) {
    _showSnackBar("Gagal membatalkan: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
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

Widget _infoBox(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  );
} 
Widget _infoStatus(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      Text(value, style: const TextStyle(fontSize: 12, color: Colors.red,fontWeight: FontWeight.bold)),
    ],
  );
} 
  Widget _infoColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }


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
          const Text("Tidak ada antrian planning saat ini", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}