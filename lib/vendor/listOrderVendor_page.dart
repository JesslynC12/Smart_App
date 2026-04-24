import 'package:flutter/material.dart';
import 'package:project_app/vendor/booking_antrian.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class VendorOrderListPage extends StatefulWidget {
  final String vendorNik; // Menggunakan NIK sesuai penugasan terbaru
  const VendorOrderListPage({super.key, required this.vendorNik});

  @override
  State<VendorOrderListPage> createState() => _VendorOrderListPageState();
}

class _VendorOrderListPageState extends State<VendorOrderListPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _dataList = [];

  DateTimeRange? _selectedDateRange;
  String _dateFilterType = "RDD";

  @override
  void initState() {
    super.initState();
    _fetchVendorOrders();
  }

  Future<void> _fetchVendorOrders() async {
    try {
      setState(() => _isLoading = true);

      // 1. Query ambil dari shipping_assignments dan join ke shipping_request (Flat Table)
      var query = supabase.from('shipping_assignments').select('''
            *,
            request:shipping_id (
              *,
              delivery_order(
                do_number,
                customer(customer_id, customer_name),
                do_details(qty, material(material_id, material_name))
              )
            )
          ''')
          .eq('nik', widget.vendorNik)
          .eq('status_assignment', 'offered'); // Hanya yang baru ditawarkan

      // 2. Filter Tanggal
      if (_selectedDateRange != null) {
        String dateColumn = _dateFilterType == "RDD" ? 'request.rdd' : 'request.stuffing_date';
        query = query
            .gte(dateColumn, _selectedDateRange!.start.toIso8601String())
            .lte(dateColumn, _selectedDateRange!.end.toIso8601String());
      }

      final response = await query.order('assigned_at', ascending: false);
      
      if (mounted) {
        setState(() {
          // Melakukan pemetaan ulang agar struktur data cocok dengan fungsi grouping Anda
          final List<Map<String, dynamic>> flattenedData = (response as List).map((e) {
            final Map<String, dynamic> req = e['request'] as Map<String, dynamic>;
            req['id_assignment'] = e['id_assignment']; // Simpan ID assignment untuk aksi Accept/Reject
            return req;
          }).toList();

          _dataList = _getGroupedDisplayData(flattenedData);
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

  // // --- FUNGSI ACCEPT / REJECT ---
  // Future<void> _updateAssignment(int assignmentId, String status, int shipId) async {
  //   try {
  //     setState(() => _isLoading = true);

  //     // 1. Update tabel penugasan
  //     await supabase.from('shipping_assignments').update({
  //       'status_assignment': status,
  //       'responded_at': DateTime.now().toIso8601String(),
  //     }).eq('id_assignment', assignmentId);

  //     // 2. Update tabel status pengiriman utama
  //     String finalStatus = status == 'accepted' ? 'on process' : 'waiting assign vendor delivery';
  //     await supabase.from('shipping_request').update({
  //       'status': finalStatus,
  //     }).eq('shipping_id', shipId);

  //     _showSnackBar("Berhasil $status order", Colors.green);
  //     _fetchVendorOrders();
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     _showSnackBar("Gagal: $e", Colors.red);
  //   }
  // }

  // --- FUNGSI ACCEPT / REJECT ---
  Future<void> _updateAssignment(int assignmentId, String status, int shipId) async {
    try {
      setState(() => _isLoading = true);

      // 1. Update tabel penugasan (shipping_assignments)
      // Status berubah jadi 'accepted' atau 'rejected'
      await supabase.from('shipping_assignments').update({
        'status_assignment': status,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id_assignment', assignmentId);

      // 2. Tentukan status akhir untuk shipping_request
      String finalStatusRequest;
      if (status == 'accepted') {
        finalStatusRequest = 'on process';
      } else {
        // Logika Reject Anda: Kembali ke antrian pencarian vendor
        finalStatusRequest = 'waiting assign vendor delivery';
      }

      // 3. Update tabel status pengiriman utama (shipping_request)
      // Kita cek dulu apakah ini bagian dari Group atau bukan
      final currentData = _dataList.firstWhere((element) => 
        (element['shipping_id'] == shipId) || 
        (element['grouped_ids'] != null && (element['grouped_ids'] as List).contains(shipId))
      );

      if (currentData['group_id'] != null) {
        // Jika Group, update semua shipping_id yang ada di dalam grup tersebut
        List<int> allIds = List<int>.from(currentData['grouped_ids']);
        await supabase.from('shipping_request').update({
          'status': finalStatusRequest,
          // Opsional: kosongkan vendor_id jika ingin benar-benar reset
          // 'vendor_id': null 
        }).inFilter('shipping_id', allIds);
      } else {
        // Jika bukan group, update satu ID saja
        await supabase.from('shipping_request').update({
          'status': finalStatusRequest,
        }).eq('shipping_id', shipId);
      }

      _showSnackBar("Berhasil $status order", Colors.green);
      _fetchVendorOrders(); // Refresh daftar
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal: $e", Colors.red);
    }
  }

  // --- LOGIKA GROUPING TETAP (TIDAK BERUBAH) ---
  List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
    Map<int, Map<String, dynamic>> groupedMap = {};
    List<Map<String, dynamic>> finalResult = [];

    for (var req in source) {
      final dynamic rawGroupId = req['group_id'];
      if (rawGroupId == null) {
        finalResult.add(Map<String, dynamic>.from(req));
      } else {
        int gId = rawGroupId is String ? int.parse(rawGroupId) : rawGroupId as int;
        if (!groupedMap.containsKey(gId)) {
          groupedMap[gId] = Map<String, dynamic>.from(req);
          groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
          if (groupedMap[gId]!['delivery_order'] != null) {
            for (var doItem in groupedMap[gId]!['delivery_order']) {
              doItem['parent_so'] = req['so']?.toString(); 
            }
          }
        } else {
          groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
          List newDos = List.from(req['delivery_order'] ?? []);
          for (var ndo in newDos) {
            ndo['parent_so'] = req['so']?.toString();
          }
          List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
          currentDos.addAll(newDos);
          groupedMap[gId]!['delivery_order'] = currentDos;
        }
      }
    }
    finalResult.addAll(groupedMap.values);
    finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
    return finalResult;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _dataList.isEmpty 
                ? const Center(child: Text("Tidak ada order baru."))
                : RefreshIndicator(
                    onRefresh: _fetchVendorOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _dataList.length,
                      itemBuilder: (context, index) => _buildVendorCard(_dataList[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS TETAP SAMA PERSIS SESUAI PERMINTAAN ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _dateFilterType,
              decoration: _filterInputDecoration("Berdasarkan"),
              items: ["RDD", "STUFFING"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                setState(() => _dateFilterType = val!);
                if (_selectedDateRange != null) _fetchVendorOrders();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDateRange == null ? "Pilih Tanggal" : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(onPressed: () { setState(() => _selectedDateRange = null); _fetchVendorOrders(); }, icon: const Icon(Icons.refresh, color: Colors.red))
        ],
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> item) {
    final bool isGroup = item['group_id'] != null;
    final List dos = item['delivery_order'] ?? [];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
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
                const Spacer(),
                // Ambil langsung dari item (Flat Table)
                _buildBadge(item['storage_location']?.toString().toUpperCase() ?? "-", Colors.red.shade700),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoText("📅 RDD:", _formatDate(item['rdd'])),
                    _infoText("🚛 Stuffing:", _formatDate(item['stuffing_date'])),
                  ],
                ),
                const Divider(height: 25),
                ...dos.map((doItem) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                              Text("SO: ${doItem['parent_so'] ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                              Flexible(child: Text("${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        Table(
                          columnWidths: const { 0: FlexColumnWidth(1.5), 1: FlexColumnWidth(4), 2: FlexColumnWidth(1) },
                          children: (doItem['do_details'] as List).map((det) => TableRow(
                            children: [
                              _tablePadding(det['material']?['material_id']?.toString() ?? "-"),
                              _tablePadding(det['material']?['material_name'] ?? "-"),
                              _tablePadding(det['qty']?.toString() ?? "0", isBold: true, align: TextAlign.right),
                            ],
                          )).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    //onPressed: () => _updateAssignment(item['id_assignment'], 'rejected', item['shipping_id']), 
                    onPressed: () => _confirmReject(item), 
    
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.red),
      foregroundColor: Colors.red,
    ),
                    child: const Text("REJECT")
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    //onPressed: () => _updateAssignment(item['id_assignment'], 'accepted', item['shipping_id']), 
                    //child: const Text("ACCEPT")
                    onPressed: () {
      // Navigasi ke halaman jadwal dengan membawa ID yang diperlukan
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleSelectionPage(
            assignmentId: item['id_assignment'],
            shippingId: item['shipping_id'],
            onSuccess: () => _fetchVendorOrders(), // Refresh list setelah selesai
          ),
        ),
      );
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: const Text("ACCEPT", style: TextStyle(color: Colors.white)),
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// // --- FUNGSI KONFIRMASI REJECT ---
//   Future<void> _confirmReject(Map<String, dynamic> item) async {
//     // Ambil nama customer dari DO pertama (karena ini grup/single)
//    // final List dos = item['delivery_order'] ?? [];
//     // final String customerName = dos.isNotEmpty 
//     //     ? (dos[0]['customer']?['customer_name'] ?? '-') 
//     //     : '-';
//     final int shipId = item['shipping_id'];

//     return showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//           title: const Text("Konfirmasi Reject", 
//             style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
//           content: Text(
//             "Apakah Anda yakin ingin me-reject order ini?\n\n"
//             "🚢 Ship ID: $shipId\n",
//             // "👤 Tujuan: $customerName",
//             style: const TextStyle(fontSize: 14),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               onPressed: () {
//                 Navigator.pop(context); // Tutup dialog
//                 _updateAssignment(item['id_assignment'], 'rejected', shipId);
//               },
//               child: const Text("YA, REJECT", style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );
//   }

// --- FUNGSI KONFIRMASI REJECT ---
  Future<void> _confirmReject(Map<String, dynamic> item) async {
    final int shipId = item['shipping_id'];
    final bool isGroup = item['group_id'] != null;
    
    // Ambil list customer unik dari DO
    final List dos = item['delivery_order'] ?? [];
    String customers = dos.map((d) => d['customer']?['customer_name'] ?? '-').toSet().join(", ");

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Konfirmasi Reject", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Apakah Anda yakin ingin me-reject order ini?", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 15),
              Text("🚢 ${isGroup ? 'Group ID' : 'Ship ID'}: ${isGroup ? item['group_id'] : shipId}", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("👤 Tujuan: $customers", style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 10),
              const Text("*Order ini akan dikembalikan ke Admin untuk di-assign ulang.", 
                style: TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _updateAssignment(item['id_assignment'], 'rejected', shipId);
              },
              child: const Text("YA, REJECT", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  
  // --- HELPERS (TETAP SAMA) ---
  Widget _infoText(String label, String value) {
    return RichText(text: TextSpan(style: const TextStyle(fontSize: 11, color: Colors.black87), children: [TextSpan(text: "$label "), TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold))]));
  }

  Widget _tablePadding(String text, {bool isBold = false, TextAlign align = TextAlign.left}) {
    return Padding(padding: const EdgeInsets.all(6), child: Text(text, textAlign: align, style: TextStyle(fontSize: 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
  }

  Widget _buildBadge(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color, width: 0.5)), child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)));
  }

  InputDecoration _filterInputDecoration(String label) => InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)));

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime(2100));
    if (picked != null) { setState(() => _selectedDateRange = picked); _fetchVendorOrders(); }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); } catch (e) { return "-"; }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}