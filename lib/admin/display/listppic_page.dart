import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' as io; // Gunakan prefix io untuk Mobile
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart' hide Border;

class PPICListPage extends StatefulWidget {
  const PPICListPage({super.key});

  @override
  State<PPICListPage> createState() => _PPICListPageState();
}

class _PPICListPageState extends State<PPICListPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _displayData = [];
  List<Map<String, dynamic>> _materialList = [];
  List<Map<String, dynamic>> _mesinList = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  RealtimeChannel? _ppicSubscription;
bool _globalExportLock = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _listenToRealtime();
  }

  @override
  void dispose() {
    _ppicSubscription?.unsubscribe();
    super.dispose();
  }

  // Ambil Master Data (Material & Mesin) satu kali saja
  Future<void> _fetchInitialData() async {
    try {
      final mats = await supabase.from('material').select('material_id, material_name, box_per_pallet');
      final mes = await supabase.from('mesin').select('mesin_id, nama_mesin');
      setState(() {
        _materialList = List<Map<String, dynamic>>.from(mats);
        _mesinList = List<Map<String, dynamic>>.from(mes);
      });
      _fetchData();
    } catch (e) {
      debugPrint("Error initial data: $e");
    }
  }

  void _listenToRealtime() {
    _ppicSubscription = supabase
        .channel('public:ppic_form_details')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ppic_form_details',
          callback: (payload) {
            debugPrint("Data Changed: ${payload.eventType}");
            _fetchData();
          },
        )
        .subscribe();
  }

  // Future<void> _fetchData() async {
  //   if (!mounted) return;
  //   setState(() => _isLoading = true);
  //   try {
  //     final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

  //     final List<dynamic> rawData = await supabase
  //         .from('ppic_form_details')
  //         .select('''
  //           detail_id, shift, qty, mesin_id, material_id,
  //           ppic_forms!inner(ppic_id, tanggal, production_type),
  //           material(material_id, material_name, box_per_pallet),
  //           mesin(nama_mesin)
  //         ''')
  //         .eq('ppic_forms.tanggal', dateStr);

  //     final Map<String, Map<String, dynamic>> grouped = {};

  //     for (var row in rawData) {
  //       final form = row['ppic_forms'];
  //       final mat = row['material'];
  //       final mes = row['mesin'];
        
  //       String key = "${mat['material_id']}_${form['production_type']}";

  //       if (!grouped.containsKey(key)) {
  //         grouped[key] = {
  //           'ppic_id': form['ppic_id'],
  //           'production_type': form['production_type'],
  //           'material_id': mat['material_id'],
  //           'material_name': mat['material_name'],
  //           'mesin_id': row['mesin_id'],
  //           'nama_mesin': mes != null ? mes['nama_mesin'] : '-',
  //           'qty_shift_1': 0,
  //           'qty_shift_2': 0,
  //           'qty_shift_3': 0,
  //           'total_box': 0,
  //           'box_per_pallet': int.tryParse(mat['box_per_pallet'].toString()) ?? 1,
  //         };
  //       }

  //       int qty = int.tryParse(row['qty'].toString()) ?? 0;
  //       String shift = row['shift'].toString();

  //       if (shift == 'I') grouped[key]!['qty_shift_1'] += qty;
  //       else if (shift == 'II') grouped[key]!['qty_shift_2'] += qty;
  //       else if (shift == 'III') grouped[key]!['qty_shift_3'] += qty;

  //       grouped[key]!['total_box'] += qty;
  //     }

  //     final List<Map<String, dynamic>> processed = grouped.values.map((item) {
  //       double bpp = (item['box_per_pallet'] as int).toDouble();
  //       item['total_pallet'] = (item['total_box'] / bpp).ceil();
  //       return item;
  //     }).toList();

  //     setState(() {
  //       _displayData = processed;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //       _showSnackBar("Gagal memuat data: $e", Colors.red);
  //     }
  //   }
  // }

  Future<void> _fetchData() async {
  if (!mounted) return;
  setState(() => _isLoading = true);
  try {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final List<dynamic> rawData = await supabase
        .from('ppic_form_details')
        .select('''
          detail_id, shift, qty, mesin_id, material_id,
          ppic_forms!inner(ppic_id, tanggal, production_type),
          material(material_id, material_name, box_per_pallet),
          mesin(nama_mesin)
        ''')
        .eq('ppic_forms.tanggal', dateStr);

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var row in rawData) {
      final form = row['ppic_forms'];
      final mat = row['material'];
      final mes = row['mesin'];
      
      // PERBAIKAN: Key sekarang menyertakan mesin_id
      // Format: materialId_mesinId_prodType
      String key = "${mat['material_id']}_${row['mesin_id']}_${form['production_type']}";

      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'ppic_id': form['ppic_id'],
          'production_type': form['production_type'],
          'material_id': mat['material_id'],
          'material_name': mat['material_name'],
          'mesin_id': row['mesin_id'],
          'nama_mesin': mes != null ? mes['nama_mesin'] : '-',
          'qty_shift_1': 0,
          'qty_shift_2': 0,
          'qty_shift_3': 0,
          'total_box': 0,
          'box_per_pallet': int.tryParse(mat['box_per_pallet'].toString()) ?? 1,
        };
      }

      int qty = int.tryParse(row['qty'].toString()) ?? 0;
      String shift = row['shift'].toString();

      if (shift == 'I') grouped[key]!['qty_shift_1'] += qty;
      else if (shift == 'II') grouped[key]!['qty_shift_2'] += qty;
      else if (shift == 'III') grouped[key]!['qty_shift_3'] += qty;

      grouped[key]!['total_box'] += qty;
    }

    final List<Map<String, dynamic>> processed = grouped.values.map((item) {
      double bpp = (item['box_per_pallet'] as int).toDouble();
      item['total_pallet'] = (item['total_box'] / bpp).ceil();
      return item;
    }).toList();

    setState(() {
      _displayData = processed;
      _isLoading = false;
    });
  } catch (e) {
    // ... handle error
  }
}

  // Future<void> _handleEdit(Map<String, dynamic> item) async {
  //   // Ambil detail record asli dari DB
  //   final List<dynamic> details = await supabase
  //       .from('ppic_form_details')
  //       .select()
  //       .eq('ppic_id', item['ppic_id'])
  //       .eq('material_id', item['material_id'])
  //       .eq('mesin_id', item['mesin_id']);

  //   if (!mounted) return;

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setModalState) {
  //           return Padding(
  //             padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text("Edit Produksi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //                 const Divider(),
  //                 const SizedBox(height: 10),
  //                 // List per Shift
  //                 ...details.map((d) {
  //                   int? currentMatId = d['material_id'];
  //                   int? currentMesId = d['mesin_id'];
  //                   TextEditingController qCtrl = TextEditingController(text: d['qty'].toString());

  //                   return Container(
  //                     margin: const EdgeInsets.only(bottom: 15),
  //                     padding: const EdgeInsets.all(10),
  //                     decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
  //                     child: Column(
  //                       children: [
  //                         Row(
  //                           children: [
  //                             CircleAvatar(radius: 12, backgroundColor: Colors.red[700], child: Text(d['shift'], style: const TextStyle(color: Colors.white, fontSize: 12))),
  //                             const SizedBox(width: 10),
  //                             const Text("Shift Detail", style: TextStyle(fontWeight: FontWeight.bold)),
  //                           ],
  //                         ),
  //                         const SizedBox(height: 10),
  //                         // Dropdown Material
  //                         DropdownButtonFormField<int>(
  //                           value: currentMatId,
  //                           decoration: const InputDecoration(labelText: "Material", isDense: true),
  //                           items: _materialList.map((m) => DropdownMenuItem(value: m['material_id'] as int, child: Text(m['material_name']))).toList(),
  //                           onChanged: (val) => currentMatId = val,
  //                         ),
  //                         const SizedBox(height: 5),
  //                         // Dropdown Mesin
  //                         DropdownButtonFormField<int>(
  //                           value: currentMesId,
  //                           decoration: const InputDecoration(labelText: "Mesin", isDense: true),
  //                           items: _mesinList.map((m) => DropdownMenuItem(value: m['mesin_id'] as int, child: Text(m['nama_mesin']))).toList(),
  //                           onChanged: (val) => currentMesId = val,
  //                         ),
  //                         const SizedBox(height: 5),
  //                         // Qty
  //                         TextField(
  //                           controller: qCtrl,
  //                           keyboardType: TextInputType.number,
  //                           decoration: const InputDecoration(labelText: "Qty Box"),
  //                         ),
  //                         const SizedBox(height: 10),
  //                         ElevatedButton(
  //                           style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 36)),
  //                           onPressed: () async {
  //                             await supabase.from('ppic_form_details').update({
  //                               'material_id': currentMatId,
  //                               'mesin_id': currentMesId,
  //                               'qty': int.parse(qCtrl.text),
  //                             }).eq('detail_id', d['detail_id']);
  //                             _showSnackBar("Update Shift ${d['shift']} Berhasil", Colors.green);
  //                           },
  //                           child: const Text("Update Shift Ini"),
  //                         )
  //                       ],
  //                     ),
  //                   );
  //                 }).toList(),
  //                 const SizedBox(height: 20),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }
Future<void> _handleEdit(Map<String, dynamic> item) async {
  // 1. Ambil data detail asli dari tabel (bukan view)
  final List<dynamic> details = await supabase
      .from('ppic_form_details')
      .select()
      .eq('ppic_id', item['ppic_id'])
      .eq('material_id', item['material_id'])
      .eq('mesin_id', item['mesin_id']);

  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      // Menggunakan StatefulBuilder agar perubahan dropdown di dalam modal langsung terlihat
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                const Text("Edit Produksi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: details.length,
                    itemBuilder: (context, index) {
                      final d = details[index];
                      
                      // Inisialisasi controller dan data
                      final qCtrl = TextEditingController(text: d['qty'].toString());
                      
                      return Card(
                        color: Colors.grey[50],
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("SHIFT ${d['shift']}", 
                                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),

                              // DROPDOWN SEARCH MATERIAL (GAYA V6+)
                              const Text("Material", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              DropdownSearch<Map<String, dynamic>>(
                                items: (filter, loadProps) => _materialList,
                                itemAsString: (i) => "${i['material_id']} - ${i['material_name']}",
                                compareFn: (i, s) => i['material_id'].toString() == s['material_id'].toString(),
                                selectedItem: _materialList.firstWhere(
                                  (m) => m['material_id'] == d['material_id'],
                                  orElse: () => {},
                                ),
                                onChanged: (v) {
                                  if (v != null) d['material_id'] = v['material_id'];
                                },
                                decoratorProps: DropDownDecoratorProps(
                                  decoration: InputDecoration(
                                    isDense: true, filled: true, fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    hintText: "Cari Material",
                                  ),
                                ),
                                popupProps: const PopupProps.menu(
                                  showSearchBox: true,
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(hintText: "Ketik No Mat/Nama..."),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 15),

                              // DROPDOWN MESIN
                              const Text("Mesin", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<int>(
                                value: d['mesin_id'],
                                isDense: true,
                                decoration: InputDecoration(
                                  filled: true, fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: _mesinList.map((m) => DropdownMenuItem(
                                  value: m['mesin_id'] as int, 
                                  child: Text(m['nama_mesin'], style: const TextStyle(fontSize: 12))
                                )).toList(),
                                onChanged: (val) => d['mesin_id'] = val,
                              ),

                              const SizedBox(height: 15),

                              // INPUT QTY
                              const Text("Quantity", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: qCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true, filled: true, fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),

                              const SizedBox(height: 15),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green, 
                                  minimumSize: const Size(double.infinity, 45),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                ),
                                onPressed: () async {
                                  try {
                                    await supabase.from('ppic_form_details').update({
                                      'material_id': d['material_id'],
                                      'mesin_id': d['mesin_id'],
                                      'qty': int.parse(qCtrl.text),
                                    }).eq('detail_id', d['detail_id']);
                                    
                                    _showSnackBar("Update Berhasil", Colors.green);
                                  } catch (e) {
                                    _showSnackBar("Error: $e", Colors.red);
                                  }
                                },
                                child: const Text("SIMPAN SHIFT INI", 
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  Future<void> _handleDelete(Map<String, dynamic> item) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Baris"),
        content: Text("Hapus semua data produksi ${item['material_name']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text("Hapus", style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      try {
       await supabase
          .from('ppic_form_details')
          .delete()
          .eq('ppic_id', item['ppic_id'])
          .eq('material_id', item['material_id'])
          .eq('mesin_id', item['mesin_id']);
        _showSnackBar("Data berhasil dihapus", Colors.green);
      } catch (e) {
        _showSnackBar("Gagal: $e", Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildPPICFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTableCard("MARSHO PRODUCTION", "marsho"),
                          const SizedBox(height: 24),
                          _buildTableCard("FILLING PRODUCTION", "filling"),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(String title, String type) {
    final filtered = _displayData.where((d) => d['production_type'] == type).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: DataTable(
                columnSpacing: 6,
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text("NO MAT",style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("MATERIAL DESCRIPTION", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("MESIN", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("SHIFT I", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("SHIFT II", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("SHIFT III", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("PALLET",style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("AKSI", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filtered.isEmpty 
                  ? [DataRow(cells: List.generate(9, (index) => const DataCell(Text("-"))))]
                  : filtered.map((item) => DataRow(cells: [
                      DataCell(Text(item['material_id'].toString(), style: const TextStyle(fontSize: 12))),
                      DataCell(SizedBox(width: 260, child: Text(item['material_name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))),
                      DataCell(Text(item['nama_mesin'], style: const TextStyle(fontSize: 12))),
                      DataCell(Text(item['qty_shift_1'].toString())),
                      DataCell(Text(item['qty_shift_2'].toString())),
                      DataCell(Text(item['qty_shift_3'].toString())),
                      DataCell(Text(item['total_box'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(_buildSimpleBadge(item['total_pallet'].toString())),
                      DataCell(Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _handleEdit(item)),
                          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _handleDelete(item)),
                        ],
                      )),
                    ])).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPPICFilterBar() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.all(12),
      child: Row(children: [
        ElevatedButton.icon(
          onPressed: () async {
            final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2100));
            if (p != null) { setState(() => _selectedDate = p); _fetchData(); }
          },
          icon: const Icon(Icons.calendar_month), label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
        ),
        const Spacer(),
        IconButton(onPressed: _import, icon: const Icon(Icons.upload_file, color: Colors.orange)),
        IconButton(onPressed: _exportToExcel, icon: const Icon(Icons.download, color: Colors.green)),
      ]),
    );
  }

  Widget _buildSimpleBadge(String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
      child: Text("$val PALET", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
    );
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  // // LOGIC EXPORT
  // Future<void> _exportToExcel() async {
  //   try {
  //     setState(() => _isLoading = true);
  //     var excel = Excel.createExcel();
  //     Sheet sheetObject = excel['Rekap Produksi'];
  //     excel.delete('Sheet1');

  //     sheetObject.appendRow([TextCellValue("TANGGAL"), TextCellValue("TYPE"), TextCellValue("ID MAT"), TextCellValue("DESCRIPTION"), TextCellValue("SHIFT I"), TextCellValue("SHIFT II"), TextCellValue("SHIFT III"), TextCellValue("TOTAL BOX"), TextCellValue("TOTAL PALLET")]);

  //     for (var item in _displayData) {
  //       sheetObject.appendRow([
  //         TextCellValue(DateFormat('yyyy-MM-dd').format(_selectedDate)),
  //         TextCellValue(item['production_type'].toString().toUpperCase()),
  //         TextCellValue(item['material_id'].toString()),
  //         TextCellValue(item['material_name']),
  //         IntCellValue(item['qty_shift_1']),
  //         IntCellValue(item['qty_shift_2']),
  //         IntCellValue(item['qty_shift_3']),
  //         IntCellValue(item['total_box']),
  //         IntCellValue(item['total_pallet']),
  //       ]);
  //     }

  //     final fileBytes = excel.save();
  //     final directory = await getApplicationDocumentsDirectory();
  //     String filePath = "${directory.path}/Rekap_PPIC_${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx";
  //     final file = File(filePath);
  //     await file.writeAsBytes(fileBytes!);
  //     _showSnackBar("Export Berhasil!", Colors.green);
  //     await OpenFile.open(filePath);
  //   } catch (e) {
  //     _showSnackBar("Gagal Export: $e", Colors.red);
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }
Future<void> _exportToExcel() async {
  // Cegah export dobel atau jika data kosong
  if (_globalExportLock || _displayData.isEmpty) return;

  try {
    _globalExportLock = true;
    if (mounted) setState(() => _isLoading = true);

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Rekap_Produksi_PPIC'];
    excel.delete('Sheet1');

    // --- 1. HEADER ---
    List<CellValue> headers = [
      TextCellValue('Tanggal'),
      TextCellValue('Tipe Produksi'),
      TextCellValue('No Mat'),
      TextCellValue('Material Description'),
      TextCellValue('Mesin'),
      TextCellValue('Shift I'),
      TextCellValue('Shift II'),
      TextCellValue('Shift III'),
      TextCellValue('Total Box'),
      TextCellValue('Total Pallet'),
    ];
    sheetObject.appendRow(headers);

    // --- 2. ISI DATA ---
    for (var item in _displayData) {
      sheetObject.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(_selectedDate)),
        TextCellValue(item['production_type']?.toString().toUpperCase() ?? "-"),
        TextCellValue(item['material_id']?.toString() ?? "-"),
        TextCellValue(item['material_name'] ?? "-"),
        TextCellValue(item['nama_mesin'] ?? "-"),
        IntCellValue(item['qty_shift_1'] ?? 0),
        IntCellValue(item['qty_shift_2'] ?? 0),
        IntCellValue(item['qty_shift_3'] ?? 0),
        IntCellValue(item['total_box'] ?? 0),
        TextCellValue("${item['total_pallet'] ?? 0} PLT"),
      ]);
    }

    // --- 3. PROSES DOWNLOAD (Aman untuk Web & Mobile) ---
    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    String fileName = "Rekap_PPIC_${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx";

    if (kIsWeb) {
      // Logika Download untuk Browser
      final content = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(content);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);
      _showSnackBar("Excel berhasil diunduh!", Colors.green);
    } else {
      // Logika Simpan untuk Mobile/Desktop
      final directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileName';
      final file = io.File(filePath);
      
      await file.create(recursive: true);
      await file.writeAsBytes(fileBytes);
      
      _showSnackBar("File disimpan di Documents", Colors.green);
      await OpenFile.open(filePath);
    }

  } catch (e) {
    debugPrint("Export Error: $e");
    _showSnackBar("Gagal Export: $e", Colors.red);
  } finally {
    // Jeda keamanan
    await Future.delayed(const Duration(seconds: 1));
    _globalExportLock = false;
    if (mounted) setState(() => _isLoading = false);
  }
}
Future<void> _import() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    
    if (result == null) return;
    setState(() => _isLoading = true);

    var bytes = kIsWeb ? result.files.single.bytes : await io.File(result.files.single.path!).readAsBytes();
    var excel = Excel.decodeBytes(bytes!);
    var sheet = excel.tables.values.first;

    // 1. PETAKAN HEADER (Mencari posisi kolom berdasarkan nama)
    if (sheet.maxRows < 1) return;
    var headerRow = sheet.rows[0];
    Map<String, int> colMap = {};

    for (var i = 0; i < headerRow.length; i++) {
      String headerName = headerRow[i]?.value.toString().toLowerCase().trim() ?? "";
      if (headerName.contains("tanggal")) colMap["tanggal"] = i;
      if (headerName.contains("type")) colMap["type"] = i;
      if (headerName.contains("shift")) colMap["shift"] = i;
      if (headerName.contains("mesin")) colMap["mesin"] = i;
      if (headerName.contains("material")) colMap["material"] = i;
      if (headerName.contains("qty")) colMap["qty"] = i;
    }

    // Validasi apakah kolom minimal sudah ada
    if (!colMap.containsKey("tanggal") || !colMap.containsKey("material")) {
      throw "Kolom 'Tanggal' atau 'Material' tidak ditemukan!";
    }

    // 2. PROSES DATA PER BARIS
    for (var i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty) continue;

      // Ambil data berdasarkan mapping header
      String tgl = row[colMap["tanggal"]!]?.value.toString() ?? "";
      String type = row[colMap["type"]!]?.value.toString().toLowerCase() ?? "";
      String shift = row[colMap["shift"]!]?.value.toString() ?? "";
      String mesinRaw = row[colMap["mesin"]!]?.value.toString() ?? "";
      int matId = int.tryParse(row[colMap["material"]!]?.value.toString() ?? "0") ?? 0;
      int qty = int.tryParse(row[colMap["qty"]!]?.value.toString() ?? "0") ?? 0;

      if (tgl.isEmpty || matId == 0) continue;

      // 3. LOGIKA MESIN (Bisa ID atau Nama)
      int? finalMesinId = int.tryParse(mesinRaw);
      if (finalMesinId == null && mesinRaw.isNotEmpty) {
        // Jika bukan angka, cari ID berdasarkan Nama Mesin di _mesinList
        try {
          finalMesinId = _mesinList.firstWhere(
            (m) => m['nama_mesin'].toString().toLowerCase() == mesinRaw.toLowerCase(),
          )['mesin_id'];
        } catch (_) {
          finalMesinId = 0; // Tidak ditemukan
        }
      }

      // 4. UPSERT HEADER & INSERT DETAIL
      final headerRes = await supabase.from('ppic_forms').upsert({
        'tanggal': tgl,
        'production_type': type,
        'created_by': 'Import System',
      }).select().single();

      await supabase.from('ppic_form_details').insert({
        'ppic_id': headerRes['ppic_id'],
        'shift': shift,
        'mesin_id': finalMesinId ?? 0,
        'material_id': matId,
        'qty': qty,
      });
    }

    _showSnackBar("Import Berhasil!", Colors.green);
    _fetchData();
  } catch (e) {
    _showSnackBar("Gagal: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}
}