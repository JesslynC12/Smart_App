import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';


class DetailsDOGbjPage extends StatefulWidget {
  const DetailsDOGbjPage({super.key});


  @override
  State<DetailsDOGbjPage> createState() => _DetailsDOGbjPageState();
}


class _DetailsDOGbjPageState extends State<DetailsDOGbjPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _dataList = [];


  // Variabel untuk melacak baris mana yang sedang dibuka (berdasarkan shipping_id)
  int? _expandedId;


  // State input sementara
  String? _selectedSLoc;
  String? _selectedDedicated;


  @override
  void initState() {
    super.initState();
    _fetchData();
  }


  // Future<void> _fetchData() async {
  //   try {
  //     final response = await supabase.from('shipping_request').select('''
  //           *,
  //           shipping_request_details!inner(*),
  //           delivery_order(
  //             do_number,
  //             customer(customer_name),
  //             do_details(qty, material_id, material(material_name))
  //           )
  //         ''').order('shipping_id', ascending: false);


  //     setState(() {
  //       _dataList = List<Map<String, dynamic>>.from(response);
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //       _showSnackBar("Gagal ambil data: $e", Colors.red);
  //     }
  //   }
  // }


//   Future<void> _fetchData() async {
//   try {
//     final response = await supabase
//         .from('shipping_request')
//         .select('''
//             *,
//             shipping_request_details!inner(*),
//             vendor_delivery_request!left(id),
//             delivery_order(
//               do_number,
//               customer(customer_name),
//               do_details(qty, material_id, material(material_name))
//             )
//           ''')
//         // SYARAT 1: Belum ada di daftar vendor (otomatis hilang jika sudah di-insert)
//         .isFilter('vendor_delivery_request', null)
//         // SYARAT 2: Status bukan 'cancel' (otomatis hilang jika di-cancel)
//         .not('status', 'eq', 'cancel')
//         .order('shipping_id', ascending: false);


//     setState(() {
//       _dataList = List<Map<String, dynamic>>.from(response);
//       _isLoading = false;
//     });
//   } catch (e) {
//     if (mounted) {
//       setState(() => _isLoading = false);
//       _showSnackBar("Gagal ambil data: $e", Colors.red);
//     }
//   }
// }


Future<void> _fetchData() async {
  try {
    setState(() => _isLoading = true);
    final response = await supabase
        .from('shipping_request')
        .select('''
            *,
            group_id,
            shipping_request_details!inner(*),
            vendor_delivery_request!left(id),
            delivery_order(
              do_number,
              customer(customer_id,customer_name),
              do_details(qty, material_id, material(material_name))
            )
          ''')
        .isFilter('vendor_delivery_request', null)
        .not('status', 'eq', 'pending')
        .order('shipping_id', ascending: false);


    setState(() {
      // PROSES GROUPING DI SINI
      _dataList = _getGroupedDisplayData(List<Map<String, dynamic>>.from(response));
      _isLoading = false;
    });
  } catch (e) {
    // ... handle error
  }
}


  // Future<void> _simpanDanPindahkan(int sid) async {
  //   if (_selectedSLoc == null || _selectedDedicated == null) {
  //     _showSnackBar("Harap isi Lokasi dan Status Dedicated", Colors.orange);
  //     return;
  //   }


  //   try {
  //     setState(() => _isLoading = true);


  //     // 1. Update Detail (Simpan input user)
  //     await supabase.from('shipping_request_details').update({
  //       'storage_location': _selectedSLoc,
  //       'is_dedicated': _selectedDedicated,
  //     }).eq('shipping_id', sid);


  //     // 2. Tandai agar masuk ke List Vendor (Kita asumsikan dengan kolom status atau flag baru)
  //     // Misal kita update status di shipping_request menjadi 'to_vendor'
  //     await supabase.from('shipping_request').update({
  //       'status': 'waiting vendor delivery request',
  //     }).eq('shipping_id', sid);


  //     _showSnackBar("Berhasil! Data dipindahkan ke List Vendor", Colors.green);
     
  //     // Reset state & Refresh list (item akan otomatis hilang dari query !inner jika status berubah)
  //     _expandedId = null;
  //     _selectedSLoc = null;
  //     _selectedDedicated = null;
  //     await _fetchData();
     
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     _showSnackBar("Gagal menyimpan: $e", Colors.red);
  //   }
  // }


