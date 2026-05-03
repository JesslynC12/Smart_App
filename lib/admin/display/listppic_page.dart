import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_file_plus/open_file_plus.dart';

class PPICListPage extends StatefulWidget {
  const PPICListPage({super.key});

  @override
  State<PPICListPage> createState() => _PPICListPageState();
}

class _PPICListPageState extends State<PPICListPage> {
  final supabase = Supabase.instance.client;

  // Variabel State
  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- LOGIC FETCH DATA ---
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // Mengambil data dari VIEW (pastikan kolom total_pallet sudah ada di VIEW)
      final data = await supabase
          .from('view_ppic_rekap')
          .select()
          .eq('tanggal', dateStr);

      setState(() {
        _allData = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Gagal memuat data: $e", Colors.red);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // appBar: AppBar(
      //   title: const Text("REKAP PRODUKSI PPIC",
      //       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
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

  Widget _buildPPICFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _fetchData(); 
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(
              DateFormat('dd/MM/yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _import,
            icon: const Icon(Icons.file_upload, color: Colors.orange),
            tooltip: "Import Excel",
            style: IconButton.styleFrom(
              backgroundColor: Colors.orange.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.file_download, color: Colors.green),
            tooltip: "Export Excel",
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIC IMPORT ---
  Future<void> _import() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null) return;

      setState(() => _isLoading = true);
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      var sheet = excel.tables.values.first;

      for (var i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row[0] == null) continue;

        String tgl = row[0]?.value.toString() ?? "";
        String type = row[1]?.value.toString().toLowerCase() ?? "";
        String shift = row[2]?.value.toString() ?? "";
        int mesinId = int.tryParse(row[3]?.value.toString() ?? "0") ?? 0;
        int matId = int.tryParse(row[4]?.value.toString() ?? "0") ?? 0;
        int qty = int.tryParse(row[5]?.value.toString() ?? "0") ?? 0;

        final headerRes = await supabase.from('ppic_forms').insert({
          'tanggal': tgl,
          'production_type': type,
          'created_by': 'Import System',
        }).select().single();

        await supabase.from('ppic_form_details').insert({
          'ppic_id': headerRes['ppic_id'],
          'shift': shift,
          'mesin_id': mesinId,
          'material_id': matId,
          'qty': qty,
        });
      }
      _showSnackBar("Import Berhasil!", Colors.green);
      _fetchData();
    } catch (e) {
      _showSnackBar("Gagal Import: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // // --- LOGIC EXPORT ---
  // Future<void> _exportToExcel() async {
  //   try {
  //     setState(() => _isLoading = true);
  //     var excel = Excel.createExcel();
  //     Sheet sheetObject = excel['Rekap Produksi'];
  //     excel.delete('Sheet1');

  //     sheetObject.appendRow([TextCellValue("REKAP PRODUKSI PPIC")]);
  //     sheetObject.appendRow([
  //       TextCellValue("ID MAT"),
  //       TextCellValue("DESCRIPTION"),
  //       TextCellValue("SHIFT I"),
  //       TextCellValue("SHIFT II"),
  //       TextCellValue("SHIFT III"),
  //       TextCellValue("TOTAL BOX"),
  //       TextCellValue("TOTAL PALLET")
  //     ]);

  //     for (var item in _allData) {
  //       // Ambil langsung dari kolom total_pallet hasil VIEW database
  //       sheetObject.appendRow([
  //         TextCellValue(item['material_id'].toString()),
  //         TextCellValue(item['material_name'] ?? '-'),
  //         IntCellValue(item['qty_shift_1'] ?? 0),
  //         IntCellValue(item['qty_shift_2'] ?? 0),
  //         IntCellValue(item['qty_shift_3'] ?? 0),
  //         IntCellValue(item['total_box'] ?? 0),
  //         TextCellValue(item['total_pallet']?.toString() ?? '0'),
  //       ]);
  //     }

  //     var fileBytes = excel.save();
  //     var directory = await getExternalStorageDirectory();
  //     String filePath = "${directory!.path}/Rekap_PPIC_${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx";

  //     File(filePath)
  //       ..createSync(recursive: true)
  //       ..writeAsBytesSync(fileBytes!);

  //     _showSnackBar("Export Berhasil!", Colors.green);
  //     await OpenFile.open(filePath);
  //   } catch (e) {
  //     _showSnackBar("Gagal Export: $e", Colors.red);
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }
  Future<void> _exportToExcel() async {
  try {
    setState(() => _isLoading = true);
    var excel = Excel.createExcel();
    
    Sheet sheetObject = excel['Rekap Produksi'];
    excel.delete('Sheet1');

    // 1. Buat Header Tabel (Ditambah Tanggal dan Type)
    sheetObject.appendRow([
      TextCellValue("TANGGAL"),
      TextCellValue("TYPE"),
      TextCellValue("ID MAT"),
      TextCellValue("DESCRIPTION"),
      TextCellValue("SHIFT I"),
      TextCellValue("SHIFT II"),
      TextCellValue("SHIFT III"),
      TextCellValue("TOTAL BOX"),
      TextCellValue("TOTAL PALLET"),
    ]);

    // 2. Isi Data dari _allData
    for (var item in _allData) {
      // Ambil data tanggal dan format agar rapi di Excel
      String rawDate = item['tanggal']?.toString() ?? "-";
      String prodType = (item['production_type']?.toString() ?? "-").toUpperCase();
      
      var palletValue = item['total_pallet']?.toString() ?? "0";
      var materialName = item['material_name'] ?? "-";
      var materialId = item['material_id']?.toString() ?? "-";

      sheetObject.appendRow([
        TextCellValue(rawDate),       // Kolom Tanggal
        TextCellValue(prodType),      // Kolom Type (MARSHO/FILLING)
        TextCellValue(materialId),
        TextCellValue(materialName),
        IntCellValue(item['qty_shift_1'] ?? 0),
        IntCellValue(item['qty_shift_2'] ?? 0),
        IntCellValue(item['qty_shift_3'] ?? 0),
        IntCellValue(item['total_box'] ?? 0),
        TextCellValue(palletValue),   // Total Pallet dari Database
      ]);
    }

    // 3. Simpan File ke Folder Internal (Aman dari Cross-Device Error)
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      // Nama file menggunakan tanggal yang sedang difilter
      String formattedFileName = DateFormat('yyyyMMdd').format(_selectedDate);
      String filePath = "${directory.path}/Rekap_PPIC_$formattedFileName.xlsx";

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      _showSnackBar("Export Berhasil!", Colors.green);
      
      // 4. Buka File secara otomatis
      await OpenFile.open(filePath);
    }
  } catch (e) {
    debugPrint("Error Export: $e");
    _showSnackBar("Gagal Export: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

  Widget _buildTableCard(String title, String type) {
    final filteredData = _allData.where((d) => d['production_type'] == type).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900)),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 45,
              dataRowHeight: 55,
              headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
              columns: const [
                DataColumn(label: Text('ID MAT')),
                DataColumn(label: Text('DESCRIPTION')),
                DataColumn(label: Text('S-I')),
                DataColumn(label: Text('S-II')),
                DataColumn(label: Text('S-III')),
                DataColumn(label: Text('TOTAL')),
                DataColumn(label: Text('PALLET')),
              ],
              rows: filteredData.isEmpty
                  ? [
                      const DataRow(cells: [
                        DataCell(Text("-")),
                        DataCell(Text("Tidak ada data")),
                        DataCell(Text("")),
                        DataCell(Text("")),
                        DataCell(Text("")),
                        DataCell(Text("")),
                        DataCell(Text(""))
                      ])
                    ]
                  : filteredData.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item['material_id'].toString())),
                        DataCell(SizedBox(
                            width: 120,
                            child: Text(item['material_name'] ?? '-',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis))),
                        DataCell(Text(item['qty_shift_1'].toString())),
                        DataCell(Text(item['qty_shift_2'].toString())),
                        DataCell(Text(item['qty_shift_3'].toString())),
                        DataCell(Text(item['total_box'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.indigo))),
                        DataCell(Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(
                                // Ambil langsung hasil CEIL dari database VIEW
                                item['total_pallet']?.toString() ?? '0',
                                style: const TextStyle(
                                    color: Colors.orange, fontWeight: FontWeight.bold)))),
                      ]);
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}