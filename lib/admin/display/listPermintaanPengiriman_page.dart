import 'package:flutter/material.dart';
import 'package:project_app/admin/display/assign_vendor_page.dart';
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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String _selectedFilterLoc = "SEMUA";
  DateTimeRange? _selectedDateRange;
String _dateFilterType = "STUFFING"; 
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
  void _initNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

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
      shipId, 
      '🚨 Order Ditolak Vendor!',
      'Vendor $vendorName menolak pesanan #$shipId. Segera cari vendor lain!',
      platformChannelSpecifics,
    );
  }

  void _setupRealtime() {
   
    _realtimeSubscription = supabase
        .from('shipping_request')
        .stream(primaryKey: ['shipping_id'])
        .listen((_) => _fetchVendorTargetData());
       
    _assignmentSubscription = supabase
        .from('shipping_assignments')
        .stream(primaryKey: ['id']) 
        .listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty) {
        final lastUpdate = data.last;
        if (lastUpdate['status_assignment'] == 'rejected') {
         
          _showRejectNotification(
            "Transportasi", 
            lastUpdate['shipping_id'] ?? 0,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
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
            decision_for_unit,
            catatan,
            reason_rejected,
            cancelled_reason,
            vendor_transportasi:id_vendor_details(nik, vendor_name)
          )
          ''').eq('status', 'waiting assign vendor delivery')
         .or(
          'status_assignment.eq.rejected,status_assignment.eq.rejected unit,status_assignment.eq.cancel booking,status_assignment.eq.no response', 
          referencedTable: 'shipping_assignments'
        );
// .filter('vendor_id', 'is', null);
      if (_selectedFilterLoc != "SEMUA") {
        query = query.eq('warehouse_id',int.parse(_selectedFilterLoc));
      }

      if (_selectedDateRange != null) {
      String dateColumn = _dateFilterType == "RDD" ? 'rdd' : 'stuffing_date';
        query = query
           .gte(dateColumn, _selectedDateRange!.start.toIso8601String())
          .lte(dateColumn, _selectedDateRange!.end.toIso8601String());
      }

      final response = await query.order('shipping_id', ascending: false);
      if (mounted) {
      setState(() {
    List<Map<String, dynamic>> rawGrouped = _getGroupedDisplayData(List<Map<String, dynamic>>.from(response));

    for (var item in rawGrouped) {
      Map<String, Map<String, dynamic>> uniqueRejects = {};
    
      List<int> groupShipIds = item['group_id'] != null 
          ? List<int>.from(item['grouped_ids']) 
          : [item['shipping_id']];

      for (var originalRow in (response as List)) {
        if (groupShipIds.contains(originalRow['shipping_id'])) {
          //final List rejects = originalRow['shipping_assignments'] as List? ?? [];
final List assignments = originalRow['shipping_assignments'] as List? ?? [];

      for (var a in assignments) {
        final String statusAss = a['status_assignment']?.toString().toLowerCase() ?? "";
  
  // Daftar status yang dianggap sebagai riwayat kegagalan
  const failedStatuses = ['rejected', 'rejected unit', 'cancel booking', 'no response'];

  if (failedStatuses.contains(statusAss)) {
      
          String vName = a['vendor_transportasi']?['vendor_name'] ?? "Unknown Vendor";
       
    if (statusAss == 'rejected unit') {
      a['reject_type'] = 'INSPEKSI';
    } else if (statusAss == 'no response') {
      a['reject_type'] = 'EXPIRED'; // Tipe baru untuk no response
    } else if (statusAss == 'cancel booking') {
      a['reject_type'] = 'CANCEL';
    } else {
      a['reject_type'] = 'KONFIRMASI';
    }
          uniqueRejects[vName] = a;
        }
      }
        }
      }
    
      item['unique_reject_list'] = uniqueRejects.values.toList();
    }

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
        final Map<String, dynamic> singleData = Map<String, dynamic>.from(req);
        if (singleData['delivery_order'] != null) {
          for (var d in singleData['delivery_order']) {
            d['rdd_origin'] = req['rdd'];
          }
        }
        finalResult.add(singleData);
      } else {
        int gId = req['group_id'];
        if (!groupedMap.containsKey(gId)) {
          groupedMap[gId] = Map<String, dynamic>.from(req);
          groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
        if (groupedMap[gId]!['delivery_order'] != null) {
          for (var doItem in groupedMap[gId]!['delivery_order']) {
            doItem['parent_so'] = req['so']; 
            doItem['rdd_origin'] = req['rdd']; 
          }
        }
      } else {
        groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
        
        List newDos = List.from(req['delivery_order'] ?? []);
        for (var ndo in newDos) {
          ndo['parent_so'] = req['so']; 
          ndo['rdd_origin'] = req['rdd'];
        }

        List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
        currentDos.addAll(newDos);
        groupedMap[gId]!['delivery_order'] = currentDos;
      }
    }
  }
    finalResult.addAll(groupedMap.values);
   
  finalResult.sort((a, b) {
  
    
    bool aIsRejected = (a['unique_reject_list'] as List? ?? []).isNotEmpty;
    bool bIsRejected = (b['unique_reject_list'] as List? ?? []).isNotEmpty;

    if (aIsRejected && !bIsRejected) return -1;
    if (!aIsRejected && bIsRejected) return 1;

    return (b['shipping_id'] as int).compareTo(a['shipping_id'] as int);
  });
    return finalResult;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
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


Widget _buildFilterBar() {
  bool isDateActive = _selectedDateRange != null;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 2),
        )
      ],
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedFilterLoc,
            decoration: _filterInputDecoration("Gudang"),
            style: const TextStyle(fontSize: 11, color: Colors.black),
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

        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: isDateActive ? Colors.red.shade700 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
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
    
final List rejectHistory = item['unique_reject_list'] ?? [];
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
                // const Spacer(),
                // _buildBadge(warehouseDisplay, Colors.red.shade700),
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
                    // _infoText("📅 RDD:", _formatDate(item['rdd'])),
                     //const SizedBox(width: 565),
                     
                    _infoText("🚛 Stuffing:", _formatDate(item['stuffing_date'],)),
                     const SizedBox(width: 60),
                     const Spacer(),
                _buildBadge(warehouseDisplay, Colors.red.shade700),
                  ],
                  
                ),
              const Divider(height: 30),
                // List Table per DO
                ...dos.map((doItem) {
                  final List doDetails = doItem['do_details'] ?? [];
                  final String rddSpesifik = _formatDate(doItem['rdd_origin'] ?? item['rdd']);
                
    return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 6),
                            Text(
                              "RDD: $rddSpesifik",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCE4EC), // Pink sesuai permintaan
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                                  Text("SO: ${doItem['parent_so'] ?? item['so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text("${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", 
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.2),
                                1: FlexColumnWidth(4),
                                2: FlexColumnWidth(1),
                              },
                              children: doDetails.map((det) => TableRow(
                                children: [
                                  _tablePadding(det['material']?['material_id']?.toString() ?? "-"),
                                  _tablePadding(det['material']?['material_name'] ?? "-"),
                                  _tablePadding(det['qty']?.toString() ?? "0", isBold: true, align: TextAlign.right),
                                ],
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                        if (rejectHistory.isNotEmpty) ...[
                          const Divider(height: 1, thickness: 1),
                          Container(
                            padding: const EdgeInsets.all(10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                            color: rejectHistory.any((r) => r['reject_type'] == 'INSPEKSI') 
          ? Colors.red.shade100 
          : Colors.yellow.shade200,
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
            Icon(Icons.report_problem, size: 14, 
                color: rejectHistory.any((r) => r['reject_type'] == 'INSPEKSI') ? Colors.red.shade900 : Colors.orange.shade900),
            const SizedBox(width: 4),
            Text("RIWAYAT PENOLAKAN:", 
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, 
                  color: rejectHistory.any((r) => r['reject_type'] == 'INSPEKSI') ? Colors.red.shade900 : Colors.orange.shade900)),
          ],
        ),
        const SizedBox(height: 6),
        ...rejectHistory.map((rej) {
          String vendorName = rej['vendor_transportasi']?['vendor_name'] ?? "Unknown Vendor";
          
String typeText = "";
String status = rej['status_assignment']?.toString().toLowerCase() ?? "";
 
  if (status == 'rejected unit') {
    typeText = "UNIT DITOLAK SAAT CHECK-IN";
    if (rej['catatan'] != null && rej['catatan'].toString().isNotEmpty) {
      typeText += " - ${rej['catatan']}";
    }
  } 
  else if (status == 'no response') {
    typeText = "tidak merespon penugasan hingga batas waktu.";
  }
  else if (status == 'cancel booking') {
   typeText = "BOOKING DIBATALKAN";
   var alasanCancel = rej['cancelled_reason'] ?? rej['catatan'];
    if (alasanCancel != null && alasanCancel.toString().isNotEmpty) {
      typeText += " - $alasanCancel";
    }
  } 
  else {
    typeText = "VENDOR MENOLAK ORDER";
    if (rej['reason_rejected'] != null && rej['reason_rejected'].toString().isNotEmpty) {
      typeText += " - ${rej['reason_rejected']}";
    }
  }
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              status == 'no response' 
          ? "• Vendor ($vendorName) $typeText" 
          : "• $vendorName: $typeText",        
      style: TextStyle(
        fontSize: 10, 
        color: (status == 'rejected unit' || status == 'no response') 
            ? Colors.red.shade800 
            : Colors.black87,
        fontWeight: (status == 'rejected unit' || status == 'no response') 
            ? FontWeight.bold 
            : FontWeight.normal
              ),
            ),
          );
        }),
                             ],
                  ),
                ),
              ],
            ],
          ),
        ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
               onPressed: () {
   
  final groupId = item['group_id'];
  final shipId = item['shipping_id'];
  
  String tabTitle;
  if (groupId != null) {
    tabTitle = "Assign Vendor Grup #$groupId";
  } else {
    tabTitle = "Assign Vendor Shipping #$shipId";
  }

  DynamicTabPage.of(context)?.openTab(
    tabTitle, 
    AssignVendorPage(shippingId: shipId),
  );
},
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: Text(
                 
                "PROSES PERMINTAAN VENDOR",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color, width: 0.5)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _filterInputDecoration(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)));

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.done_all, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text("Semua data sudah diproses", style: TextStyle(color: Colors.grey))]));

  Future<void> _pickDateRange() async {
  DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2023),
    lastDate: DateTime(2100),
    initialDateRange: _selectedDateRange,
    locale: const Locale('id', 'ID'), 
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.red.shade700, 
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400, 
              maxHeight: 550, 
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