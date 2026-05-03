import 'package:flutter/material.dart';
import 'package:project_app/admin/display/assignVendor_page.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class VendorRequestPage extends StatefulWidget {
  const VendorRequestPage({super.key});

  @override
  State<VendorRequestPage> createState() => _VendorRequestPageState();
}

class _VendorRequestPageState extends State<VendorRequestPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _assignmentSubscription;
  bool _isLoading = false;
  List<Map<String, dynamic>> _dataList = [];

  // 3. Inisialisasi Plugin Notifikasi
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Filter States
  String _selectedFilterLoc = "SEMUA";
  DateTimeRange? _selectedDateRange;
String _dateFilterType = "RDD"; // Default filter ke RDD
List<Map<String, dynamic>> _warehouseList = [];

  @override
  void initState() {
    super.initState();
    _fetchWarehouse();
    _initNotification();
    _fetchVendorTargetData();
    _setupRealtime();
  }

Future<void> _fetchWarehouse() async {
  try {
    final response = await supabase
        .from('warehouse')
        .select('warehouse_id, warehouse_name, lokasi')
        .inFilter('warehouse_id', [1, 2, 3, 6]) // Membatasi pilihan gudang
        .order('lokasi', ascending: true);

    setState(() {
      _warehouseList = List<Map<String, dynamic>>.from(response);
    });
  } catch (e) {
    debugPrint("Error Fetch Warehouse: $e");
  }
}
// 4. Fungsi Inisialisasi Notifikasi
  void _initNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 5. Fungsi Menampilkan Notifikasi Pop-up
  Future<void> _showRejectNotification(String vendorName, int shipId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'reject_channel', 'Reject Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: Colors.red,
      playSound: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      shipId, // Menggunakan ID Shipping sebagai ID notifikasi
      '🚨 Order Ditolak Vendor!',
      'Vendor $vendorName menolak pesanan #$shipId. Segera cari vendor lain!',
      platformChannelSpecifics,
    );
  }

  void _setupRealtime() {
    // Kita memantau perubahan pada tabel shipping_request
    // Karena halaman ini memfilter status 'waiting vendor delivery request'
    _realtimeSubscription = supabase
        .from('shipping_request')
        .stream(primaryKey: ['shipping_id'])
        .listen((_) => _fetchVendorTargetData());
          // 6. Listener Realtime KHUSUS untuk Notifikasi Reject
    // Kita memantau tabel shipping_assignments untuk mendeteksi perubahan status ke 'rejected'
    _assignmentSubscription = supabase
        .from('shipping_assignments')
        .stream(primaryKey: ['id']) // Pastikan ada PK 'id' di tabel assignments
        .listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty) {
        final lastUpdate = data.last;
        if (lastUpdate['status_assignment'] == 'rejected') {
          // Ambil nama vendor atau ID untuk notifikasi
          // Catatan: Anda mungkin perlu query tambahan untuk nama vendor jika tidak ada di payload
          _showRejectNotification(
            "Transportasi", // Default name jika tidak ada di payload
            lastUpdate['shipping_id'] ?? 0,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel(); // WAJIB: mematikan stream saat pindah halaman
    _assignmentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchVendorTargetData() async {
    try {
      setState(() => _isLoading = true);

      var query = supabase.from('shipping_request').select('''
            *,
            so,
            warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order(
              do_number,
              customer(customer_id, customer_name),
              do_details(qty, material(material_id, material_name))
            ),
            shipping_assignments(
            status_assignment,
            responded_at,
            master_vendor(vendor_name)
          )
          ''').eq('status', 'waiting assign vendor delivery')
          //.eq('is_dedicated', 'dedicated') // Filter hanya yang DEDICATED
          .eq('shipping_assignments.status_assignment', 'rejected'); // Ambil yang pernah direject
// .filter('vendor_id', 'is', null);
      if (_selectedFilterLoc != "SEMUA") {
        query = query.eq('warehouse_id',int.parse(_selectedFilterLoc));
      }

      if (_selectedDateRange != null) {
        // Menentukan kolom mana yang difilter berdasarkan pilihan dropdown
      String dateColumn = _dateFilterType == "RDD" ? 'rdd' : 'stuffing_date';
        query = query
           .gte(dateColumn, _selectedDateRange!.start.toIso8601String())
          .lte(dateColumn, _selectedDateRange!.end.toIso8601String());
      }

      final response = await query.order('shipping_id', ascending: false);
      if (mounted) {
      setState(() {
      //   _dataList = _getGroupedDisplayData(List<Map<String, dynamic>>.from(response));
      //   _isLoading = false;
      // });
      // }
      // 1. Jalankan grouping data Anda seperti biasa
    List<Map<String, dynamic>> rawGrouped = _getGroupedDisplayData(List<Map<String, dynamic>>.from(response));

    // 2. Loop setiap Card (baik grup maupun single) untuk membersihkan duplikasi vendor
    for (var item in rawGrouped) {
      Map<String, Map<String, dynamic>> uniqueRejects = {};
      
      // Ambil data dari key 'reject_history' (sesuai alias di query .select)
      //final List rejects = item['shipping_assignments'] as List? ?? [];
      
      // Ambil ID yang ada di dalam grup ini (jika single, maka hanya contains dirinya sendiri)
      List<int> groupShipIds = item['group_id'] != null 
          ? List<int>.from(item['grouped_ids']) 
          : [item['shipping_id']];

          // 3. Cari di data asli (response) semua riwayat reject untuk ID-ID tersebut
      for (var originalRow in (response as List)) {
        if (groupShipIds.contains(originalRow['shipping_id'])) {
          final List rejects = originalRow['shipping_assignments'] as List? ?? [];

      for (var r in rejects) {
        if (r['status_assignment'] == 'rejected') {
          // Gunakan nama vendor sebagai KEY agar otomatis menimpa jika namanya sama (menjadi unik)
          String vName = r['master_vendor']?['vendor_name'] ?? "Unknown Vendor";
          uniqueRejects[vName] = r;
        }
      }
        }
      }
      // Simpan list yang sudah unik ke dalam key baru 'unique_reject_list'
      item['unique_reject_list'] = uniqueRejects.values.toList();
    }

// RE-SORTING setelah unique_reject_list terisi
  rawGrouped.sort((a, b) {
    bool aHasReject = (a['unique_reject_list'] as List? ?? []).isNotEmpty;
    bool bHasReject = (b['unique_reject_list'] as List? ?? []).isNotEmpty;
    if (aHasReject && !bHasReject) return -1;
    if (!aHasReject && bHasReject) return 1;
    return (b['shipping_id'] as int).compareTo(a['shipping_id'] as int);
  });

    _dataList = rawGrouped;
    _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
      setState(() => _isLoading = false);
      _showSnackBar("Error: $e", Colors.red);
      }
    }
  }

  List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
    Map<int, Map<String, dynamic>> groupedMap = {};
    List<Map<String, dynamic>> finalResult = [];

    for (var req in source) {
      if (req['group_id'] == null) {
        finalResult.add(Map<String, dynamic>.from(req));
      } else {
        int gId = req['group_id'];
        if (!groupedMap.containsKey(gId)) {
          groupedMap[gId] = Map<String, dynamic>.from(req);
          groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
        // Simpan SO induk ke dalam setiap DO di grup pertama
        if (groupedMap[gId]!['delivery_order'] != null) {
          for (var doItem in groupedMap[gId]!['delivery_order']) {
            doItem['parent_so'] = req['so']; 
          }
        }
      } else {
        groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
        
        // Ambil DO baru dan tempelkan nomor SO-nya
        List newDos = List.from(req['delivery_order'] ?? []);
        for (var ndo in newDos) {
          ndo['parent_so'] = req['so']; // Menandai SO asal untuk tiap DO
        }

        List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
        currentDos.addAll(newDos);
        groupedMap[gId]!['delivery_order'] = currentDos;
      }
    }
  }
    finalResult.addAll(groupedMap.values);
    //finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
    
    // --- PERBAIKAN LOGIKA SORTING DISINI ---
  finalResult.sort((a, b) {
    // 1. Cek apakah ada riwayat reject (menggunakan unique_reject_list yang sudah kita buat sebelumnya)
    // Catatan: Karena unique_reject_list diisi setelah grouping di _fetchVendorTargetData, 
    // pastikan sorting ini dilakukan SETELAH list unik tersebut terisi.
    
    bool aIsRejected = (a['unique_reject_list'] as List? ?? []).isNotEmpty;
    bool bIsRejected = (b['unique_reject_list'] as List? ?? []).isNotEmpty;

    // 2. Jika A direject dan B tidak, A naik ke atas
    if (aIsRejected && !bIsRejected) return -1;
    // 3. Jika B direject dan A tidak, B naik ke atas
    if (!aIsRejected && bIsRejected) return 1;

    // 4. Jika keduanya sama-sama direject atau sama-sama bersih, 
    // urutkan berdasarkan Shipping ID terbaru (descending)
    return (b['shipping_id'] as int).compareTo(a['shipping_id'] as int);
  });
    return finalResult;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      // appBar: AppBar(
      //   title: const Text("Permintaan Vendor Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      child: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _dataList.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _dataList.length,
                    itemBuilder: (context, index) => _buildVendorCard(_dataList[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // Widget _buildFilterBar() {
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: const BoxDecoration(color: Colors.white),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: DropdownButtonFormField<String>(
  //             value: _selectedFilterLoc,
  //             decoration: _filterInputDecoration("Lokasi Gudang"),
  //             items: ["SEMUA", "RUNGKUT", "TAMBAK LANGON"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
  //             onChanged: (val) {
  //               setState(() => _selectedFilterLoc = val!);
  //               _fetchVendorTargetData();
  //             },
  //           ),
  //         ),
  //         const SizedBox(width: 8),

  //         Expanded(
  //           child: InkWell(
  //             onTap: _pickDateRange,
  //             child: Container(
  //               padding: const EdgeInsets.all(10),
  //               decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
  //               child: Row(
  //                 children: [
  //                   const Icon(Icons.calendar_month, size: 16, color: Colors.red),
  //                   const SizedBox(width: 8),
  //                   Text(_selectedDateRange == null ? "Filter RDD" : DateFormat('dd/MM').format(_selectedDateRange!.start), style: const TextStyle(fontSize: 12)),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),
  //         IconButton(
  //           onPressed: () { 
  //             setState(() { _selectedFilterLoc = "SEMUA"; _selectedDateRange = null; }); 
  //             _fetchVendorTargetData(); 
  //           }, 
  //           icon: const Icon(Icons.refresh, color: Colors.red)
  //         )
  //       ],
  //     ),
  //   );
  // }

Widget _buildFilterBar() {
  bool isDateActive = _selectedDateRange != null;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 2,
          offset: const Offset(0, 2),
        )
      ],
    ),
    child: Row(
      children: [
        // 1. Dropdown Lokasi Gudang (Flex 2)
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedFilterLoc,
            decoration: _filterInputDecoration("Gudang"),
            style: const TextStyle(fontSize: 11, color: Colors.black),
            // items: ["SEMUA", "RUNGKUT", "TAMBAK LANGON"].map((e) => 
            //   DropdownMenuItem(value: e, child: Text(e))
            // ).toList(),
            items: [
      const DropdownMenuItem(value: "SEMUA", child: Text("SEMUA GUDANG")),
      ..._warehouseList.map((wh) {
        String display = "${wh['lokasi']} - ${wh['warehouse_name']}";
        return DropdownMenuItem(
          value: wh['warehouse_id'].toString(), // Value ID untuk filter ke DB
          child: Text(display, style: const TextStyle(fontSize: 10)),
        );
      }),
    ],
            onChanged: (val) {
              setState(() => _selectedFilterLoc = val!);
              _fetchVendorTargetData();
            },
          ),
        ),
        const SizedBox(width: 8),

        // 2. Dropdown Tipe Tanggal (Flex 2)
        
//         Expanded(
//           flex: 5,
//           child: DropdownButtonFormField<String>(
//             value: _dateFilterType,
//             decoration: _filterInputDecoration("Berdasarkan"),
//             style: const TextStyle(fontSize: 11, color: Colors.black),
//             items: ["RDD", "STUFFING"].map((e) => 
//               DropdownMenuItem(value: e, child: Text(e))
//             ).toList(),
//             onChanged: (val) {
//               setState(() => _dateFilterType = val!);
//               if (_selectedDateRange != null) _fetchVendorTargetData();
//             },
//           ),
//         ),
//         const SizedBox(width: 6),

//         // 3. Tombol Pilih Rentang Tanggal (Flex 3)
//         Expanded(
//           flex: 3,
//           child: InkWell(
//             onTap: _pickDateRange,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade400),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.calendar_month, size: 14, color: Colors.red),
//                   const SizedBox(width: 4),
//                   Flexible(
//                     child: Text(
//                       _selectedDateRange == null 
//                           ? "Pilih Tgl" 
//                           : "${DateFormat('dd/MM').format(_selectedDateRange!.start)}-${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
//                       style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),

//         // 4. Tombol Reset (Kecil)
//         IconButton(
//           constraints: const BoxConstraints(),
//           padding: const EdgeInsets.only(left: 4),
//           onPressed: () { 
//             setState(() { 
//               _selectedFilterLoc = "SEMUA"; 
//               _selectedDateRange = null; 
//               _dateFilterType = "RDD";
//             }); 
//             _fetchVendorTargetData(); 
//           }, 
//           icon: const Icon(Icons.refresh, color: Colors.red, size: 20)
//         )
//       ],
//     ),
//   );
// }

// 2. Filter Tanggal Unified (Mirip List DO)
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: isDateActive ? Colors.red.shade700 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Bagian Dropdown Tipe (RDD/Stuffing)
                Container(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isDateActive ? Colors.white30 : Colors.grey.shade400,
                        width: 1,
                      ),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _dateFilterType,
                      isDense: true,
                      dropdownColor: isDateActive ? Colors.red.shade800 : Colors.white,
                      iconEnabledColor: isDateActive ? Colors.white : Colors.black87,
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: isDateActive ? Colors.white : Colors.black87,
                      ),
                      items: ["RDD", "STUFFING"].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _dateFilterType = val!);
                        if (isDateActive) _fetchVendorTargetData();
                      },
                    ),
                  ),
                ),
                // Bagian Pilih Tanggal
                Expanded(
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.date_range, 
                            size: 14, 
                            color: isDateActive ? Colors.white : Colors.black87
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedDateRange == null 
                                ? "Pilih Tgl" 
                                : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDateActive ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Tombol Refresh/Reset
        if (isDateActive || _selectedFilterLoc != "SEMUA")
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red, size: 20),
            onPressed: () {
              setState(() {
                _selectedFilterLoc = "SEMUA";
                _selectedDateRange = null;
                _dateFilterType = "RDD";
              });
              _fetchVendorTargetData();
            },
          ),
      ],
    ),
  );
}
  Widget _buildVendorCard(Map<String, dynamic> item) {
    final bool isGroup = item['group_id'] != null;
    final List dos = item['delivery_order'] ?? [];
    
    // Perbaikan akses detail (Menangani List dari inner join)
    // final List rawDetails = item['shipping_request_details'] ?? [];
    // final Map<String, dynamic> details = rawDetails.isNotEmpty ? rawDetails[0] : {};
//final List rejectHistory = item['shipping_assignments'] ?? [];
final List rejectHistory = item['unique_reject_list'] ?? [];
// 2. Ambil data warehouse dari hasil join
    final warehouse = item['warehouse'];
    final String warehouseDisplay = warehouse != null 
        ? "${warehouse['lokasi']} - ${warehouse['warehouse_name']}"
        : ("-");
    return Card(
      
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Group & Lokasi
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
                _buildBadge(warehouseDisplay, Colors.red.shade700),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Tanggal
                Row(
                  children: [
                    _infoText("📅 RDD:", _formatDate(item['rdd'])),
                    const SizedBox(width: 20),
                    _infoText("🚛 Stuffing:", _formatDate(item['stuffing_date'],)),
                     const SizedBox(width: 20),
//                       _infoText("🛠️ Status:", item['is_dedicated']?.toString().toUpperCase() ?? "-"),
const Divider(height: 40),
                  ],
                  
                ),
                // const SizedBox(height: 4),
                // _infoText("🛠️ Status:", item['is_dedicated']?.toString().toUpperCase() ?? "-"),
                // const Divider(height: 20),
// // --- BAGIAN RIWAYAT REJECT ---
//               if (rejectHistory.isNotEmpty) ...[
//                 const SizedBox(height: 12),
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: Colors.orange.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.orange.shade200),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade900),
//                           const SizedBox(width: 4),
//                           Text("Direject Oleh:", 
//                             style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
//                         ],
//                       ),
//                       const SizedBox(height: 4),
//                       // Loop vendor yang reject
//                       ...rejectHistory.map((rej) {
//                         String vendorName = rej['master_vendor']?['vendor_name'] ?? "Unknown Vendor";
//                         //String reason = rej['reason_rejected'] ?? "Tanpa alasan";
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 2),
//                           child: Text(
//                             "• $vendorName",
//                             style: const TextStyle(fontSize: 10, color: Colors.black87),
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 ),
//               ],
              
//               const Divider(height: 30),
                // List Table per DO
                ...dos.map((doItem) {
                  final List doDetails = doItem['do_details'] ?? [];
                  final String custName = doItem['customer']?['customer_name'] ?? "-";
                  final String custId = doItem['customer']?['customer_id']?.toString() ?? "-";

                  // return Container(
                  //   margin: const EdgeInsets.only(bottom: 12),
                  //   decoration: BoxDecoration(
                  //     border: Border.all(color: Colors.grey.shade200),
                  //     borderRadius: BorderRadius.circular(8),
                  //   ),
                  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[300]!), // Border abu tipis
    ),
    child: Column(
      children: [
        // HEADER BOX (DO - SO - CUSTOMER)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.pink.shade50, // Background abu sangat muda sesuai gambar
            borderRadius: const BorderRadius.only(
             
            ),
          ),
                    child: Row(
                      children: [
                        // Container(
                        //   padding: const EdgeInsets.all(8),
                        //   color: Colors.grey.shade50,
                        //   child: Row(
                        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //     children: [
                              Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                              const Spacer(),
                              Text(
                  "SO: ${doItem['parent_so'] ?? item['so'] ?? '-'}", // Pastikan key 'so_number' sesuai data Anda
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                              Text("${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.2), // No Mat
                            1: FlexColumnWidth(4),   // Nama Mat
                            2: FlexColumnWidth(1),   // Qty
                          },
                          children: doDetails.map((det) => TableRow(
                            children: [
                              _tablePadding(det['material']?['material_id']?.toString() ?? "-"),
                              _tablePadding(det['material']?['material_name'] ?? "-"),
                              _tablePadding(det['qty']?.toString() ?? "0", isBold: true, align: TextAlign.right),
                            ],
                          )).toList(),
                        ),]
                        ,
                  ),
                );
              }).toList(),
                        // --- BAGIAN RIWAYAT REJECT (Diletakkan di bawah material) ---
                        if (rejectHistory.isNotEmpty) ...[
                          const Divider(height: 1, thickness: 1),
                          Container(
                            padding: const EdgeInsets.all(10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade200,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade900),
                                    const SizedBox(width: 4),
                                    Text("Direject Oleh:", 
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ...rejectHistory.map((rej) {
                                  String vendorName = rej['master_vendor']?['vendor_name'] ?? "Unknown Vendor";
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      "• $vendorName",
                                      style: const TextStyle(fontSize: 10, color: Colors.black87),
                                    ),
                                  );
                                }).toList(),
                             ],
                  ),
                ),
              ],
            ],
          ),
        ),

          // Tombol Proses
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
               onPressed: () {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => AssignVendorPage(shippingId: item['shipping_id']),
    //     ),
    //   );
    // },
  //  final String shipId = item['shipping_id'].toString();
              
  //             DynamicTabPage.of(context)?.openTab(
  //               "Assign Vendor Shipping #$shipId", 
  //               AssignVendorPage(shippingId: item['shipping_id']),
  //             );
  //           },
  final groupId = item['group_id'];
  final shipId = item['shipping_id'];
  
  // 2. Tentukan Judul Tab secara dinamis
  String tabTitle;
  if (groupId != null) {
    tabTitle = "Assign Vendor Grup #$groupId";
  } else {
    tabTitle = "Assign Vendor Shipping #$shipId";
  }

  // 3. Panggil DynamicTab untuk membuka halaman di dalam bingkai
  DynamicTabPage.of(context)?.openTab(
    tabTitle, 
    AssignVendorPage(shippingId: shipId), // ID yang dikirim tetap shippingId utama
  );
},
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: Text(
                // isGroup ? "PROSES GRUP (${(item['grouped_ids'] as List).length} DATA)" : 
                "PROSES PERMINTAAN VENDOR",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // --- UI Helpers ---
  Widget _infoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: "$label "),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tablePadding(String text, {bool isBold = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color, width: 0.5)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _filterInputDecoration(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)));

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.done_all, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text("Semua data sudah diproses", style: TextStyle(color: Colors.grey))]));

  // // --- Logic ---
  // Future<void> _submitToVendor(Map<String, dynamic> item) async {
  //   final List ids = item['group_id'] != null ? item['grouped_ids'] : [item['shipping_id']];
  //   try {
  //     setState(() => _isLoading = true);
  //     await supabase.from('shipping_request').update({'status': 'waiting vendor assignment'}).inFilter('shipping_id', ids);
  //     final inserts = ids.map((id) => {'shipping_id': id, 'status': 'requested', 'id_profile': supabase.auth.currentUser?.id}).toList();
  //     await supabase.from('vendor_delivery_request').insert(inserts);
  //     _showSnackBar("Berhasil dikirim ke Vendor!", Colors.green);
  //     _fetchVendorTargetData();
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     _showSnackBar("Gagal: $e", Colors.red);
  //   }
  // }

  // Future<void> _pickDateRange() async {
  //   DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime(2100), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.red.shade700)), child: child!));
  //   if (picked != null) { setState(() => _selectedDateRange = picked); _fetchVendorTargetData(); }
  // }

  Future<void> _pickDateRange() async {
  DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2023),
    lastDate: DateTime(2100),
    initialDateRange: _selectedDateRange,
    locale: const Locale('id', 'ID'), // Memastikan kalender menggunakan Bahasa Indonesia
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.red.shade700, // Warna tema utama (Header & Tombol)
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
        ),
        // --- BAGIAN KUNCI: MENGATUR UKURAN DIALOG ---
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,  // Membatasi lebar maksimal agar tidak full screen
              maxHeight: 550, // Membatasi tinggi maksimal
            ),
            child: child!,
          ),
        ),
      );
    },
  );

  if (picked != null) {
    setState(() => _selectedDateRange = picked);
    _fetchVendorTargetData();
  }
}

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); } catch (e) { return "-"; }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}