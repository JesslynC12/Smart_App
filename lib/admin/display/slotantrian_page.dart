import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QueueSlotPage extends StatefulWidget {
  const QueueSlotPage({super.key});

  @override
  State<QueueSlotPage> createState() => _QueueSlotPageState();
}

class _QueueSlotPageState extends State<QueueSlotPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  DateTime _selectedDate = DateTime.now();
RealtimeChannel? _assignmentsChannel;
  RealtimeChannel? _requestsChannel;

  final List<String> _timeSlots = [
    '07:00 - 09:00',
    '09:00 - 11:00',
    '11:00 - 13:00',
    '13:00 - 15:00',
    '15:00 - 17:00',
    '17:00 - 19:00',
    '19:00 - 21:00',
    '21:00 - 23:00',
  ];

  final List<Map<String, dynamic>> _warehouses = [
    {
      'warehouse_id': 1,
      'warehouse_name': 'GBJ CO CHIYODA',
    },
    {
      'warehouse_id': 2,
      'warehouse_name': 'GBJ KUNCIMAS',
    },
    {
      'warehouse_id': 3,
      'warehouse_name': 'GBJ MARSHO VNA',
    },
  ];

  /// format:
  ///
  /// {
  ///   "1_07:00 - 09:00": {
  ///      "booked": 4,
  ///      "max": 8,
  ///      "vendors": ["PT ABC", "PT MAJU"]
  ///   }
  /// }
  Map<String, dynamic> _slotData = {};

 @override
  void initState() {
    super.initState();
    // Memuat data awal dengan loading spinner
    _loadSlotData(showGlobalLoading: true);
    // Jalankan sistem pendengar realtime
    _initRealtimeStreams();
  }

  @override
  void dispose() {
    // Hapus channel agar tidak memory leak
    _assignmentsChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    if (_assignmentsChannel != null) supabase.removeChannel(_assignmentsChannel!);
    if (_requestsChannel != null) supabase.removeChannel(_requestsChannel!);
    super.dispose();
  }
