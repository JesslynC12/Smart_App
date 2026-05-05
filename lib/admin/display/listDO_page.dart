import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' as io; // Gunakan prefix io untuk Mobile
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html; // Untuk Web
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class ListDOPage extends StatefulWidget {
  const ListDOPage({super.key});

  @override
  State<ListDOPage> createState() => _ListDOPageState();
}

class _ListDOPageState extends State<ListDOPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription? _realtimeSubscription;
  bool _isLoading = true;
  String _dateFilterType = "RDD"; // Default filter
  String? userDisplayName;

final ScrollController _horizontalController = ScrollController();
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  String _searchQuery = "";
DateTimeRange? _selectedDateRange;
  
  // Menggunakan Set<String> untuk menyimpan kunci unik "shippingId_doNumber"
  //final Set<String> _selectedKeys = {}; 
  final Set<int> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchShippingRequests();
    _setupRealtime();
  }

void _setupRealtime() {
    // Kita buat subscription untuk memantau perubahan status atau penambahan data
    _realtimeSubscription = supabase
        .from('shipping_request')
        .stream(primaryKey: ['shipping_id'])
        .listen((_) {
          // Setiap kali ada perubahan (insert/update/delete) di DB,
          // kita panggil fungsi fetch untuk memperbarui List dan Grouping.
          _fetchShippingRequests(); 
        });
  }

// Future<void> _importMassalTigaTabel() async {
//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['xlsx'],
//         withData: true,
//       );

//       if (result == null || result.files.isEmpty) return;

//       setState(() => _isLoading = true);
//       final bytes = result.files.first.bytes;
//       var excel = Excel.decodeBytes(bytes!);
//       var sheet = excel.tables.values.first;

//       Map<String, List<Map<String, dynamic>>> groupedByDO = {};
      
//       for (int i = 1; i < sheet.maxRows; i++) {
//         var row = sheet.rows[i];
//         if (row.length < 14 || row[2]?.value == null) continue; 

//         String doNum = row[2]!.value.toString().trim();
//         if (!groupedByDO.containsKey(doNum)) groupedByDO[doNum] = [];

//         groupedByDO[doNum]!.add({
//           "so": row[3]?.value.toString() ?? "",
//           "cust_id": int.tryParse(row[4]?.value.toString() ?? ""),
//           "mat_id": int.tryParse(row[6]?.value.toString() ?? ""),
//           "qty": int.tryParse(row[9]?.value.toString() ?? "0"),
//           "rdd": row[12]?.value.toString(),
//           "stuffing": row[13]?.value.toString(),
//         });
//       }

//       for (var entry in groupedByDO.entries) {
//         String doNumber = entry.key;
//         var items = entry.value;
//         var firstItem = items.first;

//         String rddRaw = firstItem['rdd']?.toString() ?? '';
//         String stuffingRaw = firstItem['stuffing']?.toString() ?? '';

//         if (rddRaw.contains(" ")) rddRaw = rddRaw.split(" ")[0];
//         if (stuffingRaw.contains(" ")) stuffingRaw = stuffingRaw.split(" ")[0];

//         final shipRes = await supabase.from('shipping_request').insert({
//           'so': firstItem['so'],
//           'status': 'waiting approval',
//           'rdd': DateTime.tryParse(rddRaw)?.toIso8601String(),
//           'stuffing_date': DateTime.tryParse(stuffingRaw)?.toIso8601String(),
//           'created_by': userDisplayName?? 'System Import',
//         }).select().single();

//         final int newShipId = shipRes['shipping_id'];

//         final doRes = await supabase.from('delivery_order').insert({
//           'shipping_id': newShipId,
//           'do_number': doNumber,
//           'customer_id': firstItem['cust_id'],
//         }).select().single();

//         final int newDoId = doRes['do_id'];

//         List<Map<String, dynamic>> detailsToInsert = items.map((item) => {
//           'do_id': newDoId,
//           'material_id': item['mat_id'],
//           'qty': item['qty'],
//         }).toList();

//         await supabase.from('do_details').insert(detailsToInsert);
//       }

//       _showSnackBar("Berhasil import massal 3 tabel sekaligus!", Colors.green);
//       _fetchShippingRequests();

//     } catch (e) {
//       _showSnackBar("Gagal Import Massal: $e", Colors.red);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

@override
  void dispose() {
    _horizontalController.dispose();
    _realtimeSubscription?.cancel(); // WAJIB: Batalkan subscription agar tidak memory leak
    _searchController.dispose();
    super.dispose();
  }

Future<void> _importMassalTigaTabel() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isLoading = true);
    final bytes = result.files.first.bytes;
    var excel = Excel.decodeBytes(bytes!);
    var sheet = excel.tables.values.first;

    // --- LANGKAH 1: Kelompokkan Data Excel ---
    Map<String, List<Map<String, dynamic>>> groupedByDO = {};
    
    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      
      // Validasi: Cek apakah baris kosong atau No DO (Indeks 0) kosong
      if (row.isEmpty || row[0]?.value == null) continue;

      String doNum = row[0]!.value.toString().trim();
      if (!groupedByDO.containsKey(doNum)) groupedByDO[doNum] = [];

      groupedByDO[doNum]!.add({
        "so": row[1]?.value?.toString().trim() ?? "",
        "cust_id": int.tryParse(row[2]?.value?.toString() ?? ""),
        "mat_id": int.tryParse(row[3]?.value?.toString() ?? ""),
        "qty": int.tryParse(row[4]?.value?.toString() ?? "0"),
        "rdd": row[5]?.value?.toString(),
        "stuffing": row[6]?.value?.toString(), // Jika ada di kolom G
      });
    }

    // --- LANGKAH 2: Eksekusi ke Database ---
    for (var entry in groupedByDO.entries) {
      String doNumber = entry.key;
      var items = entry.value;
      var firstItem = items.first;

// 1. CEK APAKAH NO DO SUDAH ADA DI DATABASE
  final existingDO = await supabase
      .from('delivery_order')
      .select('do_id, shipping_id')
      .eq('do_number', doNumber)
      .maybeSingle();

  if (existingDO != null) {
    // JIKA SUDAH ADA, TAMPILKAN PESAN ATAU LANJUTKAN KE DO BERIKUTNYA
    print("No DO $doNumber sudah ada, melewati baris ini.");
    continue; // Melewati No DO ini agar tidak duplikat
  }
  
      // Bersihkan tanggal
      String rddRaw = firstItem['rdd']?.toString() ?? '';
      //String? stuffingFinal = formatTanggal(firstItem['stuffing']);
      String stuffing = firstItem['stuffing']?.toString() ?? '';
      if (rddRaw.contains(" ")) rddRaw = rddRaw.split(" ")[0];

      // A. Insert ke SHIPPING_REQUEST (Ship_ID otomatis dibuat DB)
      final shipRes = await supabase.from('shipping_request').insert({
        'so': firstItem['so'],
        'status': 'waiting approval',
        'rdd': DateTime.tryParse(rddRaw)?.toIso8601String(),
        'stuffing_date': stuffing, // Sudah format ISO
        'created_by': userDisplayName ?? 'System Import',
        // 'group_id' sengaja tidak diisi agar jadi single data
      }).select().single();

      final int newShipId = shipRes['shipping_id'];

      // B. Insert ke DELIVERY_ORDER
      final doRes = await supabase.from('delivery_order').insert({
        'shipping_id': newShipId,
        'do_number': doNumber,
        'customer_id': firstItem['cust_id'],
      }).select().single();

      final int newDoId = doRes['do_id'];

      // C. Insert ke DO_DETAILS (Bulk Insert)
      List<Map<String, dynamic>> detailsToInsert = items.map((item) => {
        'do_id': newDoId,
        'material_id': item['mat_id'],
        'qty': item['qty'],
      }).toList();

      await supabase.from('do_details').insert(detailsToInsert);
    }

    _showSnackBar("Berhasil import data!", Colors.green);
    _fetchShippingRequests();

  } catch (e) {
    debugPrint("Error: $e");
    _showSnackBar("Gagal: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

Future<void> _fetchShippingRequests() async {
  try {
    //setState(() => _isLoading = true);
    if (_allRequests.isEmpty) {
      setState(() => _isLoading = true);
    }
    final response = await supabase
        .from('shipping_request')
        .select('''
          *,
          group_id,
          delivery_order (
            do_number,
            customer (customer_id, customer_name),
            do_details (details_id, qty, material (material_id, material_name, material_type, net_weight))
          ),
      shipping_pending_history (
      shipping_id,
        reason,
        pending_at
      )
        ''')
        // .eq('status', 'waiting approval',) 
        .inFilter('status', ['waiting approval', 'pending'])
        .order('shipping_id', ascending: false);

    List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
if (mounted) {
    setState(() {
      _allRequests = data;
      _filteredRequests = _allRequests;
      _runFilter(_searchController.text);
      _isLoading = false;
      _selectedIds.clear();
    });
}
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal ambil data: $e", Colors.red);
    print("Error Detail: $e");
  }
}

Future<void> _updateQtyMaterial(int detailsId, double newQty) async {
  try {
    await supabase
        .from('do_details')
        .update({'qty': newQty})
        .eq('details_id', detailsId);
  } catch (e) {
    rethrow;
  }
}

void _editShippingRequest(Map<String, dynamic> req) async {
  final bool isGroup = req['group_id'] != null;
  final List<int> idsToUpdate = isGroup 
      ? List<int>.from(req['grouped_ids']) 
      : [req['shipping_id'] as int];

Map<int, TextEditingController> soController = {};
  //final TextEditingController soController = TextEditingController(text: req['so']?.toString() ?? "");
  // List untuk menampung controller qty setiap material
  // Format: { 'details_id': controller }
  Map<int, TextEditingController> qtyControllers = {};
// Inisialisasi Data
  if (isGroup) {
    // Jika grup, kita perlu mencari SO asli dari masing-masing shipping_id
    // Kita bisa ambil dari data yang sudah di-fetch sebelumnya (_allRequests)
    for (int sId in idsToUpdate) {
      var originalReq = _allRequests.firstWhere((element) => element['shipping_id'] == sId);
      soController[sId] = TextEditingController(text: originalReq['so']?.toString() ?? "");
    }
  } else {
    soController[req['shipping_id']] = TextEditingController(text: req['so']?.toString() ?? "");
  }

  // Inisialisasi controller untuk setiap material yang ada di dalam request/group ini
  final List dos = req['delivery_order'] ?? [];
  for (var d in dos) {
    for (var det in d['do_details']) {
      int detId = det['details_id'];
      qtyControllers[detId] = TextEditingController(text: det['qty'].toString());
    }
  }

 DateTime? selectedRDD = req['rdd'] != null ? DateTime.tryParse(req['rdd'].toString()) : null;
  DateTime? selectedStuffing = req['stuffing_date'] != null ? DateTime.tryParse(req['stuffing_date'].toString()) : null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 20, right: 20, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isGroup ? "Edit Grup (ID: ${req['group_id']})" : "Edit Shipping Request", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            const Divider(),
            
            // --- BAGIAN HEADER (SO & TANGGAL) ---
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // if (!isGroup) ...[
                    //   const SizedBox(height: 10),
                    //   TextField(
                    //     controller: soController, 
                    //     decoration: const InputDecoration(
                    //       labelText: "Nomor SO",
                    //       isDense: true,
                    //       border: OutlineInputBorder(),
                    //       prefixIcon: Icon(Icons.assignment),
                    //     ),
                    //   ),
                    // ],
                    // --- SEKSI EDIT SO ---
                    const Align(alignment: Alignment.centerLeft, child: Text("Nomor SO:", style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    ...soController.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: isGroup ? "SO untuk Ship ID ${entry.key}" : "Nomor SO",
                            isDense: true,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.assignment, size: 20),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildDateTile("RDD", selectedRDD, (date) => setModalState(() => selectedRDD = date)),
                        const SizedBox(width: 10),
                        _buildDateTile("Stuffing", selectedStuffing, (date) => setModalState(() => selectedStuffing = date)),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Daftar Material (Edit Qty):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 10),

                    // --- BAGIAN EDIT QTY MATERIAL ---
                    ...dos.expand((d) {
                      return (d['do_details'] as List).map((det) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300)
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(det['material']?['material_name'] ?? "Unknown Material", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text("DO: ${d['do_number']}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: qtyControllers[det['details_id']],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    labelText: "Qty",
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                    }).toList(),
                  ],
                ),
              ),
            ),

            // --- TOMBOL SIMPAN ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), 
                  backgroundColor: Colors.blue.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () async {
                  try {
                    //setState(() => _isLoading = true);
                    
                    // 1. Update SO per Shipping Request
                    for (var entry in soController.entries) {
                      await supabase
                          .from('shipping_request')
                          .update({
                            'so': entry.value.text,
                            'rdd': selectedRDD?.toIso8601String(),
                            'stuffing_date': selectedStuffing?.toIso8601String(),
                          })
                          .eq('shipping_id', entry.key);
                    }
                   
                    // 2. Update Semua Qty Material di Tabel do_details
                    for (var entry in qtyControllers.entries) {
                      double? newQty = double.tryParse(entry.value.text);
                      if (newQty != null) {
                        await _updateQtyMaterial(entry.key, newQty);
                      }
                    }
                   

                    Navigator.pop(context);
                    _showSnackBar("Data dan Qty Berhasil Diperbarui!", Colors.green);
                    _fetchShippingRequests();
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showSnackBar("Gagal Update: $e", Colors.red);
                  }
                },
                child: const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper widget untuk date picker di modal
Widget _buildDateTile(String label, DateTime? date, Function(DateTime) onPick) {
  return Expanded(
    child: InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context, 
          initialDate: date ?? DateTime.now(), 
          firstDate: DateTime(2020), lastDate: DateTime(2100)
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.blue)),
            Text(date == null ? "-" : DateFormat('dd/MM/yyyy').format(date),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

Future<void> _createAndAssignGroup() async {
  if (_selectedIds.length < 2) {
    _showSnackBar("Pilih minimal 2 data untuk digrup", Colors.orange);
    return;
  }

// --- LOGIKA PENGECEKAN MULAI DISINI ---
  // Cari apakah ada data terpilih yang group_id-nya sudah terisi (bukan null)
  final alreadyGrouped = _allRequests.where((req) => 
      _selectedIds.contains(req['shipping_id']) && req['group_id'] != null
  ).toList();

  if (alreadyGrouped.isNotEmpty) {
    // Ambil list ID yang bermasalah untuk ditampilkan di SnackBar/Dialog
    String problemIds = alreadyGrouped.map((e) => e['shipping_id']).join(", ");
    
    _showSnackBar(
      "Gagal! ID ($problemIds) sudah memiliki grup. Silakan Split dulu jika ingin mengganti grup.", 
      Colors.red
    );
    return; // STOP PROSES
  }
  // --- LOGIKA PENGECEKAN SELESAI ---
  
  try {
    //setState(() => _isLoading = true);

    // 1. Insert ke tabel shipping_groups
    // Jika tidak pakai Auth, hapus bagian created_by
    final groupResponse = await supabase
        .from('shipping_groups')
        .insert({}) // baris kosong untuk dpt ID auto-increment
        .select()
        .single();

    final int newGroupId = groupResponse['id'];

    // 2. Update shipping_request yang dipilih dengan group_id baru
    await supabase
        .from('shipping_request')
        .update({'group_id': newGroupId})
        .inFilter('shipping_id', _selectedIds.toList());

    _showSnackBar("Berhasil membuat Grup ID: $newGroupId", Colors.green);
    
    setState(() => _selectedIds.clear());
    await _fetchShippingRequests(); // Refresh data dari DB
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal grouping: $e", Colors.red);
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
        groupedMap[gId]!['all_rdds'] = [req['rdd']];
        // Pastikan so di simpan di dalam list delivery_order pendukungnya
        // (Biasanya sudah ada di level shipping_request)
        // Inisialisasi koleksi riwayat pending dengan menyertakan Ship ID
        // List historyWithId = [];
        // if (req['shipping_pending_history'] != null) {
        //   for (var h in req['shipping_pending_history']) {
        //     historyWithId.add({...h, 'origin_ship_id': req['shipping_id']});
        //   }
        // }
        // groupedMap[gId]!['collective_history'] = historyWithId;
        // Ambil history dan paksa masukkan Ship ID jika datanya belum punya key 'shipping_id'
  List historyRaw = req['shipping_pending_history'] ?? [];
  List historyWithId = historyRaw.map((h) => {
    ...h, 
    'origin_ship_id': req['shipping_id'] // Suntik ID asli ke tiap baris history
  }).toList();
  
  groupedMap[gId]!['collective_history'] = historyWithId;
      } else {
        groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
        
        // // Gabungkan riwayat pending dari anggota grup baru
        // if (req['shipping_pending_history'] != null) {
        //   List currentHistory = groupedMap[gId]!['collective_history'];
        //   for (var h in req['shipping_pending_history']) {
        //     currentHistory.add({...h, 'origin_ship_id': req['shipping_id']});
        //   }
        //   groupedMap[gId]!['collective_history'] = currentHistory;
        // }

        // Gabungkan history dari anggota grup berikutnya
  List currentHistory = List.from(groupedMap[gId]!['collective_history'] ?? []);
  List newHistoryRaw = req['shipping_pending_history'] ?? [];
  
  for (var h in newHistoryRaw) {
    currentHistory.add({
      ...h, 
      'origin_ship_id': req['shipping_id'] // Suntik ID asli di sini juga
    });
  }
  groupedMap[gId]!['collective_history'] = currentHistory;

        // Tambahkan RDD ke dalam list jika belum ada (unik)
        List<String?> rdds = List<String?>.from(groupedMap[gId]!['all_rdds']);
        if (!rdds.contains(req['rdd'])) {
          rdds.add(req['rdd']);
        }
        groupedMap[gId]!['all_rdds'] = rdds;
        // Ambil list DO yang sudah ada
        List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
        
        // Ambil DO dari request baru
        List newDos = req['delivery_order'] ?? [];
        
        // Trik: Tambahkan info SO ke setiap item DO agar bisa ditampilkan sejajar
        for (var ndo in newDos) {
          ndo['parent_so'] = req['so']; // Simpan SO asli di sini
          currentDos.add(ndo);
        }
        
        groupedMap[gId]!['delivery_order'] = currentDos;
      }
    }
  }
  
  finalResult.addAll(groupedMap.values);
  finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
  return finalResult;
}

void _toggleSelectAll(bool? selected) {
  setState(() {
    if (selected == true) {
      // Masukkan semua unique_key dari data yang sedang tampil (filtered)
      for (var req in _filteredRequests) {
        // _selectedKeys.add(req['shipping_id']);
        _selectedIds.add(req['shipping_id']);
      }
    } else {
      // Kosongkan pilihan
      _selectedIds.clear();
    }
  });
}

// Future<void> _prosesKePermintaan() async {
//   if (_selectedIds.isEmpty) return;
//   try {
//     setState(() => _isLoading = true);

//     // Cukup insert shipping_id saja, tidak perlu looping DO lagi
//     List<Map<String, dynamic>> dataToInsert = _selectedIds.map((id) => {
//       'shipping_id': id,
//       'storage_location': null,
//       'is_dedicated': null,
//     }).toList();

//     await supabase.from('shipping_request_details').insert(dataToInsert);

//     await supabase
//         .from('shipping_request')
//         .update({'status': 'waiting GBJ'})
//         .inFilter('shipping_id', _selectedIds.toList());

//     _showSnackBar("Berhasil memproses ${_selectedIds.length} Shipping ID", Colors.green);
//     setState(() => _selectedIds.clear());
//     await _fetchShippingRequests();
//   } catch (e) {
//     setState(() => _isLoading = false);
//     _showSnackBar("Gagal: $e", Colors.red);
//   }
// }

Future<void> _editStuffingMassal() async {
  if (_selectedIds.isEmpty) return;

  // Pilih tanggal target
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2024),
    lastDate: DateTime(2030),
    helpText: 'Pilih Tanggal Stuffing untuk Semuanya',
  );

  if (picked != null) {
    String formattedDate = picked.toIso8601String().split('T')[0];

    try {
      //setState(() => _isLoading = true);

      // Update semua shipping_id yang terpilih sekaligus
      await supabase
          .from('shipping_request')
          .update({'stuffing_date': formattedDate})
          .inFilter('shipping_id', _selectedIds.toList());

      _showSnackBar("Berhasil update stuffing ${_selectedIds.length} data", Colors.green);
      
      // Refresh data agar tampilan terbaru muncul
      await _fetchShippingRequests();
    } catch (e) {
      _showSnackBar("Gagal update massal: $e", Colors.red);
    } finally {
      // setState(() => _isLoading = false);
    }
  }
}

