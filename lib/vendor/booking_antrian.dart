import 'package:flutter/material.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ScheduleSelectionPage extends StatefulWidget {
  final int assignmentId;
  final int shippingId;
  final String? oldTime;
  final String vendorNik;
  final VoidCallback onSuccess;
  

  const ScheduleSelectionPage({
    super.key,
    required this.assignmentId,
    required this.shippingId,
    this.oldTime,
    required this.vendorNik,
    required this.onSuccess,
  });

  @override
  State<ScheduleSelectionPage> createState() => _ScheduleSelectionPageState();
}

class _ScheduleSelectionPageState extends State<ScheduleSelectionPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _shippingData;
  String? _selectedTime;

  // final List<String> _timeSlots = [
  //   '08:00', '09:00', '10:00', '11:00', 
  //   '13:00', '14:00', '15:00', '16:00'
  // ];

String? _tempSelectedReason;
final List<String> _rescheduleReasons = [
  'Kendala Truk',
  'Macet di Perjalanan',
  'Truk Tidak Tersedia',
  'Kecelakaan',
  'Lainnya',
];

  final List<String> _timeSlots = [
 '07:00 - 09:00',
  '09:00 - 11:00',
  '11:00 - 13:00', // Jam Istirahat
  '13:00 - 15:00',
  '15:00 - 17:00',
  '17:00 - 19:00',
  '19:00 - 21:00',
  '21:00 - 23:00',
];

Map<String, int> _bookedCounts = {};
//final int _maxCapacity = 14;


  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Memuat detail SO/DO saat halaman dibuka
  }

// Fungsi baru untuk menjalankan urutan muat data yang benar
  Future<void> _loadInitialData() async {
    await _loadData(); // 1. Muat detail shipment dulu
    if (_shippingData != null) {
      await _checkAvailability(); // 2. Hitung slot berdasarkan tanggal & gudang shipment tersebut
    }
  }


  // Future<void> _loadData() async {
  //   try {
  //     setState(() => _isLoading = true);
      
  //     // Mengambil data lengkap shipping termasuk detail material (sama seperti AssignVendorPage)
  //     final response = await supabase
  //         .from('shipping_request')
  //         .select('''
  //           *,
  //           delivery_order(
  //             *,
  //             customer(*),
  //             do_details(
  //               qty,
  //               material:material_id (material_id, material_name, net_weight)
  //             )
  //           )
  //         ''')
  //         .eq('shipping_id', widget.shippingId)
  //         .single();

  //     setState(() {
  //       _shippingData = response;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Gagal memuat detail: $e"), backgroundColor: Colors.red),
  //     );
  //   }
  // }

//   Future<void> _loadData() async {
//   try {
//     setState(() => _isLoading = true);
    
//     final initialRes = await supabase
//         .from('shipping_request')
//         .select('group_id')
//         .eq('shipping_id', widget.shippingId)
//         .single();

//     final int? groupId = initialRes['group_id'];
    
//     // Pastikan kita select kolom 'so' juga
//     PostgrestFilterBuilder query = supabase.from('shipping_request').select('''
//           *,
//           so, 
//           warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
//           delivery_order(
//             *,
//             customer(*),
//             do_details(
//               qty,
//               material:material_id (material_id, material_name, net_weight)
//             )
//           )
//         ''');

//     dynamic response;
//     if (groupId != null) {
//       response = await query.eq('group_id', groupId).order('shipping_id');
//     } else {
//       response = await query.eq('shipping_id', widget.shippingId);
//     }

//     setState(() {
//       if (groupId != null) {
//         List list = response as List;
//         _shippingData = Map<String, dynamic>.from(list[0]);
//         _shippingData!['all_shipping_ids'] = list.map((e) => e['shipping_id']).toList();
        
//         List allDos = [];
//         for (var item in list) {
//           // --- PERBAIKAN DI SINI ---
//           // Ambil semua DO dari baris ini
//           List currentDos = List.from(item['delivery_order'] ?? []);
          
//           // Sisipkan nomor SO dari baris ini ke dalam setiap DO-nya
//           for (var doItem in currentDos) {
//             doItem['parent_so'] = item['so']; 
//           }
          