//   Future<void> _simpanDanPindahkan(int sid) async {
//   if (_selectedSLoc == null || _selectedDedicated == null) {
//     _showSnackBar("Harap isi Lokasi dan Status Dedicated", Colors.orange);
//     return;
//   }


//   try {
//     setState(() => _isLoading = true);


//     // 1. Update Detail Logistik (Gudang)
//     await supabase.from('shipping_request_details').update({
//       'storage_location': _selectedSLoc,
//       'is_dedicated': _selectedDedicated,
//     }).eq('shipping_id', sid);


//     // 2. Update status di shipping_request menjadi waiting vendor
//     await supabase.from('shipping_request').update({
//       'status': 'waiting vendor delivery request',
//     }).eq('shipping_id', sid);


//     // 3. INSERT ke tabel vendor_delivery_request
//     // Ini pemicu utama data HILANG dari list karena filter !left vendor_delivery_request
//     await supabase.from('vendor_delivery_request').insert({
//       'shipping_id': sid,
//       'status': 'waiting approval', // Default status sesuai tabel Anda
//       'id_profile': supabase.auth.currentUser?.id, // Mencatat admin yang memproses
//     });


//     _showSnackBar("Berhasil! Data diteruskan ke Vendor", Colors.green);


//     // Reset UI state & Refresh (Data sid ini akan hilang dari list)
//     setState(() {
//       _expandedId = null;
//       _selectedSLoc = null;
//       _selectedDedicated = null;
//     });
//     await _fetchData();


//   } catch (e) {
//     setState(() => _isLoading = false);
//     _showSnackBar("Gagal memindahkan data: $e", Colors.red);
//   }
// }


Future<void> _simpanDanPindahkan(Map<String, dynamic> item) async {
  if (_selectedSLoc == null || _selectedDedicated == null) {
    _showSnackBar("Harap isi Lokasi dan Status Dedicated", Colors.orange);
    return;
  }


  // Ambil semua ID (bisa satu atau banyak jika grup)
  final List<int> idsToProcess = item['group_id'] != null
      ? List<int>.from(item['grouped_ids'])
      : [item['shipping_id'] as int];


  try {
    setState(() => _isLoading = true);


    for (int sid in idsToProcess) {
      // 1. Update Detail Logistik
      await supabase.from('shipping_request_details').update({
        'storage_location': _selectedSLoc,
        'is_dedicated': _selectedDedicated,
      }).eq('shipping_id', sid);


      // 2. Update Status
      await supabase.from('shipping_request').update({
        'status': 'waiting vendor delivery request',
      }).eq('shipping_id', sid);


      // 3. Insert ke Vendor Request
      await supabase.from('vendor_delivery_request').insert({
        'shipping_id': sid,
        'status': 'waiting approval',
        'id_profile': supabase.auth.currentUser?.id,
      });
    }


    _showSnackBar("Berhasil memproses ${idsToProcess.length} data", Colors.green);
    _expandedId = null;
    await _fetchData();
  } catch (e) {
    // ... handle error
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("DO Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _dataList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _dataList.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _dataList.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final item = _dataList[index];
                    final sid = item['shipping_id'];
                    final bool isExpanded = _expandedId == sid;


                    return _buildExpandableCard(item, sid, isExpanded);
                  },
                ),
    );


  }
 
  // 1. Tombol Cancel di Form Input (Perbaikan Casting)
Widget _buildActionForm(Map<String, dynamic> item) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.edit_note, size: 18, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text("INPUT LOGISTIK GUDANG",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
          ],
        ),
        const SizedBox(height: 16),
       
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Storage Location"),
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Pilih Lokasi"),
                    value: _selectedSLoc,
                    items: const [
                      DropdownMenuItem(value: "rungkut", child: Text("Rungkut", style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: "tambak langon", child: Text("Tambak Langon", style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) => setState(() => _selectedSLoc = val),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Dedicated Status"),
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Pilih Status"),
                    value: _selectedDedicated,
                    items: const [
                      DropdownMenuItem(value: "dedicated", child: Text("Dedicated", style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: "non-dedicated", child: Text("Non-Dedicated", style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) => setState(() => _selectedDedicated = val),
                  ),
                ],
              ),
            ),
          ],
        ),
       
        const SizedBox(height: 24),


        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                // PERBAIKAN: Hapus "as int"
                onPressed: () => _pendingRequest(item),
                icon: const Icon(Icons.close, size: 18),
                label: const Text("PENDING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _bulkAction(item, 'SAVE'),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  item['group_id'] != null
                    ? "PROSES SEMUA (${(item['grouped_ids'] as List).length})"
                    : "PROSES",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


// 2. Fungsi Bulk Action (Optimasi Request)
Future<void> _bulkAction(Map<String, dynamic> item, String actionType) async {
  if (_selectedSLoc == null || _selectedDedicated == null) {
    _showSnackBar("Harap isi lokasi dan status", Colors.orange);
    return;
  }


  final List<int> idsToProcess = item['group_id'] != null
      ? List<int>.from(item['grouped_ids'])
      : [item['shipping_id'] as int];


  try {
    setState(() => _isLoading = true);
   
    // 1. Update Detail Massal
    await supabase.from('shipping_request_details').update({
      'storage_location': _selectedSLoc,
      'is_dedicated': _selectedDedicated,
    }).inFilter('shipping_id', idsToProcess);


    // 2. Update Status Shipping Massal
    await supabase.from('shipping_request').update({
      'status': 'waiting vendor delivery request'
    }).inFilter('shipping_id', idsToProcess);


    // 3. Insert ke Vendor Request (Tetap loop karena insert beda baris)
    final List<Map<String, dynamic>> inserts = idsToProcess.map((sid) => {
      'shipping_id': sid,
      'status': 'waiting approval',
      'id_profile': supabase.auth.currentUser?.id,
    }).toList();
   
    await supabase.from('vendor_delivery_request').insert(inserts);
   
    _showSnackBar("Berhasil memproses ${idsToProcess.length} data", Colors.green);
    setState(() {
      _expandedId = null;
      _selectedSLoc = null;
      _selectedDedicated = null;
    });
    await _fetchData();
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Error: $e", Colors.red);
  }
}

Widget _buildExpandableCard(Map<String, dynamic> item, int sid, bool isExpanded) {
  final List dos = item['delivery_order'] ?? [];
  final bool isGroupRow = item['group_id'] != null;


  return Card(
    elevation: isExpanded ? 4 : 1,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Column(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ListTile(
            onTap: () {
              setState(() {
                _expandedId = isExpanded ? null : sid;
                _selectedSLoc = null;
                _selectedDedicated = null;
              });
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: isGroupRow ? Colors.blue.shade700 : (isExpanded ? Colors.red.shade700 : Colors.blueGrey[400]),
              child: Icon(isGroupRow ? Icons.layers : Icons.inventory_2, color: Colors.white, size: 20),
            ),
           
            // --- INI ADALAH BAGIAN YANG ANDA TANYAKAN ---
            // title: Row(
            //   children: [
            //     // Expanded(
            //     //   child: Text(
            //     //     isGroupRow ? "Grup SO: ${item['display_so'].join(', ')}" : "SO: ${item['so'] ?? '-'}",
            //     //     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            //     //     overflow: TextOverflow.ellipsis,
            //     //   ),
            //     // ),
            //     if (isGroupRow)
            //       Container(
            //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            //         decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
            //         child: Text("ID GRP: ${item['group_id']}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            //       ),
            //   ],
            // ),
            // -------------------------------------------
// --- BAGIAN YANG DIUBAH ---
            title: Row(
              children: [
                Icon(
                  isGroupRow ? Icons.layers : Icons.local_shipping, 
                  size: 18, 
                  color: Colors.red.shade700
                ),
                const SizedBox(width: 8),
                Text(
                  isGroupRow ? "GROUP ID: ${item['group_id']}" : "SHIP ID: ${item['shipping_id']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 12),
              ],
            ),

            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text("📅 RDD: ${_formatDate(item['rdd'])} | 🚛 Stuffing: ${_formatDate(item['stuffing_date'])}",
                     style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
               
                // --- TABEL DETAIL MATERIAL (SESUAI GAMBAR REFERENSI) ---
...dos.map((doItem) {
  final List details = doItem['do_details'] ?? [];
  // Ambil nomor SO pendukungnya
  final String soPerItem = doItem['parent_so']?.toString() ?? item['so']?.toString() ?? "-";
  
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
            color: Colors.red.shade100, // Background abu sangat muda sesuai gambar
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8), 
              topRight: Radius.circular(8)
            ),
          ),
          child: Row(
            children: [
              // 1. DO NUMBER (Kiri - Biru)
              Text(
                "DO: ${doItem['do_number']}", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)
              ),
              const Spacer(),
              Text(
                  "SO: $soPerItem", 
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
              
              const Spacer(),

              // 3. CUSTOMER NAME (Kanan - Hitam Bold)
              Text(
                // (doItem['customer']?['customer_name'] ?? "-").toString().toUpperCase(), 
                "${doItem['customer']?['customer_id'] ?? '-'} - ${(doItem['customer']?['customer_name'] ?? '-').toString().toUpperCase()}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)
              ),
            ],
          ),
        ),
        
        // TABEL ISI MATERIAL (Sesuai gambar: No Mat | Nama Mat | Qty)
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2), // No Mat
            1: FlexColumnWidth(4),   // Nama Material
            2: FlexColumnWidth(1),   // Qty
          },
          children: details.map((det) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(10), 
                child: Text(det['material_id']?.toString() ?? "-", style: const TextStyle(fontSize: 11))
              ),
              Padding(
                padding: const EdgeInsets.all(10), 
                child: Text(det['material']?['material_name'] ?? "-", style: const TextStyle(fontSize: 11))
              ),
              Padding(
                padding: const EdgeInsets.all(10), 
                child: Text(
                  det['qty']?.toString() ?? "0", 
                  textAlign: TextAlign.right, // Qty rata kanan agar rapi
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                )
              ),
            ],
          )).toList(),
        ),
      ],
    ),
  );
}).toList(),
              ],
            ),
            trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
          ),
        ),
       
        // Form Input saat di-Expand (Gunakan item bukan sid)
        if (isExpanded) _buildActionForm(item),
      ],
    ),
  );
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
        // Inisialisasi list SO agar tidak duplikat
        groupedMap[gId]!['display_so'] = [req['so']];
      } else {
        groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
       
        List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
        List newDos = req['delivery_order'] ?? [];


        for (var ndo in newDos) {
          ndo['parent_so'] = req['so']; // Simpan SO di tiap DO
          currentDos.add(ndo);
        }
        groupedMap[gId]!['delivery_order'] = currentDos;


        if (!groupedMap[gId]!['display_so'].contains(req['so'])) {
          groupedMap[gId]!['display_so'].add(req['so']);
        }
      }
    }
  }
  finalResult.addAll(groupedMap.values);
  finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
  return finalResult;
}

Future<void> _pendingRequest(Map<String, dynamic> item) async {
  final List<int> idsToCancel = item['group_id'] != null
      ? List<int>.from(item['grouped_ids'])
      : [item['shipping_id'] as int];
     
  final TextEditingController reasonController = TextEditingController();


  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Konfirmasi Pembatalan", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Membatalkan ${idsToCancel.length} data. Berikan alasan:"),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Alasan pembatalan..."),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("KEMBALI")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("BATALKAN", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  // if (confirm != true || reasonController.text.isEmpty) return;
  if (confirm != true || reasonController.text.trim().isEmpty) {
    if (confirm == true) _showSnackBar("Alasan wajib diisi!", Colors.orange);
    return;
  }

 try {
    setState(() => _isLoading = true);

    // 1. TETAP UPDATE STATUS (Logika lama Anda)
    // Menggunakan .inFilter agar lebih efisien daripada loop for
    await supabase.from('shipping_request').update({
      'status': 'pending',
      'pending_reason': reasonController.text.trim(),
      'pending_at': DateTime.now().toIso8601String(),
    }).inFilter('shipping_id', idsToCancel);

    // 2. TAMBAHAN: HAPUS BARIS DI TABEL DETAILS
    // Ini yang akan membuat data hilang dari UI karena filter !inner
    await supabase.from('shipping_request_details')
        .delete()
        .inFilter('shipping_id', idsToCancel);

    _showSnackBar("Berhasil membatalkan dan membersihkan data", Colors.grey.shade800);
    
    // Reset state UI
    setState(() {
      _expandedId = null;
      _selectedSLoc = null;
      _selectedDedicated = null;
    });
    
    // Refresh data agar list terupdate
    await _fetchData();
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal: $e", Colors.red);
  }
}

  // --- HELPER WIDGETS ---
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      hintText: hint,
    );
  }


  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Semua permintaan sudah diproses", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }


  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return "-";
    }
  }


  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