void _initRealtimeStreams() {
    // 1. Listen perubahan pada penugasan
    _assignmentsChannel = supabase
        .channel('queue_slot_assignments_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_assignments',
          callback: (payload) async {
            debugPrint("Realtime Update: Perubahan slot terdeteksi");
            // Refresh data diam-diam tanpa loading spinner
            await _loadSlotData(showGlobalLoading: false);
          },
        )
        .subscribe();

    // 2. Listen perubahan pada request utama
    _requestsChannel = supabase
        .channel('queue_slot_requests_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_request',
          callback: (payload) async {
            await _loadSlotData(showGlobalLoading: false);
          },
        )
        .subscribe();
  }
  int _getMaxCapacity(int warehouseId, String timeSlot) {
    bool isRestTime = timeSlot == '11:00 - 13:00';

    if (warehouseId == 1) {
      return isRestTime ? 4 : 8;
    } else if (warehouseId == 2) {
      return isRestTime ? 1 : 3;
    } else if (warehouseId == 3) {
      return isRestTime ? 2 : 4;
    }

    return 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });

      _loadSlotData();
    }
  }

  // Future<void> _loadSlotData() async {
  //   try {
  //     setState(() => _isLoading = true);

  //     String filterDate =
  //         DateFormat('yyyy-MM-dd').format(_selectedDate);

  //     final response = await supabase
  //         .from('shipping_assignments')
  //         .select('''
  //           jam_booking,
  //           nik,
  //           master_vendor(vendor_name),
  //           request:shipping_id(
  //             shipping_id,
  //             group_id,
  //             warehouse_id,
  //             stuffing_date
  //           )
  //         ''')
  //         .eq('status_assignment', 'accepted')
  //         .eq('request.stuffing_date', filterDate)
  //         .not('jam_booking', 'is', null);

  //     Map<String, dynamic> tempData = {};

  //     /// untuk hitung unique vehicle
  //     Map<String, Set<String>> uniqueVehicles = {};

  //     /// untuk simpan vendor
  //     Map<String, List<String>> vendorLists = {};

  //     for (var row in response) {
  //       final request = row['request'];

  //       if (request == null) continue;

  //       final int warehouseId = request['warehouse_id'];
  //       final String? timeSlot = row['jam_booking'];

  //       if (timeSlot == null) continue;

  //       String key = '${warehouseId}_$timeSlot';

  //       /// identitas kendaraan unik
  //       String vehicleKey = request['group_id'] != null
  //           ? 'GRP_${request['group_id']}'
  //           : 'SHIP_${request['shipping_id']}';

  //       if (!uniqueVehicles.containsKey(key)) {
  //         uniqueVehicles[key] = {};
  //       }

  //       uniqueVehicles[key]!.add(vehicleKey);

  //       /// vendor
  //       String vendorName = '-';

  //       if (row['master_vendor'] != null) {
  //         vendorName =
  //             row['master_vendor']['vendor_name'] ?? '-';
  //       }

  //       if (!vendorLists.containsKey(key)) {
  //         vendorLists[key] = [];
  //       }

  //       if (!vendorLists[key]!.contains(vendorName)) {
  //         vendorLists[key]!.add(vendorName);
  //       }
  //     }

  //     /// build final data
  //     for (var warehouse in _warehouses) {
  //       int warehouseId = warehouse['warehouse_id'];

  //       for (String slot in _timeSlots) {
  //         String key = '${warehouseId}_$slot';

  //         int booked =
  //             uniqueVehicles[key]?.length ?? 0;

  //         int maxCap =
  //             _getMaxCapacity(warehouseId, slot);

  //         tempData[key] = {
  //           'booked': booked,
  //           'max': maxCap,
  //           'vendors': vendorLists[key] ?? [],
  //         };
  //       }
  //     }

  //     setState(() {
  //       _slotData = tempData;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() => _isLoading = false);

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text("Error: $e"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }
Future<void> _loadSlotData({bool showGlobalLoading = false}) async {
  try {
    if (showGlobalLoading) {
        setState(() => _isLoading = true);
      }
    String filterDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final response = await supabase
        .from('shipping_assignments')
        .select('''
          jam_booking,
          nik,
          status_assignment,
          master_vendor(vendor_name),
          request:shipping_id(
            shipping_id,
            group_id,
            warehouse_id,
            stuffing_date,
            delivery_order(
              do_number,
              customer(customer_name)
            )
          )
        ''')
       // .eq('status_assignment', 'accepted')
       .inFilter('status_assignment', ['accepted', 'check in', 'loading', 'kelayakan unit', 'weighbridge','keluar'])
        .eq('request.stuffing_date', filterDate)
        .not('jam_booking', 'is', null);

    Map<String, dynamic> tempData = {};
    Map<String, Set<String>> uniqueVehicles = {};
    // Simpan objek detail booking
    Map<String, List<Map<String, dynamic>>> bookingDetails = {};

    for (var row in response) {
      final request = row['request'];
      if (request == null) continue;

      final int warehouseId = request['warehouse_id'];
      final String? timeSlot = row['jam_booking'];
      if (timeSlot == null) continue;

      String key = '${warehouseId}_$timeSlot';
      String vehicleKey = request['group_id'] != null
          ? 'GRP_${request['group_id']}'
          : 'SHIP_${request['shipping_id']}';

      if (!uniqueVehicles.containsKey(key)) uniqueVehicles[key] = {};
      
      // Jika kendaraan ini belum tercatat di slot ini, masukkan detailnya
      if (!uniqueVehicles[key]!.contains(vehicleKey)) {
        uniqueVehicles[key]!.add(vehicleKey);

        String vendorName = row['master_vendor']?['vendor_name'] ?? '-';
        
        // Ambil list DO dan Customer (Unique)
        List doList = request['delivery_order'] ?? [];
        String doNumbers = doList.map((e) => e['do_number']).join(", ");
        String customers = doList.map((e) => e['customer']?['customer_name'] ?? '-').toSet().join(", ");

        if (!bookingDetails.containsKey(key)) bookingDetails[key] = [];
        bookingDetails[key]!.add({
          'vendor': vendorName,
          'customer': customers,
          'id': vehicleKey,
          'dos': doNumbers,
          'status': row['status_assignment'], // SIMPAN STATUS DI SINI
        });
      }
    }

    for (var warehouse in _warehouses) {
      for (String slot in _timeSlots) {
        int whId = warehouse['warehouse_id'];
        String key = '${whId}_$slot';
        tempData[key] = {
          'booked': uniqueVehicles[key]?.length ?? 0,
          'max': _getMaxCapacity(whId, slot),
          'details': bookingDetails[key] ?? [],
        };
      }
    }

    setState(() {
      _slotData = tempData;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    debugPrint("Error: $e");
  }
}
  // Color _getSlotColor(int booked, int max) {
  //   if (booked >= max) {
  //     return Colors.red.shade200;
  //   }

  //   int remaining = max - booked;

  //   if (remaining <= 2) {
  //     return Colors.orange.shade100;
  //   }

  //   return Colors.green.shade100;
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Table(
                          border: TableBorder.all(
                            color: Colors.grey.shade400,
                          ),
                          defaultColumnWidth:
                              const FixedColumnWidth(320),
                          children: [
                            _buildHeaderRow(),
                            ..._timeSlots.map(
                              (slot) => _buildTimeRow(slot),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // const Text(
          //   "SLOT ANTRIAN GUDANG",
          //   style: TextStyle(
          //     fontSize: 20,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              DateFormat('dd MMM yyyy')
                  .format(_selectedDate),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _loadSlotData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.red.shade700,
      ),
      children: [
        _headerCell("Jam"),
        ..._warehouses.map(
          (e) => _headerCell(e['warehouse_name']),
        ),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  // TableRow _buildTimeRow(String slot) {
  //   return TableRow(
  //     children: [
  //       Container(
  //         height: 180,
  //         alignment: Alignment.center,
  //         color: Colors.grey.shade200,
  //         child: Text(
  //           slot,
  //           style: const TextStyle(
  //             fontWeight: FontWeight.bold,
  //             fontSize: 16,
  //           ),
  //         ),
  //       ),

  //       ..._warehouses.map((warehouse) {
  //         int warehouseId = warehouse['warehouse_id'];

  //         String key = '${warehouseId}_$slot';

  //         final data = _slotData[key];

  //         int booked = data['booked'];
  //         int max = data['max'];

  //         int remaining = max - booked;

  //         List vendors =
  //             List<String>.from(data['vendors']);

  //         bool isFull = booked >= max;

  //         return GestureDetector(
  //           onTap: () {
  //             _showDetailDialog(
  //               warehouse['warehouse_name'],
  //               slot,
  //               vendors,
  //               remaining,
  //               booked,
  //               max,
  //             );
  //           },
  //           child: Container(
  //             height: 180,
  //             padding: const EdgeInsets.all(12),
  //             //color: _getSlotColor(booked, max),
  //             child: Column(
  //               crossAxisAlignment:
  //                   CrossAxisAlignment.start,
  //               children: [
  //                 Row(
  //                   children: [
  //                     Icon(
  //                       isFull
  //                           ? Icons.close
  //                           : Icons.check_circle,
  //                       color: isFull
  //                           ? Colors.red
  //                           : Colors.green,
  //                     ),
  //                     const SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         isFull
  //                             ? "FULL"
  //                             : "Sisa Slot: $remaining",
  //                         style: TextStyle(
  //                           fontWeight:
  //                               FontWeight.bold,
  //                           fontSize: 16,
  //                           color: isFull
  //                               ? Colors.red.shade900
  //                               : Colors.green.shade900,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),

  //                 const SizedBox(height: 12),

  //                 Text(
  //                   "Terisi $booked/$max",
  //                   style: const TextStyle(
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),

  //                 const Divider(),

  //                 const Text(
  //                   "Booking:",
  //                   style: TextStyle(
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),

  //                 const SizedBox(height: 6),

  //                 Expanded(
  //                   child: vendors.isEmpty
  //                       ? const Text("-")
  //                       : ListView.builder(
  //                           itemCount: vendors.length,
  //                           itemBuilder:
  //                               (context, index) {
  //                             return Padding(
  //                               padding:
  //                                   const EdgeInsets.only(
  //                                 bottom: 4,
  //                               ),
  //                               child: Text(
  //                                 "• ${vendors[index]}",
  //                                 style:
  //                                     const TextStyle(
  //                                   fontSize: 13,
  //                                 ),
  //                               ),
  //                             );
  //                           },
  //                         ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         );
  //       }),
  //     ],
  //   );
  // }

TableRow _buildTimeRow(String slot) {
  return TableRow(
    children: [
      // Kolom Jam Operasional
      Container(
        height: 180,
        alignment: Alignment.center,
        color: Colors.grey.shade200,
        child: Text(
          slot,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      // Kolom Data per Gudang
      ..._warehouses.map((warehouse) {
        int warehouseId = warehouse['warehouse_id'];
        String key = '${warehouseId}_$slot';

        // Mengambil data slot (booked, max, details)
        final data = _slotData[key] ?? {
          'booked': 0,
          'max': _getMaxCapacity(warehouseId, slot),
          'details': [],
        };

        int booked = data['booked'];
        int max = data['max'];
        int remaining = max - booked;
        List<Map<String, dynamic>> details = List<Map<String, dynamic>>.from(data['details']);
        bool isFull = booked >= max;

        return GestureDetector(
            onTap: () => _showDetailDialog(warehouse['warehouse_name'], slot, details, remaining, booked, max),
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(12),
              color: isFull ? Colors.red.withOpacity(0.05) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isFull ? Icons.block : Icons.check_circle, size: 16, color: isFull ? Colors.red : Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFull ? "FULL" : "Sisa Slot: $remaining",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isFull ? Colors.red.shade900 : Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Terisi $booked/$max", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const Divider(height: 16),
                  Expanded(
                    child: details.isEmpty
                        ? const Text("-", style: TextStyle(fontSize: 10, color: Colors.grey))
                        : ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: details.length,
                            itemBuilder: (context, i) {
                              //itemBuilder: (context, i) {
  final String rawStatus = details[i]['status'] ?? '';
  // Logika warna status
  Color statusColor = rawStatus == 'accepted' ? Colors.grey : Colors.blue.shade700;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
        children: [
          Expanded(
            child: Text(
              "• ${details[i]['vendor']}",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6), // Beri jarak sedikit antara teks dan status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor, width: 0.5),
            ),
            child: Text(
              rawStatus.toUpperCase(),
              style: TextStyle(
                fontSize: 8, 
                fontWeight: FontWeight.bold, 
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 1), // Jarak tipis antara nama vendor dan tujuan
      Text(
        "  Tujuan: ${details[i]['customer']}",
        style: const TextStyle(fontSize: 10, color: Colors.black54),
        overflow: TextOverflow.ellipsis,
      ),
  
            //                         Text("• ${details[i]['vendor']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            //                         Text("  Tujuan: ${details[i]['customer']}", style: const TextStyle(fontSize: 10, color: Colors.black54), overflow: TextOverflow.ellipsis),
            //                         Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            //   decoration: BoxDecoration(
            //     color: statusColor.withOpacity(0.1),
            //     borderRadius: BorderRadius.circular(4),
            //     border: Border.all(color: statusColor, width: 0.5),
            //   ),
            //   child: Text(rawStatus.toUpperCase(), 
            //     style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor)),
            // ),
          ],
        ),
                              );
                              },
                          
                            ),
                  ),
                                  ],
                                ),
                              ),
        );
        }).toList(),
                            
    ],
  );             
  }

    void _showDetailDialog(String warehouse, String slot, List<Map<String, dynamic>> details, int remaining, int booked, int max) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            "$warehouse\n$slot",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Terisi: $booked/$max",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Sisa Slot: $remaining",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remaining <= 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),

                const Divider(height: 24),
