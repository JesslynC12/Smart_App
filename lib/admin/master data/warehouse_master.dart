import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:file_picker/file_picker.dart';

class WarehousePaginatedPage extends StatefulWidget {
  const WarehousePaginatedPage({super.key});

  @override
  State<WarehousePaginatedPage> createState() => _WarehousePaginatedPageState();
}

class _WarehousePaginatedPageState extends State<WarehousePaginatedPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

Future<void> _exportWarehouseToExcel() async {
  if (_warehouses.isEmpty) {
    _showMsg("Tidak ada data untuk diekspor", Colors.orange);
    return;
  }

  try {
    setState(() => _isLoading = true);
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Master_Warehouse'];
    excel.delete('Sheet1');

    // --- 1. HEADER ---
    List<CellValue> headers = [
      TextCellValue('WH Code'),
      TextCellValue('Warehouse Name'),
      TextCellValue('Lokasi'),
      TextCellValue('Kapasitas'),
      TextCellValue('Max Utilize'),
      TextCellValue('Tipe'),
      TextCellValue('Status'),
    ];
    sheetObject.appendRow(headers);

    // --- 2. ISI DATA ---
    for (var wh in _warehouses) {
      sheetObject.appendRow([
        TextCellValue(wh['wh_code']?.toString() ?? ""),
        TextCellValue(wh['warehouse_name'] ?? "-"),
        TextCellValue(wh['lokasi'] ?? "-"),
        IntCellValue(int.tryParse(wh['kapasitas']?.toString() ?? "0") ?? 0),
        IntCellValue(int.tryParse(wh['max_utilize']?.toString() ?? "0") ?? 0),
        TextCellValue(wh['tipe'] ?? "-"),
        TextCellValue(wh['status'] ?? "active"),
      ]);
    }

    // --- 3. SAVE / DOWNLOAD ---
    var fileBytes = excel.save();
    String fileName = "Master_Warehouse_${DateTime.now().millisecondsSinceEpoch}.xlsx";

    if (kIsWeb) {
      final content = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(content);
      html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
      html.Url.revokeObjectUrl(url);
      _showMsg("Download dimulai...", Colors.green);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileName';
      io.File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      await OpenFile.open(filePath);
      _showMsg("Berhasil ekspor ke Dokumen", Colors.green);
    }
  } catch (e) {
    _showMsg("Gagal Ekspor: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

Future<void> _importWarehouseFromExcel() async {
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

    List<Map<String, dynamic>> importData = [];

    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty || row[0] == null || row[1] == null) continue;

      importData.add({
        'wh_code': int.tryParse(row[0]?.value.toString() ?? ""),
        'warehouse_name': row[1]?.value?.toString(),
        'lokasi': row[2]?.value?.toString() ?? "Rungkut",
        'kapasitas': int.tryParse(row[3]?.value.toString() ?? "0"),
        'max_utilize': int.tryParse(row[4]?.value.toString() ?? "0"),
        'tipe': row[5]?.value?.toString() ?? "-",
        'status': row[6]?.value?.toString()?.toLowerCase() ?? "active",
      });
    }

    if (importData.isNotEmpty) {
      await supabase.from('warehouse').upsert(importData);
      _showMsg("Berhasil import ${importData.length} data gudang", Colors.green);
      _fetchData();
    } else {
      _showMsg("Tidak ada data valid di file Excel", Colors.orange);
    }
  } catch (e) {
    _showMsg("Error Import: $e", Colors.red);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

Widget _buildActionButton({required IconData icon, required Color color, required String tooltip, required VoidCallback onPressed}) {
  return Container(
    height: 50, // Disesuaikan agar sejajar dengan TextField
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 24),
      tooltip: tooltip,
    ),
  );
}

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var query = supabase.from('warehouse').select();
      final number = int.tryParse(_searchQuery);

  if (number != null) {
    // Jika input adalah angka:
    // Cari yang wh_code-nya SAMA PERSIS atau warehouse_name mengandung angka tersebut
    query = query.or('wh_code.eq.$number, warehouse_name.ilike.%$_searchQuery%');
  } else {
    // Jika input adalah teks:
    // Cukup cari di kolom warehouse_name
    query = query.ilike('warehouse_name', '%$_searchQuery%');
  }
    
      final data = await query.order('warehouse_id', ascending: true);

      if (mounted) {
        setState(() {
          _warehouses = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWarehouse(int id) async {
    try {
      await supabase.from('warehouse').delete().match({'warehouse_id': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data berhasil dihapus"), backgroundColor: Colors.redAccent),
        );
      }
      _fetchData();
    } catch (e) {
      debugPrint("Error Delete: $e");
    }
  }

  Future<void> _processSave(bool isEdit, int? id, String code, String name, String lokasi, String kapasitas, String maxUtilize, String tipe, String status) async {
    try {
      final payload = {
        'wh_code': int.tryParse(code),
        'warehouse_name': name,
        'lokasi': lokasi,
        'kapasitas': int.tryParse(kapasitas) ?? 0,
        'max_utilize': int.tryParse(maxUtilize) ?? 0,
        'tipe': tipe,
        'status': status,
      };

      if (isEdit && id != null) {
        payload['warehouse_id'] = id;
      }

      await supabase.from('warehouse').upsert(payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? "Data diperbarui" : "Data disimpan"), backgroundColor: Colors.green),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFormDialog([Map<String, dynamic>? warehouse]) {
    final bool isEdit = warehouse != null;

    final codeController = TextEditingController(text: warehouse?['wh_code']?.toString() ?? '');
    final nameController = TextEditingController(text: warehouse?['warehouse_name'] ?? '');
    final kapasitasController = TextEditingController(text: warehouse?['kapasitas']?.toString() ?? '');
    final maxUtilizeController = TextEditingController(text: warehouse?['max_utilize']?.toString() ?? '');
    final tipeController = TextEditingController(text: warehouse?['tipe'] ?? '');

    String rawStatus = (warehouse?['status'] ?? 'active').toString().toLowerCase();
    String selectedStatus = rawStatus == 'inactive' ? 'inactive' : 'active';

    String rawLokasi = (warehouse?['lokasi'] ?? 'Rungkut').toString();
    String selectedLokasi = ['Rungkut', 'Tambak Langon'].contains(rawLokasi) ? rawLokasi : 'Rungkut';

    final f1 = FocusNode();
    final f2 = FocusNode();
    final f3 = FocusNode();
    final f4 = FocusNode();
    final f5 = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Warehouse' : 'Tambah Warehouse'),
            content: SizedBox( // <-- Tambahkan SizedBox di sini
          width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNumberField(codeController, 'Warehouse Code *', f1, f2),
                  _buildTextField(nameController, 'Warehouse Name *', f2, f3),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      value: selectedLokasi,
                      decoration: const InputDecoration(labelText: 'Lokasi *', border: OutlineInputBorder()),
                      items: ['Rungkut', 'Tambak Langon'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (val) => setDialogState(() => selectedLokasi = val!),
                    ),
                  ),

                  _buildNumberField(kapasitasController, 'Kapasitas', f3, f4),
                  _buildNumberField(maxUtilizeController, 'Max Utilize', f4, f5),
                  // Field Tipe sekarang terintegrasi ke flow Enter
                  _buildTextField(tipeController, 'Tipe', f5, null, isLast: true),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                      items: ['active', 'inactive'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (val) => setDialogState(() => selectedStatus = val!),
                    ),
                  ),
                ],
              ),
            ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red.shade700,
    foregroundColor: Colors.white,
  ),
                onPressed: () => _validateAndSave(isEdit, warehouse?['warehouse_id'], codeController, nameController, selectedLokasi, kapasitasController, maxUtilizeController, tipeController, selectedStatus),
                child: const Text("Simpan"),
              )
            ],
          );
        },
      ),
    );
  }

  void _validateAndSave(bool isEdit, int? id, TextEditingController code, TextEditingController name, String lokasi, TextEditingController cap, TextEditingController max, TextEditingController type, String status) {
    if (code.text.isEmpty || name.text.isEmpty) {
      _showMsg("WH Code, Nama Warehouse, dan Lokasi wajib diisi!", Colors.orange);
      return;
    }
    _processSave(isEdit, id, code.text, name.text, lokasi, cap.text, max.text, type.text, status);
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _buildTextField(TextEditingController controller, String label, FocusNode current, FocusNode? next, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        focusNode: current,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        onSubmitted: (_) {
          if (next != null) {
            FocusScope.of(context).requestFocus(next);
          }
        },
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label, FocusNode current, FocusNode? next) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        focusNode: current,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(), 
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // helperText: "Input angka saja",
          helperStyle: const TextStyle(fontSize: 10)
        ),
        onSubmitted: (_) {
          if (next != null) {
            FocusScope.of(context).requestFocus(next);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = WarehouseDataSource(_warehouses, context, 
      onEdit: (wh) => _showFormDialog(wh), 
      onDelete: (id) => _deleteWarehouse(id)
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Warehouse'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50),
              child: Column(
                children: [
                  // TextField(
                  //   controller: _searchController,
                  //   decoration: InputDecoration(
                  //     labelText: "Cari Nama Warehouse...",
                  //     prefixIcon: const Icon(Icons.search),
                  //     contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  //     suffix: IconButton(
                  //       icon: const Icon(Icons.clear),
                  //       onPressed: () {
                  //         _searchController.clear();
                  //         _searchQuery = "";
                  //         _fetchData();
                  //       },
                  //     ),
                  //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  //   ),
                  //   onSubmitted: (val) {
                  //     _searchQuery = val;
                  //     _fetchData();
                  //   },
                  // ),
                  // Di dalam Widget build -> Column
Row(
  children: [
    // KOLOM PENCARIAN
    Expanded(
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: "Cari Nama Warehouse...",
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _searchQuery = "";
              _fetchData();
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onSubmitted: (val) {
          _searchQuery = val;
          _fetchData();
        },
      ),
    ),

    const SizedBox(width: 10),

    // TOMBOL IMPORT (ORANGE)
    _buildActionButton(
      icon: Icons.file_upload,
      color: Colors.orange,
      tooltip: "Import Warehouse",
      onPressed: _importWarehouseFromExcel,
    ),

    const SizedBox(width: 8),

    // TOMBOL EXPORT (HIJAU)
    _buildActionButton(
      icon: Icons.download,
      color: Colors.green,
      tooltip: "Export Warehouse",
      onPressed: _exportWarehouseToExcel,
    ),
  ],
),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      columnSpacing: 12,
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('WH Code', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nama Warehouse', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Lokasi', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Kapasitas', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Utilize', style: TextStyle(fontWeight: FontWeight.bold))),
                        // KOLOM TIPE DITAMBAHKAN DI SINI
                        DataColumn(label: Text('Tipe', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      source: source,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class WarehouseDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  WarehouseDataSource(this.data, this.context, {required this.onEdit, required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final wh = data[index];

  final String status = (wh['status'] ?? 'inactive').toString().toLowerCase();
  final bool isActive = status == 'active';

    return DataRow(cells: [
      DataCell(Text(wh['wh_code']?.toString() ?? '-')),
      DataCell(Text(wh['warehouse_name'] ?? '-')),
      DataCell(Text(wh['lokasi'] ?? '-')),
      DataCell(Text(wh['kapasitas']?.toString() ?? '0')),
      DataCell(Text("${wh['max_utilize'] ?? 0}")),
      // DATA TIPE DIMUNCULKAN DI SINI
      DataCell(Text(wh['tipe'] ?? '-')),
      DataCell(Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        wh['status']?.toString() ?? '-',
        style: TextStyle(
          color: isActive ? Colors.green.shade900 : Colors.red.shade900,
        ),
      ),
    )),
      DataCell(Row(
        children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => onEdit(wh)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirm(wh['warehouse_id'])),
        ],
      )),
    ]);
  }

  void _confirm(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus?"),
        content: const Text("Data ini akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red.shade700,
    foregroundColor: Colors.white,
  ),
          onPressed: () { onDelete(id); Navigator.pop(c); }, child: const Text("Hapus")),
        ],
      ),
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}