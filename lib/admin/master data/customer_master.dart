import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:file_picker/file_picker.dart';

class CustomerPaginatedPage extends StatefulWidget {
  const CustomerPaginatedPage({super.key});

  @override
  State<CustomerPaginatedPage> createState() => _CustomerPaginatedPageState();
}

class _CustomerPaginatedPageState extends State<CustomerPaginatedPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _customers = [];
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

  // --- REFRESH / FETCH DATA ---
  Future<void> _fetchData() async {
  if (!mounted) return;
  setState(() => _isLoading = true);

  try {
    // Tambahkan range jika datanya sangat banyak, 
    // atau pastikan kebijakan API Supabase Anda mengizinkan fetch besar.
    var query = supabase.from('customer').select();

    if (_searchQuery.isNotEmpty) {
      final isNumber = int.tryParse(_searchQuery) != null;
      if (isNumber) {
        query = query.eq('customer_id', int.parse(_searchQuery));
      } else {
        query = query.ilike('customer_name', '%$_searchQuery%');
      }
    }
    
    // Gunakan order dan pastikan tidak ada limit yang tertahan
    final data = await query.order('customer_id', ascending: true);

    if (mounted) {
      setState(() {
        _customers = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint("Error Fetch: $e");
    if (mounted) setState(() => _isLoading = false);
  }
}

// Future<void> _importCustomerFromExcel() async {
//   try {
//     // 1. Pilih File
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['xlsx'],
//       withData: true, // Penting agar bisa dibaca di Web & Mobile
//     );

//     if (result == null) return; // User membatalkan

//     setState(() => _isLoading = true);

//     // 2. Baca Excel
//     var bytes = result.files.first.bytes;
//     var excel = Excel.decodeBytes(bytes!);
//     var sheet = excel.tables.values.first; // Ambil sheet pertama

//     List<Map<String, dynamic>> importData = [];

//     // 3. Iterasi baris (mulai dari index 1 karena index 0 adalah Header)
//     for (int i = 1; i < sheet.maxRows; i++) {
//       var row = sheet.rows[i];
//       if (row.isEmpty || row[0] == null) continue;

//       // Ambil data berdasarkan urutan kolom (sesuaikan dengan urutan saat Export)
//       // row[0] = No Cust, row[1] = Nama, dst.
//       importData.add({
//         'customer_id': int.tryParse(row[0]?.value.toString() ?? ""),
//         'customer_name': row[1]?.value.toString()?? "-",
//         'customer_type': row[2]?.value.toString()?? "-",
//         'del_type': row[3]?.value.toString()?? "-",
//         'city': row[4]?.value.toString()?? "-",
//         'area': row[5]?.value.toString()?? "-",
//         'report_area': row[6]?.value.toString()?? "-",
//         'pod_area': row[7]?.value.toString()?? "-",
//       });
//     }

//     if (importData.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("File Excel kosong atau format salah"), backgroundColor: Colors.orange),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     // 4. Kirim ke Supabase (Upsert)
//     await supabase.from('customer').upsert(importData);

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Berhasil import ${importData.length} data customer")),
//     );
//     _fetchData(); // Refresh tabel

//   // } catch (e) {
//   //   setState(() => _isLoading = false);
//   //   debugPrint("Import Error: $e");
//   //   ScaffoldMessenger.of(context).showSnackBar(
//   //     SnackBar(content: Text("Gagal Import: Format file mungkin tidak sesuai"), backgroundColor: Colors.red),
//   //   );
//   } catch (e) {
//   setState(() => _isLoading = false);
//   // Tampilkan pesan error asli (e) agar kita tahu salahnya di mana
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
//   );
//   print("Detail Error Import: $e");
// }
//   }

Future<void> _importCustomerFromExcel() async {
  try {
    // Pastikan menggunakan FileType.any atau custom yang tepat
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true, // WAJIB untuk Web
    );

    if (result == null || result.files.isEmpty) {
      print("User membatalkan pilihan file");
      return; 
    }

    setState(() => _isLoading = true);

    // Ambil bytes dengan cara yang lebih aman
    final platformFile = result.files.first;
    final bytes = platformFile.bytes;

    if (bytes == null) {
      throw "Gagal membaca data file (Bytes kosong)";
    }

    var excel = Excel.decodeBytes(bytes);
    
    // Pastikan ada table/sheet di dalamnya
    if (excel.tables.isEmpty) {
      throw "File Excel tidak memiliki sheet";
    }

    var sheet = excel.tables.values.first;
    List<Map<String, dynamic>> importData = [];

    // Loop data (abaikan header baris 0)
    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      
      // Lewati jika baris benar-benar kosong atau kolom ID (row[0]) kosong
      if (row.isEmpty || row[0] == null || row[0]?.value == null) continue;

      importData.add({
        'customer_id': int.tryParse(row[0]?.value.toString() ?? ""),
        'customer_name': row[1]?.value?.toString() ?? "-",
        'customer_type': row[2]?.value?.toString() ?? "-",
        'del_type': row[3]?.value?.toString() ?? "-",
        'city': row[4]?.value?.toString() ?? "-",
        'area': row[5]?.value?.toString() ?? "-",
        'report_area': row[6]?.value?.toString() ?? "-",
        'pod_area': row[7]?.value?.toString() ?? "-",
      });
    }

    if (importData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tidak ada data valid yang ditemukan di Excel"), backgroundColor: Colors.orange),
      );
    } else {
      await supabase.from('customer').upsert(importData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Berhasil import ${importData.length} data!"), backgroundColor: Colors.green),
      );
      _fetchData();
    }

  } catch (e) {
    print("Detail Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

Future<void> _exportCustomerToExcel() async {
  if (_customers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Tidak ada data untuk diekspor"), backgroundColor: Colors.orange),
    );
    return;
  }

  try {
    setState(() => _isLoading = true);

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Master_Customer'];
    excel.delete('Sheet1');

    // --- 1. HEADER ---
    List<CellValue> headers = [
      TextCellValue('No Cust'),
      TextCellValue('Nama Customer'),
      TextCellValue('Customer Type'),
      TextCellValue('Del Type'),
      TextCellValue('City'),
      TextCellValue('Area'),
      TextCellValue('Report Area'),
      TextCellValue('POD Area'),
    ];
    sheetObject.appendRow(headers);

    // --- 2. ISI DATA ---
    for (var cust in _customers) {
      sheetObject.appendRow([
        TextCellValue(cust['customer_id']?.toString() ?? ""),
        TextCellValue(cust['customer_name'] ?? "-"),
        TextCellValue(cust['customer_type'] ?? "-"),
        TextCellValue(cust['del_type'] ?? "-"),
        TextCellValue(cust['city'] ?? "-"),
        TextCellValue(cust['area'] ?? "-"),
        TextCellValue(cust['report_area'] ?? "-"),
        TextCellValue(cust['pod_area'] ?? "-"),
      ]);
    }

    // --- 3. PROSES SIMPAN/DOWNLOAD ---
    var fileBytes = excel.save();
    String fileName = "Master_Customer_${DateTime.now().millisecondsSinceEpoch}.xlsx";

    if (kIsWeb) {
      // Logic Web
      final content = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(content);
      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download dimulai..."), backgroundColor: Colors.green));
    } else {
      // Logic Android
      final directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileName';
      io.File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes!);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File berhasil disimpan"), backgroundColor: Colors.green));
      await OpenFile.open(filePath);
    }

    setState(() => _isLoading = false);
  } catch (e) {
    setState(() => _isLoading = false);
    debugPrint("Export Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal ekspor: $e"), backgroundColor: Colors.red));
  }
}

  // --- DELETE DATA ---
  Future<void> _deleteCustomer(int id) async {
    try {
      await supabase.from('customer').delete().match({'customer_id': id});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data customer berhasil dihapus"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus: $e"), backgroundColor: Colors.black),
        );
      }
    }
  }

  // --- SAVE / EDIT DATA ---
  Future<void> _saveData(
    bool isEdit,
    TextEditingController id,
    TextEditingController name,
    TextEditingController type,
    TextEditingController del,
    TextEditingController city,
    TextEditingController area,
    TextEditingController report,
    TextEditingController pod,
  ) async {
    try {
      await supabase.from('customer').upsert({
        'customer_id': int.parse(id.text),
        'customer_name': name.text,
        'customer_type': type.text,
        'del_type': del.text,
        'city': city.text,
        'area': area.text,
        'report_area': report.text,
        'pod_area': pod.text,
      });

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? "Data berhasil diperbarui" : "Data berhasil disimpan"),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FORM DIALOG ---
  void _showFormDialog([Map<String, dynamic>? customer]) {
    final bool isEdit = customer != null;
    final idController = TextEditingController(text: customer?['customer_id']?.toString() ?? '');
    final nameController = TextEditingController(text: customer?['customer_name'] ?? '');
    final typeController = TextEditingController(text: customer?['customer_type'] ?? '');
    final delTypeController = TextEditingController(text: customer?['del_type'] ?? '');
    final cityController = TextEditingController(text: customer?['city'] ?? '');
    final areaController = TextEditingController(text: customer?['area'] ?? '');
    final reportController = TextEditingController(text: customer?['report_area'] ?? '');
    final podController = TextEditingController(text: customer?['pod_area'] ?? '');

    final f1 = FocusNode(); final f2 = FocusNode(); final f3 = FocusNode();
    final f4 = FocusNode(); final f5 = FocusNode(); final f6 = FocusNode();
    final f7 = FocusNode(); final f8 = FocusNode();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Customer' : 'Tambah Customer'),
        content: SizedBox( // <-- Tambahkan SizedBox di sini
          width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(idController, 'No Cust *', f1, f2, !isEdit, isNumber: true),
              _buildTextField(nameController, 'Nama Customer *', f2, f3, true),
              _buildTextField(typeController, 'Customer Type', f3, f4, true),
              _buildTextField(delTypeController, 'Del Type', f4, f5, true),
              _buildTextField(cityController, 'City', f5, f6, true),
              _buildTextField(areaController, 'Area *', f6, f7, true),
              _buildTextField(reportController, 'Report Area', f7, f8, true),
              _buildTextField(podController, 'POD Area', f8, null, true, isLast: true, onSave: () {
                _validateAndSave(isEdit, idController, nameController, typeController, delTypeController, cityController, areaController, reportController, podController);
              }),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade700, // Warna background tombol
      foregroundColor: Colors.white,       // Warna teks/icon tombol
    ),
            onPressed: () => _validateAndSave(isEdit, idController, nameController, typeController, delTypeController, cityController, areaController, reportController, podController),
            child: const Text("Simpan"),
          )
        ],
      ),
    );
  }

  void _validateAndSave(bool isEdit, TextEditingController id, TextEditingController name, TextEditingController type, TextEditingController del, TextEditingController city, TextEditingController area, TextEditingController report, TextEditingController pod) {
    if (id.text.isEmpty || name.text.isEmpty || area.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Cust, Nama, dan Area tidak boleh kosong!"), backgroundColor: Colors.orange),
      );
      return;
    }
    _saveData(isEdit, id, name, type, del, city, area, report, pod);
  }

  Widget _buildTextField(TextEditingController controller, String label, FocusNode current, FocusNode? next, bool enabled, {bool isNumber = false, bool isLast = false, VoidCallback? onSave}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        focusNode: current,
        enabled: enabled,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: !enabled,
          fillColor: enabled ? null : Colors.grey.shade200,
        ),
        onSubmitted: (_) {
          if (isLast && onSave != null) {
            onSave();
          } else if (next != null) {
            FocusScope.of(context).requestFocus(next);
          }
        },
      ),
    );
  }

//   @override
//   Widget build(BuildContext context) {
//     final DataTableSource dataContent = CustomerDataSource(
//       _customers,
//       context,
//       onEdit: (cust) => _showFormDialog(cust),
//       onDelete: (id) => _deleteCustomer(id),
//     );

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Master Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//         backgroundColor: Colors.red.shade700,
//         foregroundColor: Colors.white,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(50),
//               child: Column(
//                 children: [
                  
//                   // --- SEARCH BAR DENGAN ICON SILANG (CLEAR) ---
//                   ValueListenableBuilder<TextEditingValue>(
//                     valueListenable: _searchController,
//                     builder: (context, value, child) {
//                       return TextField(
//                         controller: _searchController,
//                         decoration: InputDecoration(
//                           labelText: "Cari Nama Customer...",
//                           prefixIcon: const Icon(Icons.search),
//                           // Munculkan icon silang HANYA jika ada teks
//                           suffixIcon: value.text.isNotEmpty
//                               ? IconButton(
//                                   icon: const Icon(Icons.clear),
//                                   onPressed: () {
//                                     _searchController.clear();
//                                     _searchQuery = "";
//                                     _fetchData(); // Ambil semua data lagi
//                                   },
//                                 )
//                               : null,
//                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                         ),
//                         onSubmitted: (val) {
//                           _searchQuery = val;
//                           _fetchData();
//                         },
//                       );
//                     },
//                   ),
//                   const SizedBox(height: 20),
//                   SizedBox(
//                     width: double.infinity,
//                     child: Theme(
//     // Opsional: Agar scrollbar selalu terlihat (khusus desktop/web)
//     data: Theme.of(context).copyWith(scrollbarTheme: ScrollbarThemeData(
//       thumbVisibility: WidgetStateProperty.all(true),
//     )),
//      child: PaginatedDataTable(
//                      columnSpacing: 12, 
//                         rowsPerPage: 10,
//                       columns: const [
//   DataColumn(label: Text('No Cust', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('Nama Customer', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('Del Type', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('Area', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('Report Area', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('POD Area', style: TextStyle(fontWeight: FontWeight.bold))),
//   DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
// ],
//                       source: dataContent,
//                     ),
//                   ),
//     ),
//                 ],
//               ),
//             ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _showFormDialog(),
//         backgroundColor: Colors.red.shade700,
//         child: const Icon(Icons.add, color: Colors.white),
//       ),
//     );
//   }