const Text("Daftar Booking:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (details.isEmpty)
                  const Text("- Belum ada booking")
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: details.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final d = details[i];
                        final String status = d['status'] ?? '-';
                        // Logika warna status agar konsisten
                      Color statusColor = status == 'accepted' ? Colors.grey : Colors.blue.shade700;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
//                             Text("${d['vendor']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
//                             // BADGE STATUS DI DIALOG
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//             decoration: BoxDecoration(
//               color: status == 'accepted' ? Colors.grey.shade200 : Colors.blue.shade100,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Text(
//               status == 'accepted' ? "BELUM TIBA" : status.toUpperCase(),
//               style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, 
//                 color: status == 'accepted' ? Colors.grey.shade700 : Colors.blue.shade900),
//             ),
//           ),
        
      
//                             const SizedBox(height: 4),
//                             Text("ID: ${d['id']}", style: const TextStyle(fontSize: 11)),
//                             Text("Tujuan: ${d['customer']}", style: const TextStyle(fontSize: 11)),
//                             Text("DO: ${d['dos']}", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
//                           ],
//                         );
//                       },
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
//           ],
//         );
//       },
//     );
//   }
// }

Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${d['vendor']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor, width: 0.5),
                                ),
                                child: Text(
                                  status == 'accepted' ? "BELUM TIBA" : status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text("ID: ${d['id']}", style: const TextStyle(fontSize: 11)),
                          Text("Tujuan: ${d['customer']}", style: const TextStyle(fontSize: 11)),
                          Text("DO: ${d['dos']}",
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey)),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
        ],
      );
    },
  );
  }
}

//        // actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup"))],
//       );
      
//     },
//   );
// }

//                 if (vendors.isEmpty)
//                   const Text("- Belum ada booking")
//                 else
//                   ...vendors.map(
//                     (e) => Padding(
//                       padding:
//                           const EdgeInsets.only(
//                         bottom: 6,
//                       ),
//                       child: Text("• $e"),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: const Text("Tutup"),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }