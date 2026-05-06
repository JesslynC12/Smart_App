import 'package:flutter/material.dart';
import 'package:project_app/vendor/booking_antrian.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:project_app/dynamic_tab_page.dart';

class VendorOnProcessPage extends StatefulWidget {
  final String vendorNik;
  const VendorOnProcessPage({super.key, required this.vendorNik});

  @override
  State<VendorOnProcessPage> createState() => _VendorOnProcessPageState();
}

class _VendorOnProcessPageState extends State<VendorOnProcessPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _dataList = [];

  // Variabel Filter sesuai style BookingPlanning
  DateTime _selectedDate = DateTime.now();
  String _dateFilterType = 'stuffing_date';

  @override
  void initState() {
    super.initState();
    _fetchOngoingOrders();
  }

  // Future<void> _fetchOngoingOrders() async {
  //   try {
  //     setState(() => _isLoading = true);

  //     String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

  //     final response = await supabase.from('shipping_assignments').select('''
  //           *,
  //           request:shipping_id (
  //             *,
  //             warehouse:warehouse(warehouse_id,warehouse_name, lokasi),
  //             delivery_order(
  //               do_number,
  //               customer(customer_id, customer_name),
  //               do_details(
  //                 qty, 
  //                 material:material_id (material_id, material_name)
  //               )
  //             )
  //           )
  //         ''')
  //         .eq('nik', widget.vendorNik)
  //         .eq('status_assignment', 'accepted')
  //         .not('jam_booking', 'is', null)
  //         .eq('request.$_dateFilterType', formattedDate)
  //         .order('jam_booking', ascending: true);

  //     if (mounted) {
  //       setState(() {
  //         _dataList = List<Map<String, dynamic>>.from(response);
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //       _showSnackBar("Error: $e", Colors.red);
  //     }
  //   }
  // }

//   Future<void> _fetchOngoingOrders() async {
//   try {
//     setState(() => _isLoading = true);
//     String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

//     final response = await supabase.from('shipping_assignments').select('''
//           *,
//           shipping_request:shipping_id!inner (
//             *,
//             warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
//             delivery_order(
//               do_number,
//               customer(customer_id, customer_name),
//               do_details(
//                 qty, 
//                 material:material_id (material_id, material_name)
//               )
//             )
//           )
//         ''')
//         .eq('nik', widget.vendorNik)
//         .eq('status_assignment', 'accepted')
//         .not('jam_booking', 'is', null)
//         .eq('shipping_request.$_dateFilterType', formattedDate) // Gunakan alias yang sama
//         .order('jam_booking', ascending: true);

//     setState(() {
//       _dataList = List<Map<String, dynamic>>.from(response);
//       _isLoading = false;
//     });
//   } catch (e) {
//     setState(() => _isLoading = false);
//     _showSnackBar("Error: $e", Colors.red);
//   }
// }
// Future<void> _fetchOngoingOrders() async {
//   try {
//     setState(() => _isLoading = true);
//     String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

//     // 1. Ambil data assignment vendor
//     final response = await supabase.from('shipping_assignments').select('''
//           *,
//           shipping_request:shipping_id!inner (
//             *,
//             warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
//             delivery_order(
//               do_number,
//               customer(customer_id, customer_name),
//               do_details(
//                 qty, 
//                 material:material_id (material_id, material_name)
//               )
//             )
//           )
//         ''')
//         .eq('nik', widget.vendorNik)
//         .eq('status_assignment', 'accepted')
//         .not('jam_booking', 'is', null)
//         .eq('shipping_request.$_dateFilterType', formattedDate)
//         .order('jam_booking', ascending: true);

//     // 2. PROSES GROUPING MANUAL AGAR TIDAK DUPLIKAT
//     Map<String, Map<String, dynamic>> groupedMap = {};

//     for (var item in response) {
//       final req = item['shipping_request'];
//       if (req == null) continue;

//       // Buat key unik (Pakai group_id jika ada, jika tidak pakai shipping_id)
//       String key = req['group_id'] != null 
//           ? "GROUP_${req['group_id']}" 
//           : "SINGLE_${req['shipping_id']}";

//       if (!groupedMap.containsKey(key)) {
//         // Masukkan data pertama
//         Map<String, dynamic> mutableItem = Map<String, dynamic>.from(item);
//         mutableItem['all_assignment_ids'] = [item['id_assignment']];
//   mutableItem['all_shipping_ids'] = [item['shipping_id']];
//         // Suntik RDD origin ke tiap DO di item pertama
//         List dos = List.from(mutableItem['shipping_request']['delivery_order'] ?? []);
//         for (var d in dos) {
//           d['rdd_origin'] = req['rdd'];
//           d['parent_so'] = req['so'];
//         }
//         mutableItem['shipping_request']['delivery_order'] = dos;
//         groupedMap[key] = mutableItem;
//       } else {
//         groupedMap[key]!['all_assignment_ids'].add(item['id_assignment']);
//   groupedMap[key]!['all_shipping_ids'].add(item['shipping_id']);
//         // Jika sudah ada, gabungkan Delivery Order-nya saja
//         List existingDos = List.from(groupedMap[key]!['shipping_request']['delivery_order'] ?? []);
//         List newDos = List.from(req['delivery_order'] ?? []);

//         for (var ndo in newDos) {
//           ndo['rdd_origin'] = req['rdd']; // Simpan RDD spesifik member grup ini
//           ndo['parent_so'] = req['so'];
//           existingDos.add(ndo);
//         }
//         groupedMap[key]!['shipping_request']['delivery_order'] = existingDos;
//       }
//     }

//     setState(() {
//       _dataList = groupedMap.values.toList();
//       _isLoading = false;
//     });
//   } catch (e) {
//     setState(() => _isLoading = false);
//     _showSnackBar("Error: $e", Colors.red);
//   }
// }

Future<void> _fetchOngoingOrders() async {
  try {
    setState(() => _isLoading = true);
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final response = await supabase.from('shipping_assignments').select('''
          *,
          shipping_request:shipping_id!inner (
            *,
            warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order(
              do_number,
              customer(customer_id, customer_name),
              do_details(
                qty, 
                material:material_id (material_id, material_name)
              )
            )
          )
        ''')
        .eq('nik', widget.vendorNik)
        .eq('status_assignment', 'accepted')
        .not('jam_booking', 'is', null)
        .eq('shipping_request.$_dateFilterType', formattedDate)
        .order('jam_booking', ascending: true);

    Map<String, Map<String, dynamic>> groupedMap = {};

    for (var item in response) {
      final req = item['shipping_request'];
      if (req == null) continue;

      String key = req['group_id'] != null 
          ? "GROUP_${req['group_id']}" 
          : "SINGLE_${req['shipping_id']}";

      if (!groupedMap.containsKey(key)) {
        Map<String, dynamic> mutableItem = Map<String, dynamic>.from(item);
        
        // Simpan ID Assignment dan Shipping ID dalam List untuk proses bulk update
        mutableItem['grouped_assignment_ids'] = [item['id_assignment']];
        mutableItem['grouped_shipping_ids'] = [item['shipping_id']];
        
        List dos = List.from(mutableItem['shipping_request']['delivery_order'] ?? []);
        for (var d in dos) {
          d['rdd_origin'] = req['rdd'];
          d['parent_so'] = req['so'];
        }
        mutableItem['shipping_request']['delivery_order'] = dos;
        groupedMap[key] = mutableItem;
      } else {
        // Gabungkan ID untuk keperluan bulk action
        groupedMap[key]!['grouped_assignment_ids'].add(item['id_assignment']);
        groupedMap[key]!['grouped_shipping_ids'].add(item['shipping_id']);
        
        List existingDos = List.from(groupedMap[key]!['shipping_request']['delivery_order'] ?? []);
        List newDos = List.from(req['delivery_order'] ?? []);

        for (var ndo in newDos) {
          ndo['rdd_origin'] = req['rdd'];
          ndo['parent_so'] = req['so'];
          existingDos.add(ndo);
        }
        groupedMap[key]!['shipping_request']['delivery_order'] = existingDos;
      }
    }

    setState(() {
      _dataList = groupedMap.values.toList();
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Error: $e", Colors.red);
  }
}

  // Future<void> _cancelOrder(Map<String, dynamic> item, String reason) async {
  //   try {
  //     final List<int> assignmentId = List<int>.from(item['all_assignment_ids'] ?? [item['id_assignment']]);
  //     final List<int> shipId = List<int>.from(item['all_shipping_ids'] ?? [item['shipping_id']]);

  //     await supabase.from('shipping_assignments').update({
  //       'status_assignment': 'rejected',
  //       'reason_rejected': reason,
  //       'responded_at': DateTime.now().toIso8601String(),
  //       'jam_booking': null,
  //     }).eq('id_assignment', assignmentId);

  //     await supabase.from('shipping_request').update({
  //       'status': 'waiting assign vendor delivery',
  //     }).eq('shipping_id', shipId);

  //     _showSnackBar("Order berhasil dibatalkan", Colors.orange);
  //     _fetchOngoingOrders();
  //   } catch (e) {
  //     _showSnackBar("Gagal membatalkan: $e", Colors.red);
  //   }
  // }

Future<void> _cancelOrder(Map<String, dynamic> item, String reason) async {
  try {
    // Ambil daftar ID yang sudah kita kumpulkan di fetch data
    final List<int> assignmentIds = List<int>.from(item['grouped_assignment_ids']);
    final List<int> shipIds = List<int>.from(item['grouped_shipping_ids']);

    // 1. Update semua baris assignment menjadi 'rejected'
    await supabase.from('shipping_assignments').update({
      'status_assignment': 'cancel booking',
      'reason_rejected': reason,
      'cancelled_at': DateTime.now().toIso8601String(),
      'jam_booking': null,
    }).inFilter('id_assignment', assignmentIds);

    // 2. Update semua baris shipping_request kembali ke status waiting assign vendor
    await supabase.from('shipping_request').update({
      'status': 'waiting assign vendor delivery',
    }).inFilter('shipping_id', shipIds);

    _showSnackBar("Order berhasil dibatalkan", Colors.orange);
    _fetchOngoingOrders();
  } catch (e) {
    _showSnackBar("Gagal membatalkan: $e", Colors.red);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildTopFilterBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.red))
              : RefreshIndicator(
                  onRefresh: _fetchOngoingOrders,
                  child: _dataList.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _dataList.length,
                        itemBuilder: (context, index) => _buildDetailedOngoingCard(_dataList[index]),
                      ),
                ),
          ),
        ],
      ),
    );
  }

  // --- UI FILTER BAR (STYLE PLANNING) ---
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: !isToday ? Colors.white30 : Colors.grey.shade400)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _dateFilterType == 'stuffing_date' ? "Stuffing" : "RDD",
                        isDense: true,
                        dropdownColor: !isToday ? Colors.red.shade800 : Colors.white,
                        iconEnabledColor: !isToday ? Colors.white : Colors.black87,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: !isToday ? Colors.white : Colors.black87),
                        items: ["RDD", "Stuffing"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          setState(() => _dateFilterType = val == "RDD" ? "rdd" : "stuffing_date");
                          _fetchOngoingOrders();
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: !isToday ? Colors.white : Colors.black87),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: !isToday ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                  _dateFilterType = "stuffing_date";
                });
                _fetchOngoingOrders();
              },
            ),
        ],
      ),
    );
  }


  // // --- UI CARD DETAIL (GABUNGAN PLANNING + AKSI) ---
  // Widget _buildDetailedOngoingCard(Map<String, dynamic> item) {
  //   final request = item['request'] ?? {};
  //   final bool isGroup = request['group_id'] != null;
  //   final List dos = request['delivery_order'] ?? [];
  //   final warehouse = request['warehouse'];
  //   String warehouseDisplay = warehouse != null 
  //       ? "${warehouse['lokasi']} - ${warehouse['warehouse_name']}" 
  //       : "-";

  //   return Card(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     elevation: 3,
  //     child: Column(
  //       children: [
  //         // Header: Warna Ungu (Group) / Biru (Single)
  //         Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //           decoration: BoxDecoration(
  //             color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
  //             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Row(
  //                 children: [
  //                   const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
  //                   const SizedBox(width: 8),
  //                   Text(item['jam_booking'] ?? "-",
  //                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  //                 ],
  //               ),
  //               Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  //                 decoration: BoxDecoration(
  //                   color: Colors.white24,
  //                   borderRadius: BorderRadius.circular(20),
  //                   border: Border.all(color: Colors.white, width: 0.5),
  //                 ),
  //                 child: Text(
  //                   isGroup ? "GROUP SHIP ${request['group_id']}" : "SHIP ID ${request['shipping_id']}",
  //                   style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),

  //         Padding(
  //           padding: const EdgeInsets.all(16),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               // Info Utama baris 1
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   _infoBox("RDD", _formatDate(request['rdd'])),
  //                   _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
  //                   _infoBox("DEDICATED", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
  //                 ],
  //               ),
  //               const SizedBox(height: 12),
  //               // Info Warehouse (Lokasi - Nama)
  //               _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase(), color: Colors.red.shade700),
                
  //               const Divider(height: 32),

  //               // TOMBOL AKSI
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: ElevatedButton.icon(
  //                       onPressed: () {
  //                         DynamicTabPage.of(context)?.openTab(
  //                           "Edit Jam #${item['shipping_id']}", 
  //                           ScheduleSelectionPage(
  //                             assignmentId: item['id_assignment'],
  //                             shippingId: item['shipping_id'],
  //                             onSuccess: () => _fetchOngoingOrders(),
  //                           ),
  //                         );
  //                       },
  //                       icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
  //                       label: const Text("EDIT JAM", style: TextStyle(color: Colors.white, fontSize: 11)),
  //                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
  //                     ),
  //                   ),
  //                   const SizedBox(width: 10),
  //                   Expanded(
  //                     child: OutlinedButton.icon(
  //                       onPressed: () => _showCancelDialog(item),
  //                       icon: const Icon(Icons.cancel, size: 16),
  //                       label: const Text("CANCEL", style: TextStyle(fontSize: 11)),
  //                       style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 24),

  //               // LIST DELIVERY ORDER (Detail Material & Customer)
  //               const Text("RINCIAN MUATAN (DO)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
  //               const SizedBox(height: 10),
  //               ...dos.map((doItem) {
  //                 final List details = doItem['do_details'] ?? [];
  //                 return Container(
  //                   margin: const EdgeInsets.only(bottom: 12),
  //                   padding: const EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.shade50,
  //                     borderRadius: BorderRadius.circular(10),
  //                     border: Border.all(color: Colors.grey.shade200),
  //                   ),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Row(
  //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                         children: [
  //                           Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11)),
  //                           Text("SO: ${request['so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
  //                         ],
  //                       ),
  //                       const SizedBox(height: 6),
  //                       Text("👤 ${doItem['customer']?['customer_id']} - ${doItem['customer']?['customer_name']}",
  //                           style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
  //                       const Divider(height: 20),
  //                       ...details.map((det) => Padding(
  //                         padding: const EdgeInsets.only(bottom: 6),
  //                         child: Row(
  //                           children: [
  //                             const Icon(Icons.circle, size: 6, color: Colors.grey),
  //                             const SizedBox(width: 8),
  //                             Expanded(
  //                               child: Text(
  //                                 "${det['material']?['material_id']} - ${det['material']?['material_name']}",
  //                                 style: const TextStyle(fontSize: 10),
  //                               ),
  //                             ),
  //                             Text("${det['qty']} Unit", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
  //                           ],
  //                         ),
  //                       )).toList(),
  //                     ],
  //                   ),
  //                 );
  //               }).toList(),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildDetailedOngoingCard(Map<String, dynamic> item) {
  // // UBAH: Sesuaikan key dengan alias di query (shipping_request)
  // final request = item['shipping_request'] ?? {}; 
  
  // if (request.isEmpty) {
  //   return const SizedBox.shrink(); // Mencegah card kosong muncul jika data request gagal load
  // }

  // final bool isGroup = request['group_id'] != null;
  // final List dos = request['delivery_order'] ?? [];
  // final warehouse = request['warehouse'];
  
  // String warehouseDisplay = warehouse != null 
  //     ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 
  //     : "-";

  // return Card(
  //   margin: const EdgeInsets.only(bottom: 16),
  //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //   elevation: 3,
  //   child: Column(
  //     children: [
  //       // Header
  //       Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //         decoration: BoxDecoration(
  //           color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
  //           borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
  //         ),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Row(
  //               children: [
  //                 const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
  //                 const SizedBox(width: 8),
  //                 Text(item['jam_booking'] ?? "-",
  //                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  //               ],
  //             ),
  //             Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  //               decoration: BoxDecoration(
  //                 color: Colors.white24,
  //                 borderRadius: BorderRadius.circular(20),
  //                 border: Border.all(color: Colors.white, width: 0.5),
  //               ),
  //               child: Text(
  //                 isGroup ? "GROUP SHIP ${request['group_id']}" : "SHIP ID ${request['shipping_id']}",
  //                 style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),

  //       Padding(
  //         padding: const EdgeInsets.all(16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // Baris Info RDD, Stuffing, Dedicated
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 _infoBox("RDD", _formatDate(request['rdd'])),
  //                 _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
  //                 _infoBox("DEDICATED", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
  //                 _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase(), color: Colors.red.shade700),
              
  //               ],
  //             ),
  //             //const SizedBox(height: 12),
  //             // Info Warehouse
              
  //             const Divider(height: 32),

  //             // Bagian Detail DO (Ini yang menampilkan material, customer, dll)
  //             const Text("RINCIAN MUATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
  //             const SizedBox(height: 10),
  //             ...dos.map((doItem) {
  //               final List details = doItem['do_details'] ?? [];
  //               return Container(
  //                 margin: const EdgeInsets.only(bottom: 12),
  //                 padding: const EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: Colors.grey.shade50,
  //                   borderRadius: BorderRadius.circular(10),
  //                   border: Border.all(color: Colors.grey.shade200),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Row(
  //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                       children: [
  //                         Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11)),
  //                         Text("SO: ${request['so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
  //                       ],
  //                     ),
  //                     const SizedBox(height: 6),
  //                     Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}",
  //                         style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
  //                     const Divider(height: 20),
  //                     ...details.map((det) {
  //                       final mat = det['material'] ?? {};
  //                       return Padding(
  //                         padding: const EdgeInsets.only(bottom: 6),
  //                         child: Row(
  //                           children: [
  //                             const Icon(Icons.circle, size: 6, color: Colors.grey),
  //                             const SizedBox(width: 8),
  //                             Expanded(
  //                               child: Text(
  //                                 "${mat['material_id'] ?? '-'} - ${mat['material_name'] ?? '-'}",
  //                                 style: const TextStyle(fontSize: 10),
  //                               ),
  //                             ),
  //                             Text("${det['qty']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
  //                           ],
  //                         ),
  //                       );
  //                     }).toList(),
  //                   ],
  //                 ),                
  //                 );
  //             }).toList(),
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: OutlinedButton.icon(
  //                     onPressed: () => _showCancelDialog(item),
  //                     icon: const Icon(Icons.cancel, size: 16),
  //                     label: const Text("CANCEL", style: TextStyle(fontSize: 11)),
  //                     style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 10),
  //                 Expanded(
  //                   child: ElevatedButton.icon(
  //                     onPressed: () {
  //                       DynamicTabPage.of(context)?.openTab(
  //                         "Reschedule #${request['shipping_id']}", 
  //                         ScheduleSelectionPage(
  //                           assignmentId: item['id_assignment'],
  //                           shippingId: item['shipping_id'],
  //                           oldTime: item['jam_booking'],
  // vendorNik: widget.vendorNik,
  //                           onSuccess: () => _fetchOngoingOrders(),
  //                         ),
  //                       );
  //                     },
  //                     icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
  //                     label: const Text("RESCHEDULE", style: TextStyle(color: Colors.white, fontSize: 11)),
  //                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
  //                   ),
  //                 ),
                  
                 
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],  
  //   ),
  // ); 
  // }

//   Widget _buildDetailedOngoingCard(Map<String, dynamic> item) {
//   // Mengambil data request (menggunakan alias shipping_request dari query)
//   final request = item['shipping_request'] ?? {}; 
  
//   if (request.isEmpty) {
//     return const SizedBox.shrink(); 
//   }

//   final bool isGroup = request['group_id'] != null;
//   final List dos = request['delivery_order'] ?? [];
//   final warehouse = request['warehouse'];
  
//   String warehouseDisplay = warehouse != null 
//       ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 
//       : "-";

//   // Cek apakah vendor masih boleh reschedule (Maks 2 jam sebelum jam_booking)
//   bool isAllowed = _canReschedule(item['jam_booking'], request['stuffing_date']);

//   return Card(
//     margin: const EdgeInsets.only(bottom: 16),
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     elevation: 3,
//     child: Column(
//       children: [
//         // HEADER CARD: Ungu untuk Group, Biru untuk Single
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
//                   const SizedBox(width: 8),
//                   Text(
//                     item['jam_booking'] ?? "-",
//                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.white24,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: Colors.white, width: 0.5),
//                 ),
//                 child: Text(
//                   isGroup ? "GROUP SHIP ${request['group_id']}" : "SHIP ID ${request['shipping_id']}",
//                   style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//         ),

//         Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // BARIS INFO: RDD, STUFFING, DEDICATED, WAREHOUSE
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _infoBox("RDD", _formatDate(request['rdd'])),
//                   _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
//                   _infoBox("STATUS", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
//                   _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase(), color: Colors.red.shade700),
//                 ],
//               ),
              
//               const Divider(height: 32),

//               // RINCIAN MUATAN (DO)
//               const Text("RINCIAN MUATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
//               const SizedBox(height: 10),
              
//               ...dos.map((doItem) {
//                 final List details = doItem['do_details'] ?? [];
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.grey.shade200),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11)),
//                           Text("SO: ${doItem['parent_so'] ?? request['so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
//                         ],
//                       ),
//                       const SizedBox(height: 6),
//                       Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}",
//                           style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
//                       const Divider(height: 20),
//                       ...details.map((det) {
//                         final mat = det['material'] ?? {};
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 6),
//                           child: Row(
//                             children: [
//                               const Icon(Icons.circle, size: 6, color: Colors.grey),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Text(
//                                   "${mat['material_id'] ?? '-'} - ${mat['material_name'] ?? '-'}",
//                                   style: const TextStyle(fontSize: 10),
//                                 ),
//                               ),
//                               Text("${det['qty']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 );
//               }).toList(),

//               const SizedBox(height: 10),

//               // TOMBOL AKSI: CANCEL & RESCHEDULE
//               Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       onPressed: () => _showCancelDialog(item),
//                       icon: const Icon(Icons.cancel, size: 16),
//                       label: const Text("CANCEL", style: TextStyle(fontSize: 11)),
//                       style: OutlinedButton.styleFrom(
//                         foregroundColor: Colors.red, 
//                         side: const BorderSide(color: Colors.red),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: isAllowed ? () {
//                         DynamicTabPage.of(context)?.openTab(
//                           "Reschedule #${request['shipping_id']}", 
//                           ScheduleSelectionPage(
//                             assignmentId: item['id_assignment'],
//                             shippingId: item['shipping_id'],
//                             oldTime: item['jam_booking'],
//                             vendorNik: widget.vendorNik,
//                             onSuccess: () => _fetchOngoingOrders(),
//                           ),
//                         );
//                       } : null, // Disabled jika sudah lewat batas 2 jam
//                       icon: Icon(
//                         isAllowed ? Icons.edit_calendar : Icons.lock_clock, 
//                         size: 16, 
//                         color: Colors.white
//                       ),
//                       label: Text(
//                         isAllowed ? "RESCHEDULE" : "TERKUNCI", 
//                         style: const TextStyle(color: Colors.white, fontSize: 11)
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: isAllowed ? Colors.red.shade700 : Colors.grey,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               // --- TULISAN PERINGATAN (SEKARANG DI LUAR IF AGAR MUNCUL TERUS) ---
//               // Padding(
//               //   padding: const EdgeInsets.only(top: 12.0),
//               //   child: Container(
//               //     padding: const EdgeInsets.all(8),
//               //     decoration: BoxDecoration(
//               //       color: isAllowed ? Colors.blue.shade50 : Colors.red.shade50,
//               //       borderRadius: BorderRadius.circular(6),
//               //     ),
//               //     child: Row(
//               //       children: [
//               //         Icon(
//               //           Icons.info_outline, 
//               //           size: 14, 
//               //           color: isAllowed ? Colors.blue.shade900 : Colors.red.shade900
//               //         ),
//               //         const SizedBox(width: 8),
//               //         Expanded(
//               //           child: Text(
//               //             "Batas reschedule berakhir (Maks. 2 jam sebelum jam booking).",
//               //             style: TextStyle(
//               //               fontSize: 10, 
//               //               color: isAllowed ? Colors.blue.shade900 : Colors.red.shade900, 
//               //               fontWeight: isAllowed ? FontWeight.normal : FontWeight.bold,
//               //               fontStyle: FontStyle.italic
//               //             ),
//               //           ),
//               //         ),
//               //       ],
//               //     ),
//               //   ),
//               // ),
//               // // Peringatan jika tombol terkunci
//               // if (!isAllowed)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8.0),
//                   child: Row(
//                     children: [
//                       const Icon(Icons.info_outline, size: 12, color: Colors.red),
//                       const SizedBox(width: 4),
//                       Expanded(
//                         child: Text(
//                           "Batas reschedule berakhir (Maks 2 jam sebelum jam booking).",
//                           style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontStyle: FontStyle.italic),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
// }
Widget _buildDetailedOngoingCard(Map<String, dynamic> item) {
  final request = item['shipping_request'] ?? {}; 
  if (request.isEmpty) return const SizedBox.shrink(); 

  final bool isGroup = request['group_id'] != null;
  final List dos = request['delivery_order'] ?? [];
  final warehouse = request['warehouse'];
  
  String warehouseDisplay = warehouse != null 
      ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 
      : "-";

  bool isAllowed = _canReschedule(item['jam_booking'], request['stuffing_date']);

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
    child: Column(
      children: [
        // HEADER CARD
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
                  Text(item['jam_booking'] ?? "-",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
                child: Text(
                  isGroup ? "GROUP SHIP ${request['group_id']}" : "SHIP ID ${request['shipping_id']}",
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
              // // INFO LOGS (Assigned & Responded)
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Text("Assigned: ${_formatDateTime(item['assigned_at'])}",
              //         style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
              //     Text("Responded: ${_formatDateTime(item['responded_at'])}",
              //         style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
              //   ],
              // ),
              // const SizedBox(height: 12),

              // INFO SUMMARY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
                  _infoBox("STATUS", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
                  _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase(), color: Colors.red.shade700),
                ],
              ),
              
              const Divider(height: 32),

              // --- LIST DO & RDD (DIUBAH KE DESAIN KONSISTEN) ---
              ...dos.map((doItem) {
                final List details = doItem['do_details'] ?? [];
                final String rddSpesifik = _formatDate(doItem['rdd_origin']);
                final String custInfo = "${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Teks RDD di luar kotak pink
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

                    // 2. Kontainer Detail DO
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          // Header Pink DO
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
                                Text("SO: ${doItem['parent_so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text(custInfo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Tabel Material
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

              const SizedBox(height: 10),

              // TOMBOL AKSI
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(item),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text("CANCEL", style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
  child: ElevatedButton.icon(
    // Jika isAllowed true, jalankan fungsi navigasi. Jika false, set null (otomatis disabled)
    onPressed: isAllowed ? () {
      DynamicTabPage.of(context)?.openTab(
        "Reschedule #${request['shipping_id']}", 
        ScheduleSelectionPage(
          assignmentId: item['id_assignment'],
          shippingId: item['shipping_id'],
          oldTime: item['jam_booking'],
          vendorNik: widget.vendorNik,
          onSuccess: () => _fetchOngoingOrders(),
        ),
      );
    } : null, 
    icon: Icon(
      isAllowed ? Icons.edit_calendar : Icons.lock_clock, 
      size: 16, 
      color: Colors.white,
    ),
    label: Text(
      isAllowed ? "RESCHEDULE" : "TERKUNCI", 
      style: const TextStyle(fontSize: 11, color: Colors.white),
    ),
    style: ElevatedButton.styleFrom(
      // Warna merah jika aktif, abu-abu jika terkunci
      backgroundColor: isAllowed ? Colors.red.shade700 : Colors.grey,
    ),
  ),
),
              
            ],
            
          ),
           if (!isAllowed)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    "* Batas reschedule berakhir (Maks 2 jam sebelum jam booking).",
                    style: TextStyle(fontSize: 10, color: Colors.red, fontStyle: FontStyle.italic),
                  ),
                ),
            ]
          ),
          ),
      ]
    ),
    );
}

// Tambahkan Helper TableCell jika belum ada
Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left}) {
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Text(
      text,
      textAlign: align,
      style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
    ),
  );
}
String _formatDateTime(String? dateStr) {
  if (dateStr == null) return "-";
  DateTime dt = DateTime.parse(dateStr).toLocal();
  return DateFormat('dd/MM/yy HH:mm').format(dt);
}
  // // --- HELPERS ---
  // void _showCancelDialog(Map<String, dynamic> item) {
  //   final TextEditingController reasonController = TextEditingController();
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text("Batalkan Pengiriman?", style: TextStyle(fontWeight: FontWeight.bold)),
  //       content: TextField(
  //         controller: reasonController,
  //         maxLines: 3,
  //         decoration: const InputDecoration(hintText: "Alasan pembatalan...", border: OutlineInputBorder()),
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context), child: const Text("KEMBALI")),
  //         ElevatedButton(
  //           onPressed: () {
  //             if (reasonController.text.trim().isEmpty) return;
  //             Navigator.pop(context);
  //             _cancelOrder(item, reasonController.text);
  //           },
  //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //           child: const Text("YA, CANCEL", style: TextStyle(color: Colors.white)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

// // --- DIALOG CANCEL DENGAN INPUT ALASAN ---
//   void _showCancelDialog(Map<String, dynamic> item) {
//     final TextEditingController reasonController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Batalkan Pengiriman?", style: TextStyle(fontWeight: FontWeight.bold)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             //const Text("Mohon berikan alasan pembatalan."),
//             const SizedBox(height: 15),
//             TextField(
//               controller: reasonController,
//               maxLines: 3,
//               decoration: InputDecoration(
//                 hintText: "Contoh: Armada mengalami kendala teknis...",
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text("KEMBALI")),
//           ElevatedButton(
//             onPressed: () {
//               if (reasonController.text.trim().isEmpty) {
//                 _showSnackBar("Alasan wajib diisi!", Colors.orange);
//                 return;
//               }
//               Navigator.pop(context);
//               _cancelOrder(item, reasonController.text);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text("YA, CANCEL", style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

// void _showCancelDialog(Map<String, dynamic> item) {
//   final TextEditingController reasonController = TextEditingController();
  
//   showDialog(
//     context: context,
//     builder: (context) => AlertDialog(
//       title: const Text("Alasan Pembatalan"),
//       content: TextField(
//         controller: reasonController,
//         decoration: const InputDecoration(hintText: "Masukkan alasan..."),
//       ),
//       actions: [
//         TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
//         ElevatedButton(
//           onPressed: () {
//             if (reasonController.text.isNotEmpty) {
//               Navigator.pop(context);
//               _cancelOrder(item, reasonController.text); // Memanggil fungsi baru
//             }
//           },
//           child: const Text("SUBMIT"),
//         ),
//       ],
//     ),
//   );
// }
void _showCancelDialog(Map<String, dynamic> item) {
  final List<String> cancelReasons = [
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
          title: const Text("Pilih Alasan Pembatalan", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: cancelReasons.map((reason) => RadioListTile<String>(
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
              child: const Text("KEMBALI")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: selectedReason == null 
                ? null // Button mati jika alasan belum dipilih
                : () {
                    Navigator.pop(context);
                    _cancelOrder(item, selectedReason!);
                  },
              child: const Text("SUBMIT CANCEL", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

  bool _canReschedule(String? jamBooking, String? stuffingDate) {
  if (jamBooking == null || stuffingDate == null) return false;

  try {
    // 1. Ambil jam mulai (misal "13:00" dari "13:00 - 15:00")
    String startTimeStr = jamBooking.split(" - ")[0]; 
    
    // 2. Gabungkan dengan tanggal stuffing agar menjadi objek DateTime yang lengkap
    DateTime stuffingDay = DateTime.parse(stuffingDate);
    List<String> timeParts = startTimeStr.split(":");
    
    DateTime bookingDateTime = DateTime(
      stuffingDay.year,
      stuffingDay.month,
      stuffingDay.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    // 3. Batas waktu adalah 2 jam sebelum booking dimulai
    DateTime limitTime = bookingDateTime.subtract(const Duration(hours: 2));

    // 4. Vendor masih bisa edit jika waktu sekarang BELUM melewati limitTime
    return DateTime.now().isBefore(limitTime);
  } catch (e) {
    return false;
  }
}

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchOngoingOrders();
    }
  }

  Widget _infoBox(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }

  String _formatDate(String? s) => s == null ? "-" : DateFormat('dd MMM yyyy').format(DateTime.parse(s));
  void _showSnackBar(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  Widget _buildEmptyState() => const Center(child: Text("Tidak ada pengiriman aktif pada tanggal ini.", style: TextStyle(color: Colors.grey)));
}