@override
  Widget build(BuildContext context) {
    final DataTableSource dataContent = CustomerDataSource(
      _customers,
      context,
      onEdit: (cust) => _showFormDialog(cust),
      onDelete: (id) => _deleteCustomer(id),
    );

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Master Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50), // Saya kecilkan padding agar pas di mobile/web
              child: Column(
                children: [
                  // --- ROW PENCARIAN & TOMBOL EXPORT ---
                  Row(
                    children: [
                      // Kolom Pencarian
                      Expanded(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            return TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: "Cari Nama Customer...",
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: value.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchQuery = "";
                                          _fetchData();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onSubmitted: (val) {
                                _searchQuery = val;
                                _fetchData();
                              },
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(width: 10),
// TOMBOL IMPORT (Kuning/Orange)
    _buildActionButton(
      icon: Icons.file_upload,
      color: Colors.orange,
      tooltip: "Import Excel",
      onPressed: _importCustomerFromExcel,
    ),

    const SizedBox(width: 8),
                      // TOMBOL EXPORT EXCEL
                      Container(
                        height: 55, // Samakan tinggi dengan TextField
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: IconButton(
                          onPressed: _exportCustomerToExcel,
                          icon: const Icon(Icons.file_download, color: Colors.green, size: 26),
                          tooltip: "Export Excel",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- TABEL DATA ---
                  SizedBox(
                    width: double.infinity,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        scrollbarTheme: ScrollbarThemeData(
                          thumbVisibility: WidgetStateProperty.all(true),
                        ),
                      ),
                      child: PaginatedDataTable(
                        columnSpacing: 12,
                        rowsPerPage: 10,
                        columns: const [
                          DataColumn(label: Text('No Cust', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Nama Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Del Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Area', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Report Area', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('POD Area', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        source: dataContent,
                      ),
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

Widget _buildActionButton({required IconData icon, required Color color, required String tooltip, required VoidCallback onPressed}) {
  return Container(
    height: 55,
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 26),
      tooltip: tooltip,
    ),
  );
}
}

// --- DATA SOURCE CLASS ---
class CustomerDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  CustomerDataSource(this.data, this.context, {required this.onEdit, required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final cust = data[index];

    return DataRow(cells: [
      DataCell(Text(cust['customer_id'].toString())),
      DataCell(Text(cust['customer_name'] ?? '-')),
      DataCell(Text(cust['customer_type'] ?? '-')),
      DataCell(Text(cust['del_type'] ?? '-')),
      DataCell(Text(cust['city'] ?? '-')),
      DataCell(Text(cust['area'] ?? '-')),
      DataCell(Text(cust['report_area'] ?? '-')),
      DataCell(Text(cust['pod_area'] ?? '-')),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => onEdit(cust)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirm(cust['customer_id'])),
        ],
      )),
    ]);
  }


  void _confirm(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus?"),
        content: const Text("Data yang dihapus tidak dapat dikembalikan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade700, // Warna background tombol
      foregroundColor: Colors.white,       // Warna teks/icon tombol
    ),
            onPressed: () {
              onDelete(id);
              Navigator.pop(c);
            },
            child: const Text("Ya, Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;

  
}