Future<void> _prosesKePermintaan() async {
  if (_selectedIds.isEmpty) return;
  
  try {
   // setState(() => _isLoading = true);
List<String> errorMessages = [];
for (var id in _selectedIds) {
      // Cari data lengkap dari _allRequests berdasarkan ID yang dipilih
      final req = _allRequests.firstWhere((element) => element['shipping_id'] == id, orElse: () => {});
      
      if (req.isNotEmpty) {
        // 1. Cek Data Header (SO, RDD, Stuffing Date)
        String so = req['so']?.toString().trim() ?? "";
        String rdd = req['rdd']?.toString().trim() ?? "";
        String stuffing = req['stuffing_date']?.toString().trim() ?? "";

        if (so.isEmpty || rdd.isEmpty || stuffing.isEmpty) {
          errorMessages.add("Ship ID $id: SO, RDD, atau Stuffing Date masih kosong.");
          continue;
        }
        }
              }
// Jika ada error, hentikan proses dan beri tahu user
    if (errorMessages.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Data Belum Lengkap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: errorMessages.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text("- ${errorMessages[index]}", style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OKE")),
          ],
        ),
      );
      return; // STOP PROSES DI SINI
    }
    // Sekarang kita tidak perlu INSERT ke tabel lain.
    // Cukup UPDATE tabel shipping_request untuk ID yang dipilih.
    await supabase
        .from('shipping_request')
        .update({
          'status': 'waiting GBJ',
        })
        .inFilter('shipping_id', _selectedIds.toList());

    _showSnackBar("Berhasil memproses ${_selectedIds.length} Shipping ID", Colors.green);
    
    setState(() => _selectedIds.clear());
    await _fetchShippingRequests();
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal memproses data: $e", Colors.red);
  }
}

  void _runFilter(String query) {
  setState(() {
    _searchQuery = query.toLowerCase();

    _filteredRequests = _allRequests.where((req) {
      // 1. --- LOGIKA FILTER TEKS (Termasuk matchInDO) ---
      final soNum = (req['so'] ?? "").toString().toLowerCase();
      final List dos = req['delivery_order'] ?? [];

      // Cek apakah teks ada di Nomor SO
      bool matchInSO = soNum.contains(_searchQuery);

      // Cek apakah teks ada di dalam List DO (Nomor DO, Customer, atau Material)
      bool matchInDO = dos.any((doItem) {
        final doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
        final custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
        final List details = doItem['do_details'] ?? [];

        // Cek kecocokan nama material di dalam detail DO
        bool matchMat = details.any((det) =>
            (det['material']?['material_name'] ?? "").toString().toLowerCase().contains(_searchQuery));

        return doNum.contains(_searchQuery) || custName.contains(_searchQuery) || matchMat;
      });

      // Hasil akhir filter teks: Cocok di SO atau cocok di salah satu DO
      bool matchText = matchInSO || matchInDO;

      // 2. --- LOGIKA FILTER TANGGAL ---
      bool matchDate = true;
      if (_selectedDateRange != null) {
        // Kita gunakan RDD sebagai acuan filter tanggal
      //   DateTime? rddDate = req['rdd'] != null ? DateTime.tryParse(req['rdd'].toString()) : null;
        
      //   if (rddDate != null) {
      //     // Normalisasi tanggal agar hanya membandingkan YYYY-MM-DD
      //     final startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
      //     final endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
      //     final checkDate = DateTime(rddDate.year, rddDate.month, rddDate.day);

      //     matchDate = checkDate.isAtSameMomentAs(startDate) || 
      //                 checkDate.isAtSameMomentAs(endDate) ||
      //                 (checkDate.isAfter(startDate) && checkDate.isBefore(endDate));
      //   } else {
      //     matchDate = false; // Jika tidak ada tanggal RDD, anggap tidak cocok dengan filter tanggal
      //   }
      // }
String dateColumn = _dateFilterType == "RDD" ? 'rdd' : 'stuffing_date';
  
  DateTime? targetDate = req[dateColumn] != null 
      ? DateTime.tryParse(req[dateColumn].toString()) 
      : null;
  
  if (targetDate != null) {
    final startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
    final endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
    final checkDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

    matchDate = checkDate.isAtSameMomentAs(startDate) || 
                checkDate.isAtSameMomentAs(endDate) ||
                (checkDate.isAfter(startDate) && checkDate.isBefore(endDate));
  } else {
    matchDate = false; 
  }
}
      // Return TRUE jika teks COCOK dan tanggal COCOK
      return matchText && matchDate;
    }).toList();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //  // title: const Text("List DO (Per DO)", style: TextStyle(fontWeight: FontWeight.bold)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTableArea(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIds.isNotEmpty ? _buildActionBottomBar() : null,
    //bottomNavigationBar: (_selectedKeys != null && _selectedKeys.isNotEmpty) 
    // ? _buildActionBottomBar() 
    // : null,
    );
  }

String formatSmart(dynamic value) {
  if (value == null) return "0";
  // Parsing ke double dulu untuk memastikan itu angka
  double n = double.tryParse(value.toString()) ?? 0.0;
  
  num rounded = num.parse(n.toStringAsFixed(3));
  // Trick cerdas: .toString() pada tipe 'num' di Dart 
  // otomatis menghilangkan nol yang tidak perlu.
 return rounded.toString();
}

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
      children: [
        // Input Pencarian
        Expanded(
          flex: 3,
      child: TextField(
        controller: _searchController,
        onChanged: _runFilter,
        decoration: InputDecoration(
          hintText: "Cari SO, DO, Customer, atau Material...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
        ),
        const SizedBox(width: 8),
        // Tombol Set Tanggal Massal (Pindah ke sini)
        // Hanya aktif jika ada data yang dipilih
        if (_selectedIds.isNotEmpty)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 19),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _editStuffingMassal,
            icon: const Icon(Icons.edit_calendar, size: 16),
            label: const Text("Set Stuffing Massal", style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),

        // // 2. Dropdown Tipe Tanggal (Kecil)
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        //   decoration: BoxDecoration(
        //     border: Border.all(color: Colors.grey.shade400),
        //     borderRadius: BorderRadius.circular(8),
        //   ),
        //   child: DropdownButtonHideUnderline(
        //     child: DropdownButton<String>(
        //       value: _dateFilterType,
        //       isDense: true,
        //       style: const TextStyle(fontSize: 12, color: Colors.black87),
        //       items: ["RDD", "Stuffing"].map((String value) {
        //         return DropdownMenuItem<String>(
        //           value: value,
        //           child: Text(value),
        //         );
        //       }).toList(),
        //       onChanged: (val) {
        //         setState(() {
        //           _dateFilterType = val!;
        //           _runFilter(_searchController.text);
        //         });
        //       },
        //     ),
        //   ),
        // ),
        // const SizedBox(width: 6),

        // ElevatedButton.icon(
        //   onPressed: _pickDateRange,
        //   style: ElevatedButton.styleFrom(
        //     backgroundColor: _selectedDateRange != null ? Colors.red.shade700 : Colors.grey.shade200,
        //     foregroundColor: _selectedDateRange != null ? Colors.white : Colors.black87,
        //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
        //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        //   ),
        //   icon: const Icon(Icons.date_range, size: 18),
        //   label: Text(
        //     _selectedDateRange == null 
        //         ? " Filter Tanggal" 
        //         : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
        //     style: const TextStyle(fontSize: 12),
        //   ),
        // ),

        // // Tombol Reset Filter (Hanya muncul jika filter aktif)
        // if (_selectedDateRange != null || _searchController.text.isNotEmpty)
        //   IconButton(
        //     icon: const Icon(Icons.refresh, color: Colors.red),
        //     onPressed: () {
        //       setState(() {
        //         _searchController.clear();
        //         _selectedDateRange = null;
        //         _dateFilterType = "RDD";
        //       });
        //       _runFilter("");
        //     },
        //   ),
        // Masukkan ke dalam Row di dalam _buildSearchBar
Container(
  decoration: BoxDecoration(
    // Warna background menyatu (merah jika filter aktif, abu-abu jika tidak)
    color: _selectedDateRange != null ? Colors.red.shade700 : Colors.grey.shade200,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 1. Bagian Dropdown (Kiri)
      Container(
        padding: const EdgeInsets.only(left: 10, right: 5),
        decoration: BoxDecoration(
          // Garis tipis pemisah di sebelah kanan dropdown
          border: Border(
            right: BorderSide(
              color: _selectedDateRange != null ? Colors.white30 : Colors.grey.shade400,
              width: 1,
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _dateFilterType,
            isDense: true,
            // Warna teks dropdown menyesuaikan background
            dropdownColor: _selectedDateRange != null ? Colors.red.shade800 : Colors.white,
            iconEnabledColor: _selectedDateRange != null ? Colors.white : Colors.black87,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: _selectedDateRange != null ? Colors.white : Colors.black87,
            ),
            items: ["RDD", "Stuffing"].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _dateFilterType = val!;
                _runFilter(_searchController.text);
              });
            },
          ),
        ),
      ),

      // 2. Bagian Tombol Tanggal (Kanan)
      InkWell(
        onTap: _pickDateRange,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.date_range, 
                size: 18, 
                color: _selectedDateRange != null ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedDateRange == null 
                    ? "Filter Tanggal" 
                    : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedDateRange != null ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),

// 3. Tombol Reset (Sama seperti sebelumnya)
if (_selectedDateRange != null || _searchController.text.isNotEmpty)
  IconButton(
    icon: const Icon(Icons.refresh, color: Colors.red),
    onPressed: () {
      setState(() {
        _searchController.clear();
        _selectedDateRange = null;
        _dateFilterType = "RDD";
      });
      _runFilter("");
    },
  ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _importMassalTigaTabel,
            icon: const Icon(Icons.file_upload, color: Colors.orange),
            tooltip: "Import Excel",
            style: IconButton.styleFrom(
    backgroundColor: Colors.orange.shade50,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
          ),
          const SizedBox(width: 6),
IconButton(
  onPressed: _exportToExcel,
  icon: const Icon(Icons.file_download, color: Colors.green),
  tooltip: "Export Excel",
  style: IconButton.styleFrom(
    backgroundColor: Colors.green.shade50,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
 ),
// const SizedBox(width: 6),

//         // 6. TOMBOL REFRESH (Sesuai permintaan Anda)
//         IconButton(
//           tooltip: "Refresh Data & Reset Filter",
//           style: IconButton.styleFrom(
//             backgroundColor: Colors.red.shade50,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//           ),
//           constraints: const BoxConstraints(),
//           padding: const EdgeInsets.only(left: 4),
//           onPressed: () { 
//             setState(() { 
//               _searchController.clear(); // Bersihkan teks pencarian
//               _selectedDateRange = null; // Reset filter tanggal
//               _dateFilterType = "RDD";   // Reset tipe tanggal ke default
//               _searchQuery = "";         // Kosongkan variabel query
//             }); 
//             _fetchShippingRequests();    // Ambil data ulang dari database
//           }, 
//           icon: const Icon(Icons.refresh, color: Colors.red, size: 20),
//         ),
      
      ],
      
    ),
    
  );
}
  

//   Future<void> _pickDateRange() async {
//   DateTimeRange? picked = await showDateRangePicker(
//     context: context,
//     firstDate: DateTime(2023),
//     lastDate: DateTime(2100),
//     initialDateRange: _selectedDateRange,
//     locale: const Locale('id', 'ID'), 
//     builder: (context, child) {
//       return Theme(
//         data: Theme.of(context).copyWith(
//           colorScheme: ColorScheme.light(
//             primary: Colors.red.shade700,
//             onPrimary: Colors.white,
//             onSurface: Colors.black,
//           ),
//           // Ini memastikan teks input mengikuti format lokal
//           textButtonTheme: TextButtonThemeData(
//             style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
//           ),
//         ),
//         child: child!,
//       );
//     },

//   );
//   if (picked != null) {
//     setState(() => _selectedDateRange = picked);
//     _runFilter(_searchController.text);
//   }
// }

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
        // BAGIAN INI UNTUK MENGATUR UKURAN
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,  // Batasi lebar maksimal
              maxHeight: 550, // Batasi tinggi maksimal
            ),
            child: child!,
          ),
        ),
      );
    },
  );

  if (picked != null) {
    setState(() => _selectedDateRange = picked);
    _runFilter(_searchController.text);
  }
}

double get _totalSelectedTNW {
  double total = 0;
  for (var id in _selectedIds) {
    // Cari data asli berdasarkan shipping_id
    final req = _allRequests.firstWhere((element) => element['shipping_id'] == id, orElse: () => {});
    if (req.isNotEmpty) {
      final List dos = req['delivery_order'] ?? [];
      for (var d in dos) {
        for (var det in d['do_details']) {
          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
          double nw = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
          total += (qty * nw);
        }
      }
    }
  }
  return total / 1000; // Kembalikan dalam satuan Kg
}

Widget _buildTableArea() {
  if (_filteredRequests.isEmpty) {
    return const Center(child: Text("Tidak ada data ditemukan"));
  }
//const double totalTableWidth = 1400.0;
  return LayoutBuilder(
    builder: (context, constraints) {
      // KUNCI: Scroll horizontal membungkus seluruh Column (Header + Body)
      return Scrollbar(
      controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER (Tetap di Atas) ---
              DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                columnSpacing: 10,
                horizontalMargin: 13,
                columns: _buildColumns(),
                rows: const [], // Hanya header
              ),
              
              // --- BODY (Bisa Scroll Vertikal) ---
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowHeight: 0, // Hilangkan header di body
                    dataRowMaxHeight: double.infinity,
                    dataRowMinHeight: 70,
                    columnSpacing: 10,
                    horizontalMargin: 9,
                    columns: _buildColumns(), // Harus sama persis
                    rows: _getGroupedDisplayData(_filteredRequests).map((req) {
                      return _buildDataRow(req);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      );
    },
  );
}

// Fungsi Helper untuk membangun isi baris (DataRow)
DataRow _buildDataRow(Map<String, dynamic> req) {
  final isGroupRow = req['group_id'] != null;
  final List<int> idsInRow = isGroupRow
      ? List<int>.from(req['grouped_ids'])
      : [req['shipping_id'] as int];

  final bool isSelected = idsInRow.any((id) => _selectedIds.contains(id));
  final int shippingId = req['shipping_id'];
  final List dos = req['delivery_order'] ?? [];

  List<Widget> doNumW = [],
      soW = [],
      custIdW = [],
      custW = [],
      matIdW = [],
      matW = [],
      matTypeW = [],
      qtyW = [],
      nwW = [];
  double totalNetWeight = 0;

  for (var d in dos) {
    String currentSo = d['parent_so']?.toString() ?? req['so']?.toString() ?? "-";
    String custId = d['customer']?['customer_id']?.toString() ?? "-";
    for (var det in d['do_details']) {
      double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
      double nwValue = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
      double rowNw = qty * nwValue;
      totalNetWeight += rowNw;

      soW.add(_buildTextItem(currentSo, width: 80));
      doNumW.add(_buildTextItem(d['do_number'] ?? "-", isBold: true, width: 70));
      custIdW.add(_buildTextItem(custId, width: 70));
      custW.add(_buildTextItem(d['customer']?['customer_name'] ?? "-", width: 196));
      matIdW.add(_buildTextItem(det['material']?['material_id']?.toString() ?? "-", width: 50));
      matW.add(_buildTextItem(det['material']?['material_name'] ?? "-", width: 226));
      matTypeW.add(_buildTextItem(det['material']?['material_type'] ?? "-", width: 42));
      qtyW.add(_buildTextItem(det['qty']?.toString() ?? "0", isBold: true, width: 30));
      nwW.add(_buildTextItem(formatSmart(rowNw), width: 52));
    }
  }

  return DataRow(
    selected: isSelected,
    color: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected))
        return Colors.grey.shade400.withOpacity(0.5);
      final String currentStatus = (req['status'] ?? "").toString().toLowerCase();
      if (currentStatus == 'pending') return Colors.red.shade100;
      if (req['group_id'] != null) return Colors.blue.shade100.withOpacity(0.5);
      return null;
    }),
    cells: [
      DataCell(Checkbox(
        value: isSelected,
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selectedIds.addAll(idsInRow);
            } else {
              _selectedIds.removeAll(idsInRow);
            }
          });
        },
      )),
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isGroupRow ? idsInRow.join(", ") : shippingId.toString(),
              style: TextStyle(
                  fontWeight: isGroupRow ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11)),
          _buildStatusBadge(req['status'],isGroupRow ? req['collective_history'] : req['shipping_pending_history']),
          if (isGroupRow)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4)),
              child: Text("GROUP ID: ${req['group_id']}",
                  style: const TextStyle(color: Colors.white, fontSize: 9)),
            ),
        ],
      )),
      DataCell(Column(children: doNumW)),
      DataCell(Column(children: soW)),
      DataCell(Column(children: custIdW)),
      DataCell(Column(children: custW)),
      DataCell(Column(children: matIdW)),
      DataCell(Column(children: matW)),
      DataCell(Column(children: matTypeW)),
      DataCell(Column(children: qtyW)),
      DataCell(Column(children: nwW)),
      DataCell(Text(formatSmart(totalNetWeight / 1000),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      //DataCell(Text(_formatDate(req['rdd']))),
      //DataCell(Text(_formatDate(req['stuffing_date']))),
      // KOLOM RDD INTERAKTIF
      DataCell(
        InkWell(
          onTap: () => _selectDate(context, req, 'rdd'),
          child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Builder(
        builder: (context) {
          // Jika ini adalah grup, tampilkan semua RDD yang dikumpulkan
          if (req['all_rdds'] != null) {
            List<String?> rdds = List<String?>.from(req['all_rdds']);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rdds.map((r) => Text(
                _formatDate(r), 
                style: const TextStyle(fontSize: 12, color: Colors.black)
              )).toList(),
            );
          }
          // Jika bukan grup, tampilkan satu tanggal seperti biasa
          return Text(_formatDate(req['rdd']), style: const TextStyle(color: Colors.black));
        }
      ),
    ),
  ),
),

      // KOLOM STUFFING INTERAKTIF
      DataCell(
        InkWell(
          onTap: () => _selectDate(context, req, 'stuffing_date'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatDate(req['stuffing_date']), style: const TextStyle(color: Colors.black)),
              // const Icon(Icons.calendar_month, size: 14, color: Colors.blue),
            ],
          ),
        ),
      ),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => _editShippingRequest(req),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(2),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => _deleteShippingRequest(req),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(2),
          ),
        ],
      )),
    ],
  );
}

// List<DataColumn> _buildColumns() {
//   return const [
//     DataColumn(label: Text('Pilih')),
//     DataColumn(label: Text('Ship ID')),
//     DataColumn(label: Text('No DO')),
//     DataColumn(label: Text('SO Number')),
//     DataColumn(label: Text('No Cust')),
//     DataColumn(label: Text('Customer Tujuan')),
//     DataColumn(label: Text('No Mat')),
//     DataColumn(label: Text('Nama Material')),
//     DataColumn(label: Text('Type')),
//     DataColumn(label: Text('Qty')),
//     DataColumn(label: Text('NW')),
//     DataColumn(label: Text('TNW')),
//     DataColumn(label: Text('RDD')),
//     DataColumn(label: Text('Stuffing')),
//     DataColumn(label: Text('Aksi')),
//   ];
// }

// Tambahkan lebar tetap pada kolom yang berisi teks panjang agar tidak menciut
List<DataColumn> _buildColumns() {
  return const [
    DataColumn(label: SizedBox(width: 35, child: Text('Pilih'))),
    DataColumn(label: SizedBox(width: 74, child: Text('Ship ID'))),
    DataColumn(label: SizedBox(width: 68, child: Text('No DO'))),
    DataColumn(label: SizedBox(width: 80, child: Text('SO Number'))),
    DataColumn(label: SizedBox(width: 85, child: Text('No Cust'))),
    DataColumn(label: SizedBox(width: 198, child: Text('Customer Tujuan'))),
    DataColumn(label: SizedBox(width: 55, child: Text('No Mat'))),
    DataColumn(label: SizedBox(width: 230, child: Text('Nama Material'))),
    DataColumn(label: SizedBox(width: 42, child: Text('Type'))),
    DataColumn(label: SizedBox(width: 40, child: Text('Qty'))),
    DataColumn(label: SizedBox(width: 53, child: Text('NW'))),
    DataColumn(label: SizedBox(width: 50, child: Text('TNW'))),
    DataColumn(label: SizedBox(width: 70, child: Text('RDD'))),
    DataColumn(label: SizedBox(width: 70, child: Text('Stuffing'))),
    DataColumn(label: SizedBox(width: 50, child: Text('Aksi'))),
  ];
}

Future<void> _selectDate(BuildContext context, Map<String, dynamic> req, String fieldName) async {
  // Ambil tanggal saat ini sebagai default jika data null
  DateTime initialDate = DateTime.tryParse(req[fieldName]?.toString() ?? "") ?? DateTime.now();
  
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2024), // Sesuaikan batas minimal tahun
    lastDate: DateTime(2030), // Sesuaikan batas maksimal tahun
    helpText: 'Pilih Tanggal ${fieldName.toUpperCase()}',
  );

  if (picked != null) {
    // Format tanggal ke String ISO (YYYY-MM-DD) untuk database
    String formattedDate = picked.toIso8601String().split('T')[0];

    try {
      // Tampilkan loading sebentar jika perlu, atau langsung update
      
      if (req['group_id'] != null) {
        // Jika bagian dari Group, update semua yang memiliki group_id yang sama
        await Supabase.instance.client
            .from('shipping_request')
            .update({fieldName: formattedDate})
            .eq('group_id', req['group_id']);
            
        _showSnackBar("Update Group berhasil", Colors.green);
      } else {
        // Jika data satuan
        await Supabase.instance.client
            .from('shipping_request')
            .update({fieldName: formattedDate})
            .eq('shipping_id', req['shipping_id']);

        _showSnackBar("Update Tanggal berhasil", Colors.green);
      }

      // Opsional: Jika tidak pakai realtime stream, panggil fetch manual
      // _fetchShippingRequests(); 
      
    } catch (e) {
      _showSnackBar("Gagal mengupdate: $e", Colors.red);
    }
  }
}

