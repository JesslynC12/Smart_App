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

class VendorPaginatedPage extends StatefulWidget {
  const VendorPaginatedPage({super.key});

  @override
  State<VendorPaginatedPage> createState() => _VendorPaginatedPageState();
}

class _VendorPaginatedPageState extends State<VendorPaginatedPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _vendors = [];
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

Future<void> _exportVendorToExcel() async {
  if (_vendors.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada data untuk diekspor"), backgroundColor: Colors.orange));
    return;
  }

  try {
    setState(() => _isLoading = true);
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Master_Vendor'];
    excel.delete('Sheet1');

    // --- 1. HEADER (Lengkap 25 Kolom) ---
    List<CellValue> headers = [
      TextCellValue('ID'), TextCellValue('Vendor Name'), TextCellValue('No Vendor'),
      TextCellValue('ID Rekomendasi'), TextCellValue('ID Standarisasi'), TextCellValue('QCF'),
      TextCellValue('Area'), TextCellValue('City'), TextCellValue('Jenis QCF'),
      TextCellValue('Type Unit'), TextCellValue('Winner Rank'), TextCellValue('Alokasi (%)'),
      TextCellValue('Transportation Mode'), TextCellValue('Alokasi Container'), TextCellValue('Cost Type'),
      TextCellValue('Fixed Cost'), TextCellValue('Variable Cost'), TextCellValue('Lokasi Gudang'),
      TextCellValue('Remark'), TextCellValue('Lead Time'), TextCellValue('POD Return'),
      TextCellValue('Shipment Type'), TextCellValue('Shipping Conditions'), TextCellValue('Special Proc'),
      TextCellValue('Vehicle Type'),
    ];
    sheetObject.appendRow(headers);

    // --- 2. ISI DATA ---
    for (var v in _vendors) {
      sheetObject.appendRow([
        TextCellValue(v['id']?.toString() ?? ""),
        TextCellValue(v['vendor_name'] ?? ""),
        TextCellValue(v['no_vendor'] ?? ""),
        TextCellValue(v['id_rekomendasi_winner'] ?? ""),
        TextCellValue(v['id_standarisasi'] ?? ""),
        TextCellValue(v['qcf'] ?? ""),
        TextCellValue(v['area'] ?? ""),
        TextCellValue(v['city'] ?? ""),
        TextCellValue(v['jenis_qcf'] ?? ""),
        TextCellValue(v['type_unit'] ?? ""),
        IntCellValue(int.tryParse(v['winner_rank']?.toString() ?? "0") ?? 0),
        DoubleCellValue((v['alokasi_persen'] ?? 0.0) * 100), // Kembalikan ke format 0-100
        TextCellValue(v['transportation_mode'] ?? ""),
        TextCellValue(v['alokasi_container'] ?? ""),
        TextCellValue(v['fix_var_cost'] ?? ""),
        DoubleCellValue(double.tryParse(v['fixed_cost']?.toString() ?? "0") ?? 0.0),
        DoubleCellValue(double.tryParse(v['variable_cost']?.toString() ?? "0") ?? 0.0),
        TextCellValue(v['lokasi_gudang'] ?? ""),
        TextCellValue(v['remark'] ?? ""),
        IntCellValue(int.tryParse(v['lead_time']?.toString() ?? "0") ?? 0),
        TextCellValue(v['pod_return']?.toString() ?? ""),
        TextCellValue(v['shipment_type'] ?? ""),
        TextCellValue(v['shipping_conditions'] ?? ""),
        TextCellValue(v['special_proc_indicator'] ?? ""),
        TextCellValue(v['vehicle_type'] ?? ""),
      ]);
    }

    // --- 3. SAVE / DOWNLOAD ---
    var fileBytes = excel.save();
    String fileName = "Master_Vendor_${DateTime.now().millisecondsSinceEpoch}.xlsx";

    if (kIsWeb) {
      final content = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(content);
      html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileName';
      io.File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      await OpenFile.open(filePath);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil ekspor ke Excel"), backgroundColor: Colors.green));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal Ekspor: $e"), backgroundColor: Colors.red));
  } finally {
    setState(() => _isLoading = false);
  }
}

Future<void> _importVendorFromExcel() async {
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
      if (row.isEmpty || row[1] == null) continue; // Skip jika nama vendor kosong

      double? alokasiRaw = double.tryParse(row[11]?.value?.toString() ?? "0");
      
      final Map<String, dynamic> data = {
        'vendor_name': row[1]?.value?.toString().toUpperCase().trim(),
        'no_vendor': row[2]?.value?.toString().trim(),
        'id_rekomendasi_winner': row[3]?.value?.toString().toUpperCase().trim(),
        'id_standarisasi': row[4]?.value?.toString().toUpperCase().trim(),
        'qcf': row[5]?.value?.toString().trim(),
        'area': row[6]?.value?.toString().toUpperCase().trim(),
        'city': row[7]?.value?.toString().toUpperCase().trim(),
        'jenis_qcf': row[8]?.value?.toString().trim(),
        'type_unit': row[9]?.value?.toString().trim(),
        'winner_rank': int.tryParse(row[10]?.value?.toString() ?? ""),
        'alokasi_persen': alokasiRaw != null ? alokasiRaw / 100 : 0, // Konversi balik ke desimal
        'transportation_mode': row[12]?.value?.toString().trim(),
        'alokasi_container': row[13]?.value?.toString().trim(),
        'fix_var_cost': row[14]?.value?.toString().trim(),
        'fixed_cost': double.tryParse(row[15]?.value?.toString() ?? "0"),
        'variable_cost': double.tryParse(row[16]?.value?.toString() ?? "0"),
        'lokasi_gudang': row[17]?.value?.toString().trim(),
        'remark': row[18]?.value?.toString().trim(),
        'lead_time': int.tryParse(row[19]?.value?.toString() ?? ""),
        'pod_return': row[20]?.value?.toString().trim(),
        'shipment_type': row[21]?.value?.toString().trim(),
        'shipping_conditions': row[22]?.value?.toString().trim(),
        'special_proc_indicator': row[23]?.value?.toString().trim(),
        'vehicle_type': row[24]?.value?.toString().trim(),
      };

      final idValue = int.tryParse(row[0]?.value.toString() ?? "");
      if (idValue != null) data['id'] = idValue;

      importData.add(data);
    }

    if (importData.isNotEmpty) {
      await supabase.from('vendor_transportasi').upsert(importData);
      _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Berhasil import ${importData.length} vendor"), backgroundColor: Colors.green));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Import: $e"), backgroundColor: Colors.red));
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
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

  // --- FETCH DATA ---
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var query = supabase.from('vendor_transportasi').select();

      if (_searchQuery.isNotEmpty) {
        // Pencarian berdasarkan Nama Vendor atau No Vendor
        query = query.or('vendor_name.ilike.%$_searchQuery%,no_vendor.ilike.%$_searchQuery%');
      }

      final data = await query.order('id', ascending: true);

      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DELETE DATA ---
  Future<void> _deleteVendor(int id) async {
    try {
      await supabase.from('vendor_transportasi').delete().match({'id': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data vendor berhasil dihapus"), backgroundColor: Colors.redAccent),
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
  Future<void> _saveData(bool isEdit, Map<String, dynamic> data) async {
    try {
      await supabase.from('vendor_transportasi').upsert(data);

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
  // void _showFormDialog([Map<String, dynamic>? vendor]) {
  //   final bool isEdit = vendor != null;

  //   // Controllers
  //   final idRekomController = TextEditingController(text: vendor?['id_rekomendasi_winner'] ?? '');
  //   final idStandarController = TextEditingController(text: vendor?['id_standarisasi'] ?? '');
  //   final qcfController = TextEditingController(text: vendor?['qcf'] ?? '');
  //   final areaController = TextEditingController(text: vendor?['area'] ?? '');
  //   final cityController = TextEditingController(text: vendor?['city'] ?? '');
  //   final jenisQcfController = TextEditingController(text: vendor?['jenis_qcf'] ?? '');
  //   final typeUnitController = TextEditingController(text: vendor?['type_unit'] ?? '');
  //   final rankController = TextEditingController(text: vendor?['winner_rank']?.toString() ?? '');
  //   final nameController = TextEditingController(text: vendor?['vendor_name'] ?? '');
  //   final alokasiPersenController = TextEditingController(text: vendor?['alokasi_persen']?.toString() ?? '');
  //   final lokasiGudangController = TextEditingController(text: vendor?['lokasi_gudang'] ?? '');
  //   final remarkController = TextEditingController(text: vendor?['remark'] ?? '');
  //   final leadTimeController = TextEditingController(text: vendor?['lead_time']?.toString() ?? '');
  //   final podReturnController = TextEditingController(text: vendor?['pod_return'] ?? '');
  //   final shipmentTypeController = TextEditingController(text: vendor?['shipment_type'] ?? '');
  //   final noVendorController = TextEditingController(text: vendor?['no_vendor'] ?? '');
  //   final shipConditionController = TextEditingController(text: vendor?['shipping_conditions'] ?? '');
  //   final specialProcController = TextEditingController(text: vendor?['special_proc_indicator'] ?? '');
  //   final vehicleTypeController = TextEditingController(text: vendor?['vehicle_type'] ?? '');

  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(isEdit ? 'Edit Vendor' : 'Tambah Vendor'),
  //       content: SizedBox(
  //         width: 500,
  //         child: SingleChildScrollView(
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               _buildField(nameController, 'Vendor Name*'),
  //               _buildField(noVendorController, 'No Vendor'),
  //               Row(
  //                 children: [
  //                   Expanded(child: _buildField(idRekomController, 'ID Rekomendasi')),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: _buildField(idStandarController, 'ID Standarisasi')),
  //                 ],
  //               ),
  //               Row(
  //                 children: [
  //                   Expanded(child: _buildField(qcfController, 'QCF')),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: _buildField(jenisQcfController, 'Jenis QCF')),
  //                 ],
  //               ),
  //               Row(
  //                 children: [
  //                   Expanded(child: _buildField(cityController, 'City')),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: _buildField(areaController, 'Area')),
  //                 ],
  //               ),
  //               Row(
  //                 children: [
  //                   Expanded(child: _buildField(typeUnitController, 'Type Unit')),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: _buildField(vehicleTypeController, 'Vehicle Type')),
  //                 ],
  //               ),
  //               Row(
  //                 children: [
  //                   Expanded(child: _buildField(rankController, 'Winner Rank', isNum: true)),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: _buildField(alokasiPersenController, 'Alokasi %', isNum: true)),
  //                 ],
  //               ),
  //               _buildField(lokasiGudangController, 'Lokasi Gudang'),
  //               Row(
  //                 children: [
  //                   Expanded(child: _buildField(leadTimeController, 'Lead Time', isNum: true)),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: _buildField(podReturnController, 'POD Return')),
  //                 ],
  //               ),
  //               _buildField(shipmentTypeController, 'Shipment Type'),
  //               _buildField(shipConditionController, 'Shipping Conditions'),
  //               _buildField(specialProcController, 'Special Proc Indicator'),
  //               _buildField(remarkController, 'Remark'),
  //             ],
  //           ),
  //         ),
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
  //         ElevatedButton(
  //           onPressed: () {
  //             if (nameController.text.isEmpty) return;
  //             final Map<String, dynamic> payload = {
  //               'id_rekomendasi_winner': idRekomController.text,
  //               'id_standarisasi': idStandarController.text,
  //               'qcf': qcfController.text,
  //               'area': areaController.text,
  //               'city': cityController.text,
  //               'jenis_qcf': jenisQcfController.text,
  //               'type_unit': typeUnitController.text,
  //               'winner_rank': int.tryParse(rankController.text),
  //               'vendor_name': nameController.text,
  //               'alokasi_persen': double.tryParse(alokasiPersenController.text),
  //               'lokasi_gudang': lokasiGudangController.text,
  //               'remark': remarkController.text,
  //               'lead_time': int.tryParse(leadTimeController.text),
  //               'pod_return': podReturnController.text,
  //               'shipment_type': shipmentTypeController.text,
  //               'no_vendor': noVendorController.text,
  //               'shipping_conditions': shipConditionController.text,
  //               'special_proc_indicator': specialProcController.text,
  //               'vehicle_type': vehicleTypeController.text,
  //             };
  //             if (isEdit) payload['id'] = vendor['id'];
  //             _saveData(isEdit, payload);
  //           },
  //           child: const Text("Simpan"),
  //         )
  //       ],
  //     ),
  //   );
  // }

// --- SAVE / EDIT DATA ---
  // Future<void> _saveData(bool isEdit, Map<String, dynamic> data) async {
  //   try {
  //     // Kita hapus created_at dari payload saat insert/update agar 
  //     // database yang menangani DEFAULT CURRENT_TIMESTAMP secara otomatis.
  //     data.remove('created_at');

  //     await supabase.from('vendor_transportasi').upsert(data);

  //     if (mounted) {
  //       Navigator.pop(context);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(isEdit ? "Data berhasil diperbarui" : "Data berhasil disimpan"),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     }
  //     _fetchData();
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
  //       );
  //     }
  //   }
  // }

// --- HELPER WIDGET UNTUK DROPDOWN ---
  Widget _buildDropdownField(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: (value == null || value.isEmpty || !items.contains(value)) ? null : value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // --- HELPER WIDGET UNTUK EDITABLE DROPDOWN (Autocomplete) ---
  Widget _buildEditableDropdown(TextEditingController ctrl, String label, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') return options;
          return options.where((String option) => option.contains(textEditingValue.text.toUpperCase()));
        },
        onSelected: (String selection) => ctrl.text = selection,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          // Sinkronisasi controller autocomplete dengan controller utama
          if (controller.text != ctrl.text) controller.text = ctrl.text;
          controller.addListener(() => ctrl.text = controller.text);
          
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
          );
        },
      ),
    );
  }

  // --- FORM DIALOG (Updated) ---
 void _showFormDialog([Map<String, dynamic>? vendor]) {
    final bool isEdit = vendor != null;

    // Controllers untuk semua kolom (Total 25 kolom dikelola)
    final idRekomController = TextEditingController(text: vendor?['id_rekomendasi_winner'] ?? '');
    final idStandarController = TextEditingController(text: vendor?['id_standarisasi'] ?? '');
    final qcfController = TextEditingController(text: vendor?['qcf'] ?? '');
    final cityController = TextEditingController(text: vendor?['city'] ?? '');
    final nameController = TextEditingController(text: vendor?['vendor_name'] ?? '');
    final noVendorController = TextEditingController(text: vendor?['no_vendor'] ?? '');
    final transModeController = TextEditingController(text: vendor?['transportation_mode'] ?? '');
    final alokasiContainerController = TextEditingController(text: vendor?['alokasi_container'] ?? '');
    final fixedCostController = TextEditingController(text: vendor?['fixed_cost']?.toString() ?? '');
    final variableCostController = TextEditingController(text: vendor?['variable_cost']?.toString() ?? '');
    final remarkController = TextEditingController(text: vendor?['remark'] ?? '');
    final leadTimeController = TextEditingController(text: vendor?['lead_time']?.toString() ?? '');
    final podReturnController = TextEditingController(text: vendor?['pod_return']?.toString() ?? '');
    //final alokasiPersenController = TextEditingController(text: vendor?['alokasi_persen']?.toString() ?? '');
    final alokasiPersenRaw = vendor?['alokasi_persen'];
    final alokasiPersenController = TextEditingController(
  text: alokasiPersenRaw != null ? (alokasiPersenRaw * 100).toString() : ''
);
    final specialProcController = TextEditingController(text: vendor?['special_proc_indicator'] ?? '');
    
    // Dropdown States
    String? selFixVar = vendor?['fix_var_cost'];
    String? selJenisQcf = vendor?['jenis_qcf'];
    String? selTypeUnit = vendor?['type_unit'];
    String? selRank = vendor?['winner_rank']?.toString();
    String? selGudang = vendor?['lokasi_gudang'];
    String? selShipType = vendor?['shipment_type'];
    String? selShipCond = vendor?['shipping_conditions'];
    String? selPartFunct = vendor?['part_funct'] ?? 'ZE';
    String? selVehicType = vendor?['vehicle_type'];

    // Editable Dropdown Controllers
    final areaController = TextEditingController(text: vendor?['area'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Vendor' : 'Tambah Vendor'),
          content: SizedBox(
            width: 800, // Diperlebar untuk kenyamanan input 25 kolom
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- SECTION 1: IDENTITAS VENDOR ---
                  _buildEditableDropdown(nameController, 'Vendor Name *', 
                    ['BKE', 'BLI', 'BP', 'BWI', 'DEJAVU', 'DUNEX', 'GRAHA TRANS', 'IRON BIRD', 'JPM', 'KAMADJAJA', 'KARURA', 'KS', 'MIF', 'MK', 'PAJ', 'PELANGI', 'SAMPLE', 'SILKARGO', 'TPIL']),
                  
                  Row(
                    children: [
                      Expanded(child: _buildField(noVendorController, 'No Vendor *', isNum: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildField(idRekomController, 'ID Rekomendasi Winner *')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildField(idStandarController, 'ID Standarisasi *')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildField(qcfController, 'QCF *', isNum: true)),
                    ],
                  ),

                  // --- SECTION 2: LOKASI & AREA ---
                  _buildEditableDropdown(areaController, 'Area *', 
                    ['BALI', 'BANTEN', 'GORONTALO', 'JABODETABEK', 'JAWA BARAT', 'JAWA TENGAH', 'JAWA TIMUR', 'KALIMANTAN BARAT', 'KALIMANTAN SELATAN', 'KALIMANTAN TENGAH', 'KALIMANTAN TIMUR', 'KALIMANTAN UTARA', 'KEPULAUAN RIAU', 'LAMPUNG', 'MALUKU', 'MALUKU UTARA', 'NTB', 'NTT', 'P. BANGKA & BELITUNG', 'PAPUA', 'PAPUA BARAT', 'RIAU', 'SULAWESI SELATAN', 'SULAWESI TENGGARA', 'SULAWESI TENGAH', 'SULAWESI UTARA', 'SUMATERA BARAT', 'SUMATERA SELATAN', 'SUMATERA UTARA']),
                  
                  Row(
                    children: [
                      Expanded(child: _buildField(cityController, 'City *')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdownField('Lokasi Gudang', selGudang, ['RUNGKUT', 'TAMBAK LANGON'], (v) => setDialogState(() => selGudang = v))),
                    ],
                  ),

                  // --- SECTION 3: KLASIFIKASI & UNIT ---
                  Row(
                    children: [
                      Expanded(child: _buildDropdownField('Jenis QCF *', selJenisQcf, ['AP', 'DP', 'STO', 'DEDICATED'], (v) => setDialogState(() => selJenisQcf = v))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdownField('Type Unit *', selTypeUnit, ['CDD', 'CDE', 'CONT', 'CONT (KA)', 'FUSO', 'WB', 'SAMPLE'], (v) => setDialogState(() => selTypeUnit = v))),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildDropdownField('Vehicle Type', selVehicType, ['CDD', 'CDE', 'FUS', 'WBX', 'BL042', 'BL033'], (v) => setDialogState(() => selVehicType = v))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdownField('Winner Rank *', selRank, ['1','2','3','4','5','6','7','8','9'], (v) => setDialogState(() => selRank = v))),
                    ],
                  ),

                  // --- SECTION 4: OPERASIONAL & LOGISTIK ---
                  Row(
                    children: [
                      Expanded(child: _buildField(transModeController, 'Transportation Mode')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildField(alokasiContainerController, 'Alokasi Container')),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
      width: 120, // Mengatur agar field lebih pendek
      child: _buildField(
        alokasiPersenController, 
        'Alokasi', 
        isDecimal: true,
      ),
    ),
                      //Expanded(child: _buildField(alokasiPersenController, 'Alokasi %', isDecimal: true)),
                      const SizedBox(width: 8),
                      const Text(
      "%", 
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    
    const SizedBox(width: 25), // Jarak antara grup Alokasi dengan field Lead Time
                      Expanded(child: _buildField(leadTimeController, 'Lead Time (Hari)', isNum: true)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildField(podReturnController, 'POD Return (Angka)', isNum: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdownField('Shipment Type', selShipType, ['ZBR2', 'ZBR3'], (v) => setDialogState(() => selShipType = v))),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildDropdownField('Shipping Condition', selShipCond, ['Y4', 'Y5'], (v) => setDialogState(() => selShipCond = v))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdownField('Part Funct', selPartFunct, ['ZE'], (v) => setDialogState(() => selPartFunct = v))),
                    ],
                  ),

                  // --- SECTION 5: COSTING & REMARK ---
                  _buildField(specialProcController, 'Special Proc Indicator', isNum: true),
                  Row(
                    children: [
                      Expanded(child: _buildDropdownField('Cost Type', selFixVar, ['FIX', 'VAR'], (v) => setDialogState(() => selFixVar = v))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildField(fixedCostController, 'Fixed Cost', isNum: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildField(variableCostController, 'Variable Cost', isNum: true)),
                    ],
                  ),
                  _buildField(remarkController, 'Remark', isMaxLines: true),
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
  onPressed: () {
    // 1. Validasi Kolom Wajib (*)
    if (nameController.text.trim().isEmpty ||
        noVendorController.text.trim().isEmpty ||
        idRekomController.text.trim().isEmpty ||
        idStandarController.text.trim().isEmpty ||
        qcfController.text.trim().isEmpty ||
        areaController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        selJenisQcf == null ||
        selTypeUnit == null ||
        selRank == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Harap isi semua kolom yang bertanda bintang (*)"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
              
                double? alokasiInput = double.tryParse(alokasiPersenController.text);
                
                if (alokasiInput != null && alokasiInput > 100) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Alokasi tidak boleh lebih dari 100%"))
  );
  return;
}
                // B. Konversi ke desimal (90 -> 0.9)
                double? alokasiDesimal = alokasiInput != null ? alokasiInput / 100 : null;
                final Map<String, dynamic> payload = {
                  'id_rekomendasi_winner': idRekomController.text.toUpperCase(),
                  'id_standarisasi': idStandarController.text.toUpperCase(),
                  'qcf': qcfController.text, // Tetap angka
                  'area': areaController.text.toUpperCase(),
                  'city': cityController.text.toUpperCase(),
                  'jenis_qcf': selJenisQcf,
                  'type_unit': selTypeUnit,
                  'winner_rank': int.tryParse(selRank ?? ''),
                  'vendor_name': nameController.text.toUpperCase(),
                  'transportation_mode': transModeController.text.toUpperCase(),
                  //'alokasi_persen': double.tryParse(alokasiPersenController.text),
                  'alokasi_persen': alokasiDesimal,
                  'alokasi_container': alokasiContainerController.text.toUpperCase(),
                  'fix_var_cost': selFixVar,
                  'fixed_cost': double.tryParse(fixedCostController.text),
                  'variable_cost': double.tryParse(variableCostController.text),
                  'lokasi_gudang': selGudang,
                  'remark': remarkController.text.toUpperCase(),
                  'lead_time': int.tryParse(leadTimeController.text),
                  'pod_return': podReturnController.text, 
                  'shipment_type': selShipType,
                  'no_vendor': noVendorController.text, // Tetap angka
                  'shipping_conditions': selShipCond,
                  'special_proc_indicator': specialProcController.text.toUpperCase(),
                  'part_funct': selPartFunct,
                  'vehicle_type': selVehicType,
                };
                if (isEdit) payload['id'] = vendor['id'];
                _saveData(isEdit, payload);
              },
              child: const Text("Simpan"),
            )
          ],
        ),
      ),
    );
  }

  // Widget _buildField(TextEditingController ctrl, String label, {bool isNum = false}) {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 8.0),
  //     child: TextField(
  //       controller: ctrl,
  //       keyboardType: isNum ? TextInputType.number : TextInputType.text,
  //       decoration: InputDecoration(
  //         labelText: label,
  //         border: const OutlineInputBorder(),
  //         isDense: true,
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildField(TextEditingController ctrl, String label, {bool isNum = false, bool isMaxLines = false}) {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 10),
  //     child: TextField(
  //       controller: ctrl,
  //       keyboardType: isNum ? TextInputType.number : TextInputType.text,
  //       maxLines: isMaxLines ? 3 : 1,
  //       // Otomatis ubah input menjadi Kapital saat mengetik
  //       onChanged: (value) {
  //         if (!isNum) {
  //           ctrl.value = ctrl.value.copyWith(
  //             text: value.toUpperCase(),
  //             selection: TextSelection.collapsed(offset: value.length),
  //           );
  //         }
  //       },
  //       decoration: InputDecoration(
  //         labelText: label,
  //         border: const OutlineInputBorder(),
  //         isDense: true,
  //       ),
  //     ),
  //   );
  // }

