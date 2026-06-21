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
  List<Map<String, dynamic>> _masterVendorList = [];
  List<String> _existingAreas = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _initializeAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        supabase
            .from('vendor_transportasi')
            .select('*, master_vendor(nik, vendor_name)')
            .order('id', ascending: true),
        supabase
            .from('master_vendor')
            .select('nik, vendor_name')
            .order('vendor_name', ascending: true),
      ]);

      final ruteData = List<Map<String, dynamic>>.from(results[0]);

      final Set<String> uniqueAreas = {};
      for (var rute in ruteData) {
        if (rute['area'] != null && rute['area'].toString().trim().isNotEmpty) {
          uniqueAreas.add(rute['area'].toString().toUpperCase().trim());
        }
      }

      if (mounted) {
        setState(() {
          _vendors = ruteData;
          _masterVendorList = List<Map<String, dynamic>>.from(results[1]);
          _existingAreas = uniqueAreas.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Initialize: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportVendorToExcel() async {
    if (_vendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tidak ada data untuk diekspor"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Master_Vendor'];
      excel.delete('Sheet1');

      List<CellValue> headers = [
        TextCellValue('ID'),
        TextCellValue('Vendor Name'),
        TextCellValue('No Vendor'),
        TextCellValue('ID Rekomendasi'),
        TextCellValue('ID Standarisasi'),
        TextCellValue('QCF'),
        TextCellValue('Area'),
        TextCellValue('City'),
        TextCellValue('Jenis QCF'),
        TextCellValue('Type Unit'),
        TextCellValue('Winner Rank'),
        TextCellValue('Transportation Mode'),
        TextCellValue('Alokasi (%)'),
        TextCellValue('Alokasi Container'),
        TextCellValue('Cost Type'),
        TextCellValue('Fixed Cost'),
        TextCellValue('Variable Cost'),
        TextCellValue('Lokasi Gudang'),
        TextCellValue('Remark'),
        TextCellValue('Lead Time'),
        TextCellValue('POD Return'),
        TextCellValue('Shipment Type'),
        TextCellValue('Shipping Conditions'),
        TextCellValue('Special Proc'),
        TextCellValue('Part Funct'),
        TextCellValue('Vehicle Type'),
      ];
      sheetObject.appendRow(headers);

      for (var v in _vendors) {
        final masterData = v['master_vendor'] as Map<String, dynamic>?;
        final String vendorName =
            masterData?['vendor_name'] ?? v['vendor_name'] ?? "-";
        final String noVendor = masterData?['nik'] ?? v['no_vendor'] ?? "-";
        sheetObject.appendRow([
          TextCellValue(v['id']?.toString() ?? ""),
          TextCellValue(vendorName),
          TextCellValue(noVendor),
          TextCellValue(v['id_rekomendasi_winner'] ?? ""),
          TextCellValue(v['id_standarisasi'] ?? ""),
          TextCellValue(v['qcf'] ?? ""),
          TextCellValue(v['area'] ?? ""),
          TextCellValue(v['city'] ?? ""),
          TextCellValue(v['jenis_qcf'] ?? ""),
          TextCellValue(v['type_unit'] ?? ""),
          IntCellValue(int.tryParse(v['winner_rank']?.toString() ?? "0") ?? 0),
          TextCellValue(v['transportation_mode'] ?? ""),
          DoubleCellValue(
            double.tryParse(v['alokasi_persen']?.toString() ?? "0.0") ?? 0.0,
          ),
          TextCellValue(v['alokasi_container'] ?? ""),
          TextCellValue(v['fix_var_cost'] ?? ""),
          DoubleCellValue(
            double.tryParse(v['fixed_cost']?.toString() ?? "0") ?? 0.0,
          ),
          DoubleCellValue(
            double.tryParse(v['variable_cost']?.toString() ?? "0") ?? 0.0,
          ),
          TextCellValue(v['lokasi_gudang'] ?? ""),
          TextCellValue(v['remark'] ?? ""),
          IntCellValue(int.tryParse(v['lead_time']?.toString() ?? "0") ?? 0),
          TextCellValue(v['pod_return']?.toString() ?? ""),
          TextCellValue(v['shipment_type'] ?? ""),
          TextCellValue(v['shipping_conditions'] ?? ""),
          TextCellValue(v['special_proc_indicator'] ?? ""),
          TextCellValue(v['part_funct'] ?? ""),
          TextCellValue(v['vehicle_type'] ?? ""),
        ]);
      }

      String fileName =
          "Master_Vendor_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      var fileBytes = excel.save(fileName: fileName);
      if (kIsWeb) {
        final content = html.Blob([
          fileBytes,
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(content);
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        String filePath = '${directory.path}/$fileName';
        io.File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes!);
        await OpenFile.open(filePath);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Berhasil ekspor ke Excel"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal Ekspor: $e"),
          backgroundColor: Colors.red,
        ),
      );
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
        if (row.isEmpty || row.length < 25) continue;
        if (row[20]?.value == null) continue;

        int? parseInt(dynamic value) =>
            value == null ? null : int.tryParse(value.toString().trim());
        double? parseDouble(dynamic value) =>
            value == null ? null : double.tryParse(value.toString().trim());

        double? parsePercentage(dynamic value) {
          if (value == null) return null;
          String cleanValue = value.toString().trim();
          if (cleanValue.isEmpty) return null;

          if (cleanValue.contains('%')) {
            cleanValue = cleanValue.replaceAll('%', '').trim();
            double? number = double.tryParse(cleanValue);
            return number != null ? number / 100 : null;
          }

          double? directNumber = double.tryParse(cleanValue);
          if (directNumber != null) {
            if (directNumber > 1) return directNumber / 100;
            return directNumber;
          }
          return null;
        }

        final Map<String, dynamic> data = {
          'id_rekomendasi_winner': row[0]?.value
              ?.toString()
              .toUpperCase()
              .trim(),
          'id_standarisasi': row[1]?.value?.toString().toUpperCase().trim(),
          'qcf': row[2]?.value?.toString().trim(),
          'area': row[3]?.value?.toString().toUpperCase().trim(),
          'city': row[4]?.value?.toString().toUpperCase().trim(),
          'jenis_qcf': row[5]?.value?.toString().trim(),

          'type_unit': row[6]?.value?.toString().trim(),
          'winner_rank': parseInt(row[7]?.value),
          'vendor_name': row[8]?.value?.toString().toUpperCase().trim(),
          'transportation_mode': row[9]?.value?.toString().toUpperCase().trim(),
          'alokasi_persen': parsePercentage(row[10]?.value),
          'alokasi_container': row[11]?.value?.toString().toUpperCase().trim(),

          'fix_var_cost': row[12]?.value?.toString().toUpperCase().trim(),
          'fixed_cost': parseDouble(row[13]?.value),
          'variable_cost': parseDouble(row[14]?.value),
          'lokasi_gudang': row[15]?.value?.toString().toUpperCase().trim(),

          'remark': row[16]?.value?.toString().toUpperCase().trim(),
          'lead_time': parseInt(row[17]?.value),
          'pod_return': row[18]?.value?.toString().trim(),
          'shipment_type': row[19]?.value?.toString().trim(),
          'nik': row[20]?.value?.toString().trim(),
          'shipping_conditions': row[21]?.value?.toString().trim(),

          'special_proc_indicator': row[22]?.value
              ?.toString()
              .toUpperCase()
              .trim(),
          'part_funct': row[23]?.value?.toString().trim(),
          'vehicle_type': row[24]?.value?.toString().trim(),
        };
        importData.add(data);
      }

      if (importData.isNotEmpty) {
        await supabase.from('vendor_transportasi').upsert(importData);
        _initializeAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Berhasil mengimport ${importData.length} data vendor",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Tidak ada data valid yang ditemukan di file Excel",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error Import: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengimport data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 26),
        tooltip: tooltip,
      ),
    );
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    try {
      var query = supabase
          .from('vendor_transportasi')
          .select('*, master_vendor(nik, vendor_name)');

      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'city.ilike.%$_searchQuery%,'
          'area.ilike.%$_searchQuery%,'
          'nik.ilike.%$_searchQuery%,'
          'id_rekomendasi_winner.ilike.%$_searchQuery%,'
          'id_standarisasi.ilike.%$_searchQuery%,'
          'master_vendor.vendor_name.ilike.%$_searchQuery%',
        );
      }

      final data = await query.order('id', ascending: true);

      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Mencoba fallback search query...");
      _fetchDataFallback();
    }
  }

  Future<void> _fetchDataFallback() async {
    try {
      var query = supabase
          .from('vendor_transportasi')
          .select('*, master_vendor(nik, vendor_name)');

      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'city.ilike.%$_searchQuery%, area.ilike.%$_searchQuery%, nik.ilike.%$_searchQuery%',
        );
      }

      final data = await query.order('id', ascending: true);
      List<Map<String, dynamic>> temporaryList =
          List<Map<String, dynamic>>.from(data);
      if (_searchQuery.isNotEmpty) {
        final dataFull = await supabase
            .from('vendor_transportasi')
            .select('*, master_vendor(nik, vendor_name)')
            .order('id', ascending: true);
        final allData = List<Map<String, dynamic>>.from(dataFull);

        temporaryList = allData.where((v) {
          final master = v['master_vendor'] as Map<String, dynamic>?;
          final String vName =
              master?['vendor_name']?.toString().toLowerCase() ?? '';
          final String city = v['city']?.toString().toLowerCase() ?? '';
          final String area = v['area']?.toString().toLowerCase() ?? '';
          final String nik = v['nik']?.toString().toLowerCase() ?? '';
          final String idRekom =
              v['id_rekomendasi_winner']?.toString().toLowerCase() ?? '';
          final String idStandar =
              v['id_standarisasi']?.toString().toLowerCase() ?? '';
          final String q = _searchQuery.toLowerCase();

          return vName.contains(q) ||
              city.contains(q) ||
              area.contains(q) ||
              nik.contains(q) ||
              idRekom.contains(q) ||
              idStandar.contains(q);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _vendors = temporaryList;
          _isLoading = false;
        });
      }
    } catch (err) {
      debugPrint("Error Fallback Fetch: $err");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memuat data: $err"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteVendor(int id) async {
    try {
      await supabase.from('vendor_transportasi').delete().match({'id': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data vendor berhasil dihapus"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus: $e"),
            backgroundColor: Colors.black,
          ),
        );
      }
    }
  }

  Future<void> _saveData(bool isEdit, Map<String, dynamic> data) async {
    try {
      await supabase.from('vendor_transportasi').upsert(data);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit ? "Data berhasil diperbarui" : "Data berhasil disimpan",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _initializeAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Terjadi kesalahan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: (value == null || value.isEmpty || !items.contains(value))
            ? null
            : value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildComboboxAreaField(
    TextEditingController ctrl,
    String label,
    List<String> options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return options;
          return options.where(
            (String option) =>
                option.contains(textEditingValue.text.toUpperCase()),
          );
        },
        onSelected: (String selection) {
          ctrl.text = selection.toUpperCase();
        },
        fieldViewBuilder:
            (context, textController, focusNode, onFieldSubmitted) {
              if (textController.text != ctrl.text) {
                textController.text = ctrl.text;
              }
              textController.addListener(() {
                ctrl.text = textController.text.toUpperCase();
              });

              return TextField(
                controller: textController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                onChanged: (val) {
                  ctrl.text = val.toUpperCase();
                },
              );
            },
      ),
    );
  }

  void _showFormDialog([Map<String, dynamic>? vendor]) {
    final bool isEdit = vendor != null;

    final idRekomController = TextEditingController(
      text: vendor?['id_rekomendasi_winner'] ?? '',
    );
    final idStandarController = TextEditingController(
      text: vendor?['id_standarisasi'] ?? '',
    );
    final qcfController = TextEditingController(text: vendor?['qcf'] ?? '');
    final cityController = TextEditingController(text: vendor?['city'] ?? '');
    final transModeController = TextEditingController(
      text: vendor?['transportation_mode'] ?? '',
    );
    final alokasiContainerController = TextEditingController(
      text: vendor?['alokasi_container'] ?? '',
    );
    final fixedCostController = TextEditingController(
      text: vendor?['fixed_cost']?.toString() ?? '',
    );
    final variableCostController = TextEditingController(
      text: vendor?['variable_cost']?.toString() ?? '',
    );
    final remarkController = TextEditingController(
      text: vendor?['remark'] ?? '',
    );
    final leadTimeController = TextEditingController(
      text: vendor?['lead_time']?.toString() ?? '',
    );
    final podReturnController = TextEditingController(
      text: vendor?['pod_return']?.toString() ?? '',
    );
    final alokasiPersenRaw = vendor?['alokasi_persen'];
    final alokasiPersenController = TextEditingController(
      text: alokasiPersenRaw != null ? (alokasiPersenRaw * 100).toString() : '',
    );
    final specialProcController = TextEditingController(
      text: vendor?['special_proc_indicator'] ?? '',
    );

    String? selectedNik = vendor?['nik'] ?? vendor?['master_vendor']?['nik'];
    String? selFixVar = vendor?['fix_var_cost'];
    String? selJenisQcf = vendor?['jenis_qcf'];
    String? selTypeUnit = vendor?['type_unit'];
    String? selRank = vendor?['winner_rank']?.toString();
    String? selGudang = vendor?['lokasi_gudang'];
    String? selShipType = vendor?['shipment_type'];
    String? selShipCond = vendor?['shipping_conditions'];
    String? selPartFunct = vendor?['part_funct'] ?? 'ZE';
    String? selVehicType = vendor?['vehicle_type'];

    final areaController = TextEditingController(text: vendor?['area'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Vendor' : 'Tambah Vendor'),
          content: SizedBox(
            width: 800,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _masterVendorList.any((v) => v['nik'] == selectedNik)
                          ? selectedNik
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Vendor (NIK - Nama Vendor) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _masterVendorList.map((v) {
                        return DropdownMenuItem<String>(
                          value: v['nik'].toString(),
                          child: Text("${v['nik']} - ${v['vendor_name']}"),
                        );
                      }).toList(),
                      onChanged: isEdit
                          ? null
                          : (val) {
                              setDialogState(() {
                                selectedNik = val;
                              });
                            },
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          idRekomController,
                          'ID Rekomendasi Winner *',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          idStandarController,
                          'ID Standarisasi *',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(qcfController, 'QCF *', isNum: true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildField(cityController, 'City *')),
                    ],
                  ),

                  _buildComboboxAreaField(
                    areaController,
                    'Area *',
                    _existingAreas,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Lokasi Gudang',
                          selGudang,
                          ['RUNGKUT', 'TAMBAK LANGON'],
                          (v) => setDialogState(() => selGudang = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdownField(
                          'Jenis QCF *',
                          selJenisQcf,
                          ['AP', 'DP', 'STO', 'DEDICATED'],
                          (v) => setDialogState(() => selJenisQcf = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Type Unit *',
                          selTypeUnit,
                          [
                            'CDD',
                            'CDE',
                            'CONT',
                            'CONT (KA)',
                            'FUSO',
                            'WB',
                            'SAMPLE',
                          ],
                          (v) => setDialogState(() => selTypeUnit = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdownField(
                          'Vehicle Type',
                          selVehicType,
                          ['CDD', 'CDE', 'FUS', 'WBX', 'BL042', 'BL033'],
                          (v) => setDialogState(() => selVehicType = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Winner Rank *',
                          selRank,
                          ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
                          (v) => setDialogState(() => selRank = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          transModeController,
                          'Transportation Mode',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          alokasiContainerController,
                          'Alokasi Container',
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: _buildField(
                          alokasiPersenController,
                          'Alokasi',
                          isDecimal: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "%",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          leadTimeController,
                          'Lead Time (Hari)',
                          isNum: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          podReturnController,
                          'POD Return (Angka)',
                          isNum: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Shipment Type',
                          selShipType,
                          ['ZBR2', 'ZBR3'],
                          (v) => setDialogState(() => selShipType = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdownField(
                          'Shipping Condition',
                          selShipCond,
                          ['Y4', 'Y5'],
                          (v) => setDialogState(() => selShipCond = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Part Funct',
                          selPartFunct,
                          ['ZE'],
                          (v) => setDialogState(() => selPartFunct = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          specialProcController,
                          'Special Proc Indicator',
                          isNum: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Cost Type',
                          selFixVar,
                          ['FIX', 'VAR'],
                          (v) => setDialogState(() => selFixVar = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          fixedCostController,
                          'Fixed Cost',
                          isNum: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          variableCostController,
                          'Variable Cost',
                          isNum: true,
                        ),
                      ),
                    ],
                  ),
                  _buildField(remarkController, 'Remark', isMaxLines: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final selectedVendorMap = _masterVendorList.firstWhere(
                  (v) => v['nik'] == selectedNik,
                  orElse: () => {},
                );
                final String currentVendorName =
                    selectedVendorMap['vendor_name'] ?? '';

                if (selectedNik == null ||
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
                      content: Text(
                        "Harap isi semua kolom yang bertanda bintang (*)",
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                double? alokasiInput = double.tryParse(
                  alokasiPersenController.text,
                );

                if (alokasiInput != null && alokasiInput > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Alokasi tidak boleh lebih dari 100%"),
                    ),
                  );
                  return;
                }
                double? alokasiDesimal = alokasiInput != null
                    ? alokasiInput / 100
                    : null;
                final Map<String, dynamic> payload = {
                  'nik': selectedNik,
                  'vendor_name': currentVendorName.toUpperCase(),
                  'id_rekomendasi_winner': idRekomController.text.toUpperCase(),
                  'id_standarisasi': idStandarController.text.toUpperCase(),
                  'qcf': qcfController.text,
                  'area': areaController.text.toUpperCase(),
                  'city': cityController.text.toUpperCase(),
                  'jenis_qcf': selJenisQcf,
                  'type_unit': selTypeUnit,
                  'winner_rank': int.tryParse(selRank ?? ''),
                  'transportation_mode': transModeController.text.toUpperCase(),
                  'alokasi_persen': alokasiDesimal,
                  'alokasi_container': alokasiContainerController.text
                      .toUpperCase(),
                  'fix_var_cost': selFixVar,
                  'fixed_cost': double.tryParse(fixedCostController.text),
                  'variable_cost': double.tryParse(variableCostController.text),
                  'lokasi_gudang': selGudang,
                  'remark': remarkController.text.toUpperCase(),
                  'lead_time': int.tryParse(leadTimeController.text),
                  'pod_return': podReturnController.text,
                  'shipment_type': selShipType,
                  'shipping_conditions': selShipCond,
                  'special_proc_indicator': specialProcController.text
                      .toUpperCase(),
                  'part_funct': selPartFunct,
                  'vehicle_type': selVehicType,
                };
                if (isEdit) payload['id'] = vendor['id'];
                _saveData(isEdit, payload);
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    bool isNum = false,
    bool isDecimal = false,
    bool isMaxLines = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: (isNum || isDecimal)
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: isMaxLines ? 3 : 1,
        inputFormatters: [
          if (isNum) FilteringTextInputFormatter.digitsOnly,
          if (isDecimal) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText:
                                "Cari Nama, No Vendor, Kota, atau Area...",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = "";
                                      });
                                      _fetchData();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {});
                          },
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
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'ID',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'No Vendor',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Nama',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ID Rekomendasi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ID Standarisasi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'QCF',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Area',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'City',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Jenis QCF',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Type Unit',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Rank',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Alokasi %',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Lokasi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Lead Time',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'POD',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Vehicle',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Aksi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
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

  VendorDataSource(
    this.data,
    this.context, {
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final v = data[index];

    final masterVendor = v['master_vendor'] as Map<String, dynamic>?;
    final String displayNoVendor =
        masterVendor?['nik'] ?? v['no_vendor'] ?? v['nik'] ?? '-';
    final String displayVendorName =
        masterVendor?['vendor_name'] ?? v['vendor_name'] ?? '-';

    return DataRow(
      cells: [
        DataCell(Text(v['id'].toString())),
        DataCell(Text(displayNoVendor)),
        DataCell(Text(displayVendorName)),
        DataCell(Text(v['id_rekomendasi_winner'] ?? '-')),
        DataCell(Text(v['id_standarisasi'] ?? '-')),
        DataCell(Text(v['qcf'] ?? '-')),
        DataCell(Text(v['area'] ?? '-')),
        DataCell(Text(v['city'] ?? '-')),
        DataCell(Text(v['jenis_qcf'] ?? '-')),
        DataCell(Text(v['type_unit'] ?? '-')),
        DataCell(Text(v['winner_rank']?.toString() ?? '-')),
        DataCell(
          Text("${((v['alokasi_persen'] ?? 0) * 100).toStringAsFixed(0)}%"),
        ),
        DataCell(Text(v['lokasi_gudang'] ?? '-')),
        DataCell(Text("${v['lead_time'] ?? 0} Hari")),
        DataCell(Text("${v['pod_return'] ?? 0} Hari")),
        DataCell(Text(v['vehicle_type'] ?? '-')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => onEdit(v),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirm(v['id']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirm(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus Vendor?"),
        content: const Text("Data vendor ini akan dihapus secara permanen."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Batal"),
          ),
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

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => data.length;
  @override
  int get selectedRowCount => 0;
}