Future<void> _setPending(int shippingId, String reason) async {
  try {
    // 1. INPUT KE TABEL BARU (Riwayat Pending)
    await supabase.from('shipping_pending_history').insert({
      'shipping_id': shippingId,
      'reason': reason,
      'pending_by': userDisplayName ?? 'System', // Pastikan userDisplayName terisi
    });

    // 2. UPDATE TABEL UTAMA (Status)
    await supabase.from('shipping_request').update({
      'status': 'pending',
    }).eq('shipping_id', shippingId);

    _showSnackBar("Data berhasil dipending", Colors.orange);
    
    // 3. REFRESH DATA
    _fetchShippingRequests();
    
  } catch (e) {
    debugPrint("Error Pending: $e");
    _showSnackBar("Gagal simpan pending: $e", Colors.red);
  }
}

Future<void> _setPendingGroup(List<int> shippingIds, String reason) async {
  try {
    // Siapkan list riwayat untuk bulk insert
    final List<Map<String, dynamic>> historyData = shippingIds.map((id) => {
      'shipping_id': id,
      'reason': reason,
      'pending_by': userDisplayName ?? 'System',
    }).toList();

    // 1. Insert ke riwayat secara massal
    await supabase.from('shipping_pending_history').insert(historyData);

    // 2. Update status semua ID tersebut
    await supabase.from('shipping_request')
        .update({'status': 'pending'})
        .inFilter('shipping_id', shippingIds);

    _showSnackBar("Grup berhasil dipending", Colors.orange);
    _fetchShippingRequests();
  } catch (e) {
    _showSnackBar("Gagal pending grup: $e", Colors.red);
  }
}

Future<void> _deleteShippingRequest(Map<String, dynamic> req) async {
  final int shippingId = req['shipping_id'];
  final int? groupId = req['group_id'];
  final bool isGroup = groupId != null;

  // Siapkan pesan konfirmasi yang berbeda jika data tersebut adalah grup
  String title = isGroup ? "Hapus Grup Data" : "Hapus Data";
  String content = isGroup 
      ? "Data ini bagian dari Grup ID: $groupId. Menghapus akan menghapus SEMUA Ship ID di grup ini. Lanjutkan?"
      : "Apakah Anda yakin ingin menghapus Shipping ID: $shippingId?";

  bool confirm = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
        TextButton(
          onPressed: () => Navigator.pop(context, true), 
          child: const Text("Hapus", style: TextStyle(color: Colors.red))
        ),
      ],
    ),
  ) ?? false;

  if (confirm) {
    try {
      setState(() => _isLoading = true);

      if (isGroup) {
        // LOGIKA HAPUS GRUP
        // 1. Hapus semua shipping_request yang memiliki group_id yang sama
        await supabase
            .from('shipping_request')
            .delete()
            .eq('group_id', groupId);

        // 2. Hapus entry di shipping_groups (Opsional jika DB Anda set ON DELETE CASCADE)
        await supabase
            .from('shipping_groups')
            .delete()
            .eq('id', groupId);
            
      } else {
        // LOGIKA HAPUS SINGLE DATA
        await supabase
            .from('shipping_request')
            .delete()
            .eq('shipping_id', shippingId);
      }

      _showSnackBar("Data berhasil dihapus", Colors.green);
      _fetchShippingRequests(); // Refresh data
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal menghapus: $e", Colors.red);
    }
  }
}

  Widget _buildTextItem(String text, {bool isBold = false, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

void _showReasonDialog(List history) {
  // Urutkan dari yang terbaru ke terlama
  final sortedHistory = List.from(history);
  //sortedHistory.sort((a, b) => b['pending_at'].compareTo(a['pending_at']));
  sortedHistory.sort((a, b) {
    DateTime dtA = DateTime.tryParse(a['pending_at']?.toString() ?? "") ?? DateTime(2000);
    DateTime dtB = DateTime.tryParse(b['pending_at']?.toString() ?? "") ?? DateTime(2000);
    return dtB.compareTo(dtA);
  });
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red.shade700),
          const SizedBox(width: 10),
          const Text("Alasan Pending", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: sortedHistory.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final item = sortedHistory[index];
          //   DateTime date = DateTime.parse(item['pending_at']);

          //   // Ambil ID asal (jika grup) atau gunakan ID utama
          //  String originId = item['origin_ship_id']?? item['shipping_id'] ?? item['id'] ?? "-";

DateTime date = DateTime.tryParse(item['pending_at']?.toString() ?? "") ?? DateTime.now();

            // PERBAIKAN DI SINI: Gunakan .toString() untuk ID agar tidak error 'int' is not 'String'
            String originId = (item['origin_ship_id'] ?? item['shipping_id'] ?? item['id'] ?? "-").toString();
            
            return ListTile(
      //         leading: CircleAvatar(
      //           backgroundColor: Colors.red.shade50,
      //           child: Text("${sortedHistory.length - index}", style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
      //         ),
      //         title: Text(item['reason'] ?? "-", style: const TextStyle(fontSize: 14)),
      //         subtitle: Text(
      //           DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal()),
      //           style: const TextStyle(fontSize: 11),
      //         ),
      //       );
      //     },
      //   ),
      // ),
      contentPadding: EdgeInsets.zero,
              title: Text(item['reason'] ?? "-", style: const TextStyle(fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ship ID: $originId", 
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                  Text(DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal()),
                    style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
      ],
    ),
  );
}

Widget _buildStatusBadge(String? status, dynamic historyData) {
  // Jika status null atau BUKAN 'cancel', jangan tampilkan apa-apa (SizedBox kosong)
  if (status == null || status.toLowerCase() != 'pending') {
    return const SizedBox.shrink();
  }

  // 2. Pastikan historyData adalah List dan tidak kosong
  if (historyData == null || historyData is! List || historyData.isEmpty) {
    return const SizedBox.shrink();
  }

List history = List.from(historyData);
  
  // 3. Urutkan manual berdasarkan pending_at untuk memastikan .last adalah yang terbaru
  history.sort((a, b) => (a['pending_at'] ?? "").compareTo(b['pending_at'] ?? ""));
  final latestPending = history.last;
  //final latestPending = history.last; 
  String reason = latestPending['reason'] ?? "Tidak ada alasan.";
  // Karena sudah pasti 'pending' di titik ini, kita langsung set warnanya
  Color color = Colors.red.shade800;
  String label = "PENDING";

  return InkWell(
    onTap: () => _showReasonDialog(history),
    child: Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color, 
              fontSize: 9, 
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.info_outline, size: 10, color: color),
        ],
      ),
    ),
  );
}