//           allDos.addAll(currentDos);
//         }
//         _shippingData!['delivery_order'] = allDos;
//       } else {
//         final singleData = (response as List).first;
//         _shippingData = Map<String, dynamic>.from(singleData);
        
//         // Untuk data single juga kita set agar konsisten
//         if (_shippingData!['delivery_order'] != null) {
//           for (var doItem in _shippingData!['delivery_order']) {
//             doItem['parent_so'] = _shippingData!['so'];
//           }
//         }
//       }
//       _isLoading = false;
//     });
//   } catch (e) {
//     setState(() => _isLoading = false);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Gagal memuat detail: $e"), backgroundColor: Colors.red),
//     );
//   }
// }

Future<void> _loadData() async {
  try {
    setState(() => _isLoading = true);
    
    final initialRes = await supabase
        .from('shipping_request')
        .select('group_id')
        .eq('shipping_id', widget.shippingId)
        .single();

    final int? groupId = initialRes['group_id'];
    
    PostgrestFilterBuilder query = supabase.from('shipping_request').select('''
          *,
          so, 
          warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
          delivery_order(
            *,
            customer(*),
            do_details(
              qty,
              material:material_id (material_id, material_name, net_weight)
            )
          )
        ''');

    dynamic response;
    if (groupId != null) {
      response = await query.eq('group_id', groupId).order('shipping_id');
    } else {
      response = await query.eq('shipping_id', widget.shippingId);
    }

    setState(() {
      List list = response as List;
      // Simpan semua ID dalam grup untuk proses update nanti
      _shippingData = Map<String, dynamic>.from(list[0]);
      _shippingData!['all_shipping_ids'] = list.map((e) => e['shipping_id']).toList();
      
      List allDos = [];
      for (var item in list) {
        List currentDos = List.from(item['delivery_order'] ?? []);
        for (var doItem in currentDos) {
          doItem['parent_so'] = item['so']; 
          doItem['rdd_origin'] = item['rdd']; // SUNTIK RDD ASAL DI SINI
        }
        allDos.addAll(currentDos);
      }
      _shippingData!['delivery_order'] = allDos;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Gagal memuat detail: $e"), backgroundColor: Colors.red),
    );
  }
}

int _getMaxCapacity(String timeSlot) {
  final warehouseId = _shippingData?['warehouse_id'];
  bool isRestTime = timeSlot == '11:00 - 13:00';

  if (warehouseId == 1) {
    return isRestTime ? 4 : 8;
  } else if (warehouseId == 2) {
    return isRestTime ? 1 : 3;
  } else if (warehouseId == 3) {
    return isRestTime ? 2 : 4;
  }
  
  return 14; // Default jika ID lain
}


//   Future<void> _confirmAndAccept({String? rescheduleReasons}) async {
//     if (_selectedTime == null) return;
//     // Validasi Keamanan: Pastikan jam baru tidak sama dengan jam lama
//   if (widget.oldTime != null && _selectedTime == widget.oldTime) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text("Anda harus memilih jam yang berbeda untuk reschedule!"), 
//         backgroundColor: Colors.orange
//       ),
//     );
//     return;
//   }
//     setState(() => _isSaving = true);
// //String actionType = widget.oldTime == null ? 'INITIAL_BOOKING' : 'RESCHEDULE';
//     try {
//       if (widget.oldTime != null && widget.oldTime != _selectedTime) {
//         await supabase.from('booking_history').insert({
//           'id_assignment': widget.assignmentId,
//           'jam_lama': widget.oldTime,     // Pindahkan jam dari shipping_assignment
//           'jam_baru': _selectedTime,    // Catat tujuan jam barunya
//           'changed_by': widget.vendorNik,
//           //'keterangan': actionType,
//           'reason_reschedule': rescheduleReasons,
//           'created_at': DateTime.now().toIso8601String(),
//         });
//       }
//     // 1. Update tabel penugasan vendor
//       // Kita simpan status 'accepted' dan 'jam_booking' di sini
//       await supabase.from('shipping_assignments').update({
//         'status_assignment': 'accepted',
//         'responded_at': DateTime.now().toIso8601String(),
//         'jam_booking': _selectedTime, // Disimpan ke tabel assignments
//       }).eq('id_assignment', widget.assignmentId);

//       // 2. Update tabel request utama
//       // HANYA update status menjadi 'on process'. 
//       // Kita hapus baris 'arrival_time' agar tidak menyebabkan error.
//       await supabase.from('shipping_request').update({
//         'status': 'on process',
//       }).eq('shipping_id', widget.shippingId);
//       if (mounted) {
//         widget.onSuccess();
//         // Navigator.pop(context);
//         // --- PERUBAHAN DI SINI ---
//         // Ambil instance DynamicTabPage dan tutup tab saat ini
//         final dynamicTab = DynamicTabPage.of(context);
//         if (dynamicTab != null) {
//           dynamicTab.closeCurrentTab();
//         } else {
//           // Fallback jika dibuka tidak melalui dynamic tab
//           Navigator.pop(context);
//         }
//         // --------------------------
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Berhasil! Jadwal telah disimpan."), backgroundColor: Colors.green),
//         );
//       }
//     } catch (e) {
//       setState(() => _isSaving = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Gagal menyimpan: $e"), backgroundColor: Colors.red),
//       );
//     }
//   }
Future<void> _confirmAndAccept({String? rescheduleReasons}) async {
  if (_selectedTime == null) return;
  if (widget.oldTime != null && _selectedTime == widget.oldTime) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih jam yang berbeda!"), backgroundColor: Colors.orange));
    return;
  }

  setState(() => _isSaving = true);
  try {
    final List<int> shipIds = List<int>.from(_shippingData!['all_shipping_ids']);

    // 1. Ambil semua assignment ID yang terkait dengan shipping IDs ini
    final assignmentRes = await supabase
        .from('shipping_assignments')
        .select('id_assignment')
        .inFilter('shipping_id', shipIds)
        .eq('nik', widget.vendorNik);

    final List<int> assignmentIds = (assignmentRes as List).map((e) => e['id_assignment'] as int).toList();

    // 2. Insert ke history jika Reschedule
    if (widget.oldTime != null) {
      final List<Map<String, dynamic>> historyInserts = assignmentIds.map((id) => {
        'id_assignment': id,
        'jam_lama': widget.oldTime,
        'jam_baru': _selectedTime,
        'changed_by': widget.vendorNik,
        'reason_reschedule': rescheduleReasons,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();
      await supabase.from('booking_history').insert(historyInserts);
    }

    // 3. Update tabel penugasan vendor (Massal)
    await supabase.from('shipping_assignments').update({
      'status_assignment': 'accepted',
      'responded_at': DateTime.now().toIso8601String(),
      'jam_booking': _selectedTime,
    }).inFilter('id_assignment', assignmentIds);

    // 4. Update tabel request utama (Massal)
    await supabase.from('shipping_request').update({
      'status': 'on process',
    }).inFilter('shipping_id', shipIds);

    if (mounted) {
      widget.onSuccess();
      final dynamicTab = DynamicTabPage.of(context);
      if (dynamicTab != null) {
        dynamicTab.closeCurrentTab();
      } else {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil! Jadwal grup telah disimpan."), backgroundColor: Colors.green));
    }
  } catch (e) {
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menyimpan: $e"), backgroundColor: Colors.red));
  }
}
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // appBar: AppBar(
      //   title: const Text("Detail Order & Pilih Jadwal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailedSummary(), // Detail DO & SO di bagian atas
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text("⏰ PILIH JAM KEDATANGAN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                        ),
                        _buildTimePickerGrid(),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
    );
  }

Widget _buildDetailedSummary() {
    final data = _shippingData ?? {};
    final bool isGroup = data['group_id'] != null;
    final List dos = data['delivery_order'] ?? [];
    final List rejectList = data['reject_list'] ?? [];

// LOGIKA BARU: Ambil data warehouse dari hasil join
    final warehouse = data['warehouse'];
    final String warehouseDisplay = warehouse != null 
        ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 
        : "-";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        // Garis samping berubah Biru jika Group, Merah jika Single
        border: Border(left: BorderSide(color: isGroup ? Colors.blue.shade700 : Colors.red.shade700, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isGroup ? "📦 GROUP SHIPMENT" : "🚚 SINGLE SHIPMENT", 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: isGroup ? Colors.blue.shade900 : Colors.red.shade900, 
                        letterSpacing: 1.1, 
                        fontSize: 11
                      )
                    ),
                    _buildBadge(warehouseDisplay.toUpperCase(), Colors.red.shade700),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGroup ? "ID Grup: ${data['group_id']}" : "ID Shipping: ${data['shipping_id']}", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                   // _infoBox("RDD", _formatDate(data['rdd'])),
                    _infoBox("Stuffing", _formatDate(data['stuffing_date'])),
                    _infoBox("Dedicated", (data['is_dedicated'] ?? "-").toString().toUpperCase()),
                  ],
                ),

                // --- BAGIAN RIWAYAT REJECT (DARI ASSIGNVENDORPAGE) ---
                if (rejectList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade900),
                            const SizedBox(width: 6),
                            Text("RIWAYAT REJECT VENDOR:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...rejectList.map((rej) {
                          String vendorName = rej['master_vendor']?['vendor_name'] ?? "Unknown Vendor";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text("• $vendorName", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: const Text("DETAIL ITEM & CUSTOMER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),

          // --- LOOPING DO (MENDUKUNG MULTI-SHIP DALAM GRUP) ---
          ...dos.map((doItem) {
            final List doDetails = doItem['do_details'] ?? [];
            // PERBAIKAN: Ambil SO dari parent_so (untuk grup) atau fallback ke data['so']
            final String soNum = doItem['parent_so']?.toString() ?? data['so']?.toString() ?? "-";
            final String rddSpesifik = _formatDate(doItem['rdd_origin']);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
          children: [
            Icon(Icons.calendar_month, size: 14, color: Colors.red.shade700),
            const SizedBox(width: 6),
            Text("RDD: $rddSpesifik",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
          ],
        ),
        const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 20),
                      // SO Sekarang akan dinamis sesuai masing-masing shipment
                      Text("SO: $soNum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50, 
                      borderRadius: BorderRadius.circular(6), 
                      border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2), 
                        1: FlexColumnWidth(3), 
                        2: FlexColumnWidth(0.8), 
                        3: FlexColumnWidth(1.3)
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: [
                            _tableCell("ID Mat", isBold: true, isHeader: true),
                            _tableCell("Name", isBold: true, isHeader: true),
                            _tableCell("Qty", isBold: true, align: TextAlign.right, isHeader: true),
                            _tableCell("NW (Kg)", isBold: true, align: TextAlign.right, isHeader: true),
                          ],
                        ),
                        ...doDetails.map((det) {
                          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
                          var matSource = det['material'];
                          Map<String, dynamic>? matData;
                          
                          if (matSource is List && matSource.isNotEmpty) {
                            matData = matSource[0];
                          } else if (matSource is Map) {
                            matData = matSource as Map<String, dynamic>;
                          }

                          double unitWeight = double.tryParse(matData?['net_weight']?.toString() ?? "0") ?? 0;
                          
                          return TableRow(
                            children: [
                              _tableCell(matData?['material_id']?.toString() ?? "-"),
                              _tableCell(matData?['material_name']?.toString() ?? "-"),
                              _tableCell(qty.toInt().toString(), align: TextAlign.right, isBold: true),
                              _tableCell((qty * unitWeight).toStringAsFixed(2), align: TextAlign.right),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }


  // Tambahkan Helper ini jika belum ada untuk mendukung parameter isHeader
  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
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
  // // REUSE: Widget Detailed Summary dari kode AssignVendorPage Anda
  // Widget _buildDetailedSummary() {
  //   final data = _shippingData ?? {};
  //   final List dos = data['delivery_order'] ?? [];

  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       border: Border(left: BorderSide(color: Colors.red.shade700, width: 6)),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   const Text("🚚 SHIPMENT DETAIL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, letterSpacing: 1.1, fontSize: 11)),
  //                   _buildBadge(data['storage_location']?.toString().toUpperCase() ?? "-", Colors.red.shade700),
  //                 ],
  //               ),
  //               const SizedBox(height: 8),
  //               Text("ID Shipping: ${data['shipping_id']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
  //               const SizedBox(height: 16),
  //               Row(
  //                 children: [
  //                   _infoBox("RDD", _formatDate(data['rdd'])),
  //                   _infoBox("Stuffing", _formatDate(data['stuffing_date'])),
  //                   _infoBox("SO", data['so']?.toString() ?? "-"),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         Container(
  //           width: double.infinity,
  //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //           color: Colors.grey.shade100,
  //           child: const Text("ITEM YANG AKAN DIKIRIM", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  //         ),
  //         ...dos.map((doItem) {
  //           final List doDetails = doItem['do_details'] ?? [];
  //           return Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
  //                 Text("👤 ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
  //                 const SizedBox(height: 8),
  //                 Container(
  //                   decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
  //                   child: Table(
  //                     columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(3), 2: FlexColumnWidth(1)},
  //                     children: [
  //                       ...doDetails.map((det) {
  //                         double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
  //                         Map<String, dynamic>? matData = det['material'];
  //                         return TableRow(
  //                           children: [
  //                             _tableCell(matData?['material_id']?.toString() ?? "-", align: TextAlign.center),
  //                             _tableCell(matData?['material_name']?.toString() ?? "-"),
  //                             _tableCell(qty.toInt().toString(), align: TextAlign.right, isBold: true),
  //                           ],
  //                         );
  //                       }).toList(),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           );
  //         }).toList(),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildTimePickerGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 90, vertical: 10),
      
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 2.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _timeSlots.length,
        itemBuilder: (context, index) {
          final time = _timeSlots[index];
        final int booked = _bookedCounts[time] ?? 0;
        final int maxCap = _getMaxCapacity(time);
        final bool isFull = booked >= maxCap;
        final bool isSelected = _selectedTime == time;

final bool isCurrentBooking = widget.oldTime == time;
        // Menghitung sisa slot
  final int remaining = maxCap - booked;
List<String> timeParts = time.split(" - ");
          return InkWell(
  //           onTap: () => setState(() => _selectedTime = time),
  //           child: Container(
  //             decoration: BoxDecoration(
  //               color: isSelected ? Colors.red.shade700 : Colors.white,
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade300),
  //             ),
  //             alignment: Alignment.center,
  //             child: Text(time, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }
  // Jika penuh, onTap dinonaktifkan
          onTap: isFull ? null : () => setState(() => _selectedTime = time),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Warna: Merah (Terpilih), Abu Terang (Penuh), Putih (Tersedia)
              color: isSelected 
                  ? Colors.red.shade700 
                  : (isCurrentBooking 
                ? Colors.yellow.shade100 // Warna berbeda untuk jam yang sedang aktif
                : (isFull ? Colors.grey.shade200 : Colors.white)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected 
                    ? Colors.red 
                    : (isFull ? Colors.grey.shade300 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4)] : null,
            ),
            //alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
             // crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                //const Spacer(),
                // TAMPILAN JAM SEJAJAR KE SAMPING (TANPA -)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(
                      timeParts[0],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isFull ? Colors.grey.shade500 : (isSelected ? Colors.white : Colors.black),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeParts[1],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isFull ? Colors.grey.shade500 : (isSelected ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
              
                // --- BAGIAN YANG DIUBAH MENJADI FORMAT 2/14 ---
          Text(
            isFull ? "FULL" : "$remaining/$maxCap", // Contoh: 2/14
            style: TextStyle(
              fontSize: 16,
              color: isFull 
                  ? Colors.red.shade300 
                  : (isSelected ? Colors.white70 : Colors.green.shade700),
              fontWeight: FontWeight.bold,
              ),
          ),
         const SizedBox(height: 14),
         // const Spacer(),
          //       const Divider(height: 1, indent: 8, endIndent: 8),
                // KETERANGAN CHECK-IN (2 JAM SEBELUM)
                Text(
                    "Check-in Kedatangan:\n${_getCheckInTime(time)}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, // Ukuran kecil agar tidak memenuhi kotak
                      fontStyle: FontStyle.italic,
                      color: isFull ? Colors.grey.shade400 : (isSelected ? Colors.white60 : Colors.blueGrey),
                    ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _getCheckInTime(String timeSlot) {
  // Mengambil jam awal (misal "07:00" dari "07:00 - 09:00")
  String startTimeStr = timeSlot.split(" - ")[0];
  String endTimeStr = timeSlot.split(" - ")[1];

  int startHour = int.parse(startTimeStr.split(":")[0]);
  int endHour = int.parse(endTimeStr.split(":")[0]);

  // Mengurangi 2 jam
  String checkInStart = "${(startHour - 2).toString().padLeft(2, '0')}:00";
  String checkInEnd = "${(endHour - 2).toString().padLeft(2, '0')}:00";

  return "$checkInStart - $checkInEnd";
}

Future<void> _checkAvailability() async {
  try {
   // Kita query ke assignments karena jam_booking ada di sana
    // Kita join ke request untuk memfilter berdasarkan tanggal dan gudang
    // final response = await supabase
    //     .from('shipping_assignments')
    //     .select('jam_booking')
    //     .eq('status_assignment', 'accepted')
    //     .eq('request.stuffing_date', _shippingData!['stuffing_date'])
    //     .eq('request.storage_location', _shippingData!['storage_location'])
    //     .not('jam_booking', 'is', null);

    final response = await supabase
        .from('shipping_assignments')
        .select('''
          jam_booking,
          request:shipping_id (
            stuffing_date,
            warehouse_id
          )
        ''') // <--- PERBAIKAN: Tambahkan request:shipping_id agar bisa difilter
        .eq('status_assignment', 'accepted')
        .eq('request.stuffing_date', _shippingData!['stuffing_date'])
        .eq('request.warehouse_id', _shippingData!['warehouse_id'])
        .not('jam_booking', 'is', null);

    Map<String, int> counts = {};
    for (var row in response) {
      String? time = row['jam_booking'];
      if (time != null) {
        counts[time] = (counts[time] ?? 0) + 1;
      }
    }

    setState(() {
      _bookedCounts = counts;
      _isLoading = false;
    });
  } catch (e) {
    print("Error checking slots: $e");
  }
}

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))]),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
       // onPressed: _selectedTime == null || _isSaving ? null : _confirmAndAccept,
        onPressed: _selectedTime == null || _isSaving 
  ? null 
  : () {
      if (widget.oldTime != null) {
        // JIKA RESCHEDULE, MUNCULKAN POPUP ALASAN
        _showReasonDialog();
      } else {
        // JIKA BOOKING PERTAMA, LANGSUNG SIMPAN
        _confirmAndAccept();
      }
    },
        child: _isSaving 
            ? const CircularProgressIndicator(color: Colors.white)
            :Text(
              // JIKA oldTime ADA (NOT NULL), MAKA TAMPILKAN TEKS RESCHEDULE
              widget.oldTime == null 
                ? "KONFIRMASI JADWAL & TERIMA ORDER" 
                : "KONFIRMASI RESCHEDULE JADWAL", 
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold
              ),
            ),
      ),
    );
  }

// void _showReasonDialog() {
//   _tempSelectedReason = null;
//   showDialog(
//     context: context,
//     builder: (context) => AlertDialog(
//       title: const Text("Alasan Reschedule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: _rescheduleReasons.map((reason) {
//           return ListTile(
//             title: Text(reason),
//             leading: const Icon(Icons.info_outline, color: Colors.red),
//             onTap: () {
//               Navigator.pop(context); // Tutup dialog
//               _confirmAndAccept(rescheduleReasons: reason); // Jalankan simpan dengan alasan
//             },
//           );
//         }).toList(),
//       ),
//       actions: [
//         TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
//       ],
//     ),
//   );
// }

void _showReasonDialog() {
  // Reset pilihan setiap kali dialog dibuka
  _tempSelectedReason = null;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder( // Agar UI di dalam dialog bisa update saat radio diklik
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text(
              "Pilih Alasan Reschedule",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: _rescheduleReasons.map((reason) {
                return RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: _tempSelectedReason,
                  activeColor: Colors.red.shade700,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setStateDialog(() {
                      _tempSelectedReason = value;
                    });
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: _tempSelectedReason == null
                    ? null
                    : () {
                        Navigator.pop(context); // Tutup dialog
                        _confirmAndAccept(rescheduleReasons: _tempSelectedReason);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text("SIMPAN JADWAL BARU", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}
  // REUSE: Helpers dari kode Anda
  Widget _infoBox(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))]));
  /// Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left}) => Padding(padding: const EdgeInsets.all(8), child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
  Widget _buildBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 1)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  String _formatDate(String? s) => s == null || s.isEmpty ? "-" : DateFormat('dd/MM/yy').format(DateTime.parse(s));
}