Widget _buildField(TextEditingController ctrl, String label, {bool isNum = false, bool isDecimal = false, bool isMaxLines = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: (isNum || isDecimal) ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: isMaxLines ? 3 : 1,
      // Pembatasan input agar hanya angka yang bisa masuk
      inputFormatters: [
        if (isNum) FilteringTextInputFormatter.digitsOnly, // Hanya angka bulat (int)
        if (isDecimal) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), // Angka & titik untuk desimal
      ],
      onChanged: (value) {
        if (!isNum && !isDecimal) {
          ctrl.value = ctrl.value.copyWith(
            text: value.toUpperCase(),
            selection: TextSelection.collapsed(offset: value.length),
          );
        }
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final dataContent = VendorDataSource(
      _vendors,
      context,
      onEdit: (v) => _showFormDialog(v),
      onDelete: (id) => _deleteVendor(id),
    );

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Master Vendor Transportasi', style: TextStyle(fontWeight: FontWeight.bold)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50),
              child: Column(
                children: [
                  // TextField(
                  //   controller: _searchController,
                  //   decoration: InputDecoration(
                  //     labelText: "Cari Nama atau No Vendor...",
                  //     prefixIcon: const Icon(Icons.search),
                  //     suffixIcon: IconButton(
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
    Expanded(
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: "Cari Nama atau No Vendor...",
          prefixIcon: const Icon(Icons.search),
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
    _buildActionButton(
      icon: Icons.file_upload,
      color: Colors.orange,
      tooltip: "Import Vendor",
      onPressed: _importVendorFromExcel,
    ),
    const SizedBox(width: 8),
    _buildActionButton(
      icon: Icons.download,
      color: Colors.green,
      tooltip: "Export Vendor",
      onPressed: _exportVendorToExcel,
    ),
  ],
),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      rowsPerPage: 10,
                      columnSpacing: 15,
                      columns: const [
                        DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('No Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
                        
                        DataColumn(label: Text('QCF', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Area', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Jenis QCF', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Type Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Alokasi %', style: TextStyle(fontWeight: FontWeight.bold))),
                        
                        DataColumn(label: Text('Lokasi', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Lead Time', style: TextStyle(fontWeight: FontWeight.bold))),
                        
                        DataColumn(label: Text('POD', style: TextStyle(fontWeight: FontWeight.bold))),
                        
                        DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      source: dataContent,
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

class VendorDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  VendorDataSource(this.data, this.context, {required this.onEdit, required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final v = data[index];

    return DataRow(cells: [
      DataCell(Text(v['id'].toString())),
      DataCell(Text(v['no_vendor'] ?? '-')),
      DataCell(Text(v['vendor_name'] ?? '-')),
      DataCell(Text(v['qcf'] ?? '-')),
      DataCell(Text(v['area'] ?? '-')),
      DataCell(Text(v['city'] ?? '-')),
      DataCell(Text(v['jenis_qcf'] ?? '-')),
      DataCell(Text(v['type_unit'] ?? '-')),
      DataCell(Text(v['winner_rank']?.toString() ?? '-')),
      //DataCell(Text("${v['alokasi_persen'] ?? 0}%")),
      DataCell(Text("${((v['alokasi_persen'] ?? 0) * 100).toStringAsFixed(0)}%")),
      DataCell(Text(v['lokasi_gudang'] ?? '-')),
      DataCell(Text("${v['lead_time'] ?? 0} Hari")),
      DataCell(Text("${v['pod_return'] ?? 0} Hari")),
      DataCell(Text(v['vehicle_type'] ?? '-')),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => onEdit(v)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirm(v['id'])),
        ],
      )),
    ]);
  }

  void _confirm(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus Vendor?"),
        content: const Text("Data vendor ini akan dihapus secara permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red.shade700,
    foregroundColor: Colors.white,
  ),
          
            onPressed: () {
              onDelete(id);
              Navigator.pop(c);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}