import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';

class ShippingRequestPage extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const ShippingRequestPage({super.key, this.editData});

  @override
  State<ShippingRequestPage> createState() => _ShippingRequestPageState();
}

class _ShippingRequestPageState extends State<ShippingRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController _stuffingDateController = TextEditingController();
  final TextEditingController _tanggalRDDController = TextEditingController();
  final TextEditingController _soNumberController = TextEditingController();
  final TextEditingController _doHeaderController = TextEditingController();

  final TextEditingController _tempDoController = TextEditingController();
  final TextEditingController _tempQtyController = TextEditingController();

  DateTime? _stuffingDate;
  DateTime? _tanggalRDD;

  String? selectedCustomerId;
  String? userDisplayName;

  List<Map<String, dynamic>> selectedMaterials = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> materialList = [];
  Map<String, dynamic>? _tempSelectedMaterial;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    if (widget.editData != null) {
      _loadDataForEdit();
    } else {
      _stuffingDateController.text = "";
    }
    _doHeaderController.addListener(() {
      if (_tempDoController.text.isEmpty ||
          _tempDoController.text == _doHeaderController.text) {
        _tempDoController.text = _doHeaderController.text;
      }
    });

    _fetchInitialData();
  }

  void _loadDataForEdit() {
    final data = widget.editData!;
    _soNumberController.text = data['so'] ?? '';
    _tanggalRDD = DateTime.tryParse(data['rdd'] ?? '');
    _stuffingDate = DateTime.tryParse(data['stuffing_date'] ?? '');

    if (_tanggalRDD != null)
      _tanggalRDDController.text = DateFormat(
        'dd/MM/yyyy',
      ).format(_tanggalRDD!);
    if (_stuffingDate != null)
      _stuffingDateController.text = DateFormat(
        'dd/MM/yyyy',
      ).format(_stuffingDate!);

    final List dos = data['delivery_order'] ?? [];
    for (var doItem in dos) {
      for (var det in (doItem['do_details'] as List)) {
        selectedMaterials.add({
          "do_number": doItem['do_number'],
          "customer_id": doItem['customer_id'].toString(),
          "customer_name": doItem['customer']?['customer_name'] ?? "",
          "material_id": det['material_id'].toString(),
          "material_name": det['material']?['material_name'] ?? "",
          "qty": det['qty'].toString(),
          "date_created": _formatTanggal(data['date_createdDO']),
        });
      }
    }
  }

  Future<void> _importExcelToForm() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => isLoading = true);

      final bytes = result.files.first.bytes;
      var excel = Excel.decodeBytes(bytes!);
      var sheet = excel.tables.values.first;

      if (sheet.maxRows > 1) {
        String _getVal(List<Data?> row, int index) {
          if (index >= row.length ||
              row[index] == null ||
              row[index]!.value == null)
            return "";
          return row[index]!.value.toString().trim();
        }

        DateTime? _parseIndoDate(String dateStr) {
          if (dateStr.isEmpty) return null;
          try {
            String cleanedDate = dateStr.replaceAll('/', '-');
            return DateFormat('dd-MM-yyyy').parseStrict(cleanedDate);
          } catch (e) {
            return DateTime.tryParse(dateStr);
          }
        }

        var firstDataRow = sheet.rows[1];

        setState(() {
          _soNumberController.text = _getVal(firstDataRow, 1);

          DateTime? rdd = _parseIndoDate(_getVal(firstDataRow, 7));
          DateTime? stuffing = _parseIndoDate(_getVal(firstDataRow, 8));

          if (rdd != null) {
            _tanggalRDD = rdd;
            _tanggalRDDController.text = DateFormat('dd/MM/yyyy').format(rdd);
          }

          if (stuffing != null) {
            _stuffingDate = stuffing;
            _stuffingDateController.text = DateFormat(
              'dd/MM/yyyy',
            ).format(stuffing);
          }

          String custIdFromExcel = _getVal(firstDataRow, 2);
          if (custIdFromExcel.isNotEmpty) {
            selectedCustomerId = custIdFromExcel;
          }
          selectedMaterials.clear();
          for (int i = 1; i < sheet.maxRows; i++) {
            var row = sheet.rows[i];
            String doNum = _getVal(row, 0);
            if (doNum.isEmpty || doNum.toLowerCase() == "no do") continue;

            selectedMaterials.add({
              "do_number": doNum,
              "customer_id": _getVal(row, 2),
              "customer_name": _getVal(row, 3),
              "material_id": _getVal(row, 4),
              "material_name": _getVal(row, 5),
              "qty": _getVal(row, 6),
            });
          }
        });

        _showSnackBar(
          "Impor Berhasil: Header terisi & ${selectedMaterials.length} item masuk tabel",
          Colors.green,
        );
      }
    } catch (e) {
      debugPrint("Error Import: $e");
      _showSnackBar(
        "Gagal mengimpor file. Periksa format kolom Excel Anda.",
        Colors.red,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _stuffingDateController.dispose();
    _tanggalRDDController.dispose();
    _soNumberController.dispose();
    _doHeaderController.dispose();
    _tempDoController.dispose();
    _tempQtyController.dispose();
    super.dispose();
  }

  Future<String?> _checkDoExistence(String doNumber) async {
    try {
      final response = await supabase
          .from('delivery_order')
          .select('''
          do_number,
          shipping_request (
            stuffing_date
          )
        ''')
          .eq('do_number', doNumber)
          .maybeSingle();

      if (response != null && response['shipping_request'] != null) {
        final rawDate = response['shipping_request']['stuffing_date'];
        if (rawDate != null) {
          DateTime date = DateTime.parse(rawDate);
          return DateFormat('dd/MM/yyyy').format(date);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error checking DO: $e");
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Peringatan"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchInitialData() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final profileResponse = await supabase
            .from('profiles')
            .select('name')
            .eq('id', currentUser.id)
            .single();

        userDisplayName = profileResponse['name'];
      }
      final materialResponse = await supabase
          .from('material')
          .select('material_id, material_name')
          .order('material_name', ascending: true);

      if (mounted) {
        setState(() {
          materialList = List<Map<String, dynamic>>.from(materialResponse);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showSnackBar("Gagal mengambil data: $e", Colors.red);
    }
  }

  int get _totalQty {
    return selectedMaterials.fold(0, (sum, item) {
      return sum + (int.tryParse(item['qty'].toString()) ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildHeaderForm(),
                    const SizedBox(height: 20),
                    _buildMaterialSection(),
                    const SizedBox(height: 30),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _importExcelToForm,
              icon: const Icon(
                Icons.file_upload_outlined,
                color: Colors.orange,
              ),
              label: const Text(
                "Import dari Excel",
                style: TextStyle(color: Colors.orange),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInputLabel(
                  "Tanggal RDD *",
                  _tanggalRDDController,
                  isDate: true,
                  onTap: () => _pickDate(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInputLabel(
                  "Stuffing Date*",
                  _stuffingDateController,
                  isDate: true,
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInputLabel(
                  "SO Number *",
                  _soNumberController,
                  hint: "XXXXX",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMaterialSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.inventory_2_outlined, "DETAIL MATERIAL"),
          const SizedBox(height: 16),
          _buildTable(),
          const SizedBox(height: 20),
          _buildInputRow(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(4),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(4),
        5: FlexColumnWidth(1),
        6: FixedColumnWidth(45),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(4),
          ),
          children: const [
            _PaddingCell(
              Text(
                "No DO",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            _PaddingCell(
              Text(
                "No Customer",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            _PaddingCell(
              Text(
                "Customer Tujuan",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            _PaddingCell(
              Text(
                "No Mat",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            _PaddingCell(
              Text(
                "Deskripsi Material",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            _PaddingCell(
              Text(
                "Qty",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            _PaddingCell(
              Text(
                "Action",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        ...selectedMaterials.asMap().entries.map((entry) {
          int idx = entry.key;
          var item = entry.value;
          return TableRow(
            children: [
              _PaddingCell(
                Text(
                  item['do_number'] ?? "",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              _PaddingCell(
                Text(
                  item['customer_id'] ?? "",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              _PaddingCell(
                Text(
                  item['customer_name'] ?? "",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              _PaddingCell(
                Text(
                  item['material_id'] ?? "",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              _PaddingCell(
                Text(
                  item['material_name'] ?? "",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              _PaddingCell(
                Text(
                  item['qty'].toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => selectedMaterials.removeAt(idx)),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildFieldSimple("No DO", _tempDoController),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _buildCustomerPickerForInputRow()),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: _buildMaterialPicker()),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildFieldSimple(
                  "Qty",
                  _tempQtyController,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addItemToTable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPickerForInputRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Customer Tujuan *",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        DropdownSearch<Map<String, dynamic>>(
          items: (String filter, LoadProps? loadProps) async {
            var query = supabase
                .from('customer')
                .select('customer_id, customer_name, data_log');

            if (filter.isNotEmpty) {
              final isNumber = int.tryParse(filter) != null;
              if (isNumber) {
                query = query.or(
                  'customer_id.eq.$filter, customer_name.ilike.%$filter%, data_log.ilike.%$filter%',
                );
              } else {
                query = query.or(
                  'customer_name.ilike.%$filter%, data_log.ilike.%$filter%',
                );
              }
            }

            final response = await query.limit(50).order('customer_id');
            return List<Map<String, dynamic>>.from(response);
          },

          itemAsString: (i) => "${i['customer_id']} - ${i['customer_name']}",
          compareFn: (item, selectedItem) =>
              item['customer_id'].toString() ==
              selectedItem['customer_id'].toString(),

          onChanged: (v) {
            setState(() {
              selectedCustomerId = v?['customer_id']?.toString();
              _tempSelectedCustomerData = v;
            });
          },

          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              hintText: "Cari ID/Nama/Log...",
            ),
          ),

          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: const TextFieldProps(
              decoration: InputDecoration(
                hintText: "Ketik untuk mencari...",
                prefixIcon: Icon(Icons.search),
              ),
            ),
            itemBuilder: (context, item, isSelected, isHovered) {
              return ListTile(
                selected: isSelected,
                title: Text(
                  "${item['customer_id']} - ${item['customer_name']}",
                ),
                subtitle: Text(
                  item['data_log'] ?? "-",
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _tempSelectedCustomerData;

  void _addItemToTable() async {
    if (_tempSelectedMaterial == null ||
        _tempDoController.text.isEmpty ||
        _tempQtyController.text.isEmpty ||
        selectedCustomerId == null) {
      _showSnackBar(
        "Lengkapi Customer, No DO, Material, dan Qty!",
        Colors.orange,
      );
      return;
    }

    final String currentDo = _tempDoController.text.trim();

    String? usedDate = await _checkDoExistence(currentDo);
    setState(() => isLoading = false);
    if (usedDate != null) {
      _showErrorDialog(
        "No DO $currentDo sudah digunakan di Shipping Request dengan tanggal stuffing $usedDate. Mohon gunakan No DO lain atau cek tanggal stuffing untuk konsistensi.",
      );
      return;
    }
    final String currentMatId = _tempSelectedMaterial!['material_id']
        .toString();

    bool isDoExistWithDifferentCust = selectedMaterials.any(
      (item) =>
          item['do_number'] == currentDo &&
          item['customer_id'].toString() != selectedCustomerId.toString(),
    );

    if (isDoExistWithDifferentCust) {
      _showSnackBar("1 DO tidak bisa memiliki 2 tujuan", Colors.red);
      return;
    }

    bool isMaterialDuplicate = selectedMaterials.any(
      (item) =>
          item['do_number'] == currentDo && item['material_id'] == currentMatId,
    );

    if (isMaterialDuplicate) {
      _showSnackBar(
        "Material ini sudah ada dalam No DO $currentDo!",
        Colors.red,
      );
      return;
    }

    setState(() {
      selectedMaterials.add({
        "do_number": currentDo,

        "customer_id": selectedCustomerId,
        "customer_name":
            _tempSelectedCustomerData?['customer_name'] ?? "Unknown",
        "material_id": _tempSelectedMaterial!['material_id'].toString(),
        "material_name": _tempSelectedMaterial!['material_name'] ?? "",
        "qty": _tempQtyController.text,
      });

      _tempQtyController.clear();
      _tempSelectedMaterial = null;
    });
  }

  Widget _buildMaterialPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Material",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        DropdownSearch<Map<String, dynamic>>(
          items: (f, l) => materialList,
          itemAsString: (i) =>
              "${i['material_id']?.toString() ?? ""} - ${i['material_name'] ?? ""}",
          compareFn: (i, s) =>
              i['material_id'].toString() == s['material_id'].toString(),
          selectedItem: _tempSelectedMaterial,
          onChanged: (v) => setState(() => _tempSelectedMaterial = v),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              hintText: "Cari Material",
            ),
          ),
          popupProps: const PopupProps.menu(showSearchBox: true),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Total Qty: $_totalQty Box",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          ),
          onPressed: _submitForm,
          child: const Text(
            "SUBMIT REQUEST",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldSimple(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  String _formatTanggal(String? dateFromDb) {
    if (dateFromDb == null || dateFromDb.isEmpty) return "-";

    try {
      DateTime utcDate = DateTime.parse(dateFromDb).toUtc();

      DateTime localDate = utcDate.toLocal();

      return DateFormat('dd/MM/yyyy HH:mm:ss').format(localDate);
    } catch (e) {
      debugPrint("Error Format Tanggal: $e");
      return dateFromDb;
    }
  }

  Widget _buildInputLabel(
    String label,
    TextEditingController controller, {
    bool isDate = false,
    VoidCallback? onTap,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isDate,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            suffixIcon: isDate
                ? const Icon(Icons.calendar_today, size: 14)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.red[900]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.red[900],
          ),
        ),
      ],
    );
  }

  void _pickDate(bool isStuffingDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStuffingDate
          ? (_stuffingDate ?? DateTime.now())
          : (_tanggalRDD ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        String formattedDate = DateFormat('dd/MM/yyyy').format(picked);
        if (isStuffingDate) {
          _stuffingDate = picked;
          _stuffingDateController.text = formattedDate;
        } else {
          _tanggalRDD = picked;
          _tanggalRDDController.text = formattedDate;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (selectedMaterials.isEmpty) {
      _showSnackBar("Isi minimal satu item di tabel!", Colors.orange);
      return;
    }

    if (!_formKey.currentState!.validate() || selectedCustomerId == null) {
      _showSnackBar("Lengkapi data header!", Colors.red);
      return;
    }

    setState(() => isLoading = true);
    try {
      final List<String> distinctDoNumbers = selectedMaterials
          .map((e) => e['do_number'].toString())
          .toSet()
          .toList();

      for (String doNum in distinctDoNumbers) {
        String? usedDate = await _checkDoExistence(doNum);
        if (usedDate != null) {
          setState(() => isLoading = false);
          _showErrorDialog(
            "DO $doNum sudah digunakan pada tanggal $usedDate.\n\nSilakan hapus atau ganti DO tersebut sebelum submit.",
          );
          return;
        }
      }
      final shippingResponse = await supabase
          .from('shipping_request')
          .insert({
            'stuffing_date': _stuffingDate?.toIso8601String(),
            'rdd': _tanggalRDD?.toIso8601String(),
            'so': _soNumberController.text,
            'status': 'waiting approval',
            'createdDO_by': userDisplayName ?? 'Unknown',
            'date_createdDO': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final int shippingId = shippingResponse['shipping_id'];

      final Map<String, List<Map<String, dynamic>>> groupedByDo = {};
      for (var item in selectedMaterials) {
        String doNum = item['do_number'];
        if (!groupedByDo.containsKey(doNum)) {
          groupedByDo[doNum] = [];
        }
        groupedByDo[doNum]!.add(item);
      }

      for (var entry in groupedByDo.entries) {
        String doNumber = entry.key;
        List<Map<String, dynamic>> items = entry.value;

        final String customerIdForThisDo = items.first['customer_id'];
        final doResponse = await supabase
            .from('delivery_order')
            .insert({
              'do_number': doNumber,
              'customer_id': int.parse(customerIdForThisDo),
              'shipping_id': shippingId,
            })
            .select()
            .single();

        final int doId = doResponse['do_id'];

        final List<Map<String, dynamic>> detailsToInsert = items.map((item) {
          return {
            'do_id': doId,
            'material_id': int.parse(item['material_id'].toString()),
            'qty': int.parse(item['qty'].toString()),
          };
        }).toList();

        await supabase.from('do_details').insert(detailsToInsert);
      }
      _showSnackBar("Shipping Request berhasil disimpan!", Colors.green);
      _resetForm();
    } catch (e) {
      _showSnackBar("Gagal menyimpan data: $e", Colors.red);
      //print("Error detail: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _soNumberController.clear();
      _doHeaderController.clear();
      _tanggalRDDController.clear();
      _stuffingDateController.clear();
      _tempDoController.clear();
      _tempQtyController.clear();
      _tanggalRDD = null;
      _stuffingDate = null;
      selectedMaterials.clear();
      selectedCustomerId = null;
      _tempSelectedMaterial = null;
    });
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

class _PaddingCell extends StatelessWidget {
  final Widget child;
  const _PaddingCell(this.child);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(10.0), child: child);
}