Widget _buildActionBottomBar() {
  double totalBerat = _totalSelectedTNW;
  int jumlahEntitas = _countSelectedEntities; // Menggunakan logika baru

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$jumlahEntitas Terpilih", // Menampilkan 1 jika itu sebuah grup
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    "Total Estimasi Berat:",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  "${formatSmart(totalBerat)} Ton",
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _splitGroup,
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text("Split", style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _selectedIds.length < 2 ? null : _createAndAssignGroup,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text("Group", style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _prosesKePermintaan,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    "Proses ($jumlahEntitas)", // Menampilkan jumlah truk/entitas
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

int get _countSelectedEntities {
  final Set<String> entities = {};

  for (var id in _selectedIds) {
    final req = _allRequests.firstWhere(
      (element) => element['shipping_id'] == id, 
      orElse: () => {}
    );

    if (req.isNotEmpty) {
      if (req['group_id'] != null) {
        // Jika ada Group ID, masukkan ID Grup ke dalam Set (otomatis unik)
        entities.add("GROUP_${req['group_id']}");
      } else {
        // Jika tidak ada grup, masukkan Shipping ID
        entities.add("SINGLE_$id");
      }
    }
  }
  return entities.length;
}

Future<void> _splitGroup() async {
  if (_selectedIds.isEmpty) {
    _showSnackBar("Pilih data yang ingin dipisahkan dari grup", Colors.orange);
    return;
  }

  try {
    //setState(() => _isLoading = true);

    // 1. Cari group_id apa saja yang terlibat dari ID yang dipilih
    final selectedGroups = _allRequests
        .where((req) => _selectedIds.contains(req['shipping_id']) && req['group_id'] != null)
        .map((req) => req['group_id'] as int)
        .toSet()
        .toList();

    if (selectedGroups.isEmpty) {
      setState(() => _isLoading = false);
      _showSnackBar("Data yang dipilih memang tidak masuk dalam grup mana pun", Colors.blueGrey);
      return;
    }

    // 2. Set group_id menjadi NULL untuk semua shipping_id yang ada di dalam grup tersebut
    // Kita split SEMUA yang ada di grup itu agar grupnya benar-benar bubar
    await supabase
        .from('shipping_request')
        .update({'group_id': null})
        .inFilter('group_id', selectedGroups);

    // 3. Hapus data grupnya di tabel shipping_groups agar tidak nyampah
    await supabase
        .from('shipping_groups')
        .delete()
        .inFilter('id', selectedGroups);

    _showSnackBar("Grup berhasil dibubarkan dan dihapus", Colors.blueGrey);
    
    setState(() => _selectedIds.clear());
    await _fetchShippingRequests(); // Refresh data
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal split & delete group: $e", Colors.red);
  }
}

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd/MM/yy').format(DateTime.parse(dateStr));
    } catch (e) {
      return "-";
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  bool _isExporting = false;


static bool _globalExportLock = false;

Future<void> _exportToExcel() async {
  if (_globalExportLock || _filteredRequests.isEmpty) return;

  try {
    _globalExportLock = true;
   // setState(() => _isLoading = true);

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Data_Shipping_Detail'];
    excel.delete('Sheet1'); 

    // --- 1. HEADER (Sesuai Struktur Lengkap) ---
    List<CellValue> headers = [
      TextCellValue('Group ID'),      // 1
      TextCellValue('Ship ID'),       // 2
      TextCellValue('No DO'),         // 3
      TextCellValue('SO Number'),     // 4
      TextCellValue('Customer'),      // 5
      TextCellValue('Material'),      // 6
      TextCellValue('Type'),          // 7
      TextCellValue('Qty'),           // 8
      TextCellValue('NW (Unit)'),     // 9
      TextCellValue('TNW (Kg)'),      // 10
      TextCellValue('RDD'),           // 11
      TextCellValue('Stuffing'),      // 12
      TextCellValue('Status'),        // 13
      TextCellValue('Pending Reason'), // 14
    ];
    sheetObject.appendRow(headers);

    // --- 2. ISI DATA ---
    for (var req in _filteredRequests) {
      final List dos = req['delivery_order'] ?? [];
      final String status = (req['status'] ?? "-").toString().toUpperCase();
      
      // Ambil alasan pending atau cancel
     // final String reason = req['pending_reason'] ?? req['cancel_reason'] ?? "-";
      // Ambil alasan pending terbaru dari tabel riwayat yang sudah di-join
      // req['shipping_pending_history'] sekarang berupa List
      //final List history = req['shipping_pending_history'] ?? [];
      final List history = List.from(req['shipping_pending_history'] ?? []);
      String latestReason = "-";
      
      if (history.isNotEmpty) {
        // Ambil data terakhir dari list (asumsi data terbaru)
        // Jika query Anda menggunakan .order('pending_at'), sesuaikan indeksnya
        history.sort((a, b) => (a['pending_at'] ?? "").compareTo(b['pending_at'] ?? ""));
        latestReason = history.last['reason'] ?? "-";
      }

      final String groupId = req['group_id']?.toString() ?? "-";

      for (var d in dos) {
        final List details = d['do_details'] ?? [];
        for (var det in details) {
          // Logika Perhitungan
          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
          double nwUnit = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
          // Hitung TNW dalam Kg (Qty * NW / 1000)
          double totalNwRow = (qty * nwUnit) / 1000;

          sheetObject.appendRow([
            TextCellValue(groupId),                                     // 1
            TextCellValue(req['shipping_id'].toString()),               // 2
            TextCellValue(d['do_number'] ?? "-"),                       // 3
            TextCellValue(req['so']?.toString() ?? "-"),                // 4
            TextCellValue(d['customer']?['customer_name'] ?? "-"),      // 5
            TextCellValue(det['material']?['material_name'] ?? "-"),    // 6
            TextCellValue(det['material']?['material_type'] ?? "-"),    // 7
            DoubleCellValue(qty),                                       // 8
            DoubleCellValue(nwUnit),                                    // 9
            DoubleCellValue(totalNwRow),                                // 10
            TextCellValue(_formatDate(req['rdd'])),                     // 11
            TextCellValue(_formatDate(req['stuffing_date'])),           // 12
            TextCellValue(status),                                      // 13
            TextCellValue(latestReason),                                 // 14
          ]);
        }
      }
    }

    // --- 3. PROSES DOWNLOAD (Web & Mobile Aman) ---
    // Gunakan encode() agar tidak terpicu auto-download dari library
    final fileBytes = excel.encode(); 
    if (fileBytes == null) return;

    String fileName = "Shipping_Report_${DateFormat('yyyyMMdd_HHmm')}.xlsx";

    if (kIsWeb) {
      final content = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(content);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);
      _showSnackBar("Excel diunduh!", Colors.green);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileName';
      final file = io.File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(fileBytes);
      await OpenFile.open(filePath);
    }

  } catch (e) {
    debugPrint("Export Error: $e");
    _showSnackBar("Gagal: $e", Colors.red);
  } finally {
    // Jeda 3 detik untuk memastikan lock aman
    await Future.delayed(const Duration(seconds: 3));
    _globalExportLock = false;
    // // if (mounted) {
    // //   setState(() => _isLoading = false);
    // }
  }
}

}