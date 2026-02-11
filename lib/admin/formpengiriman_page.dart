import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';

class ShippingRequestPage extends StatefulWidget {
  const ShippingRequestPage({super.key});

  @override
  State<ShippingRequestPage> createState() => _ShippingRequestPageState();
}

class _ShippingRequestPageState extends State<ShippingRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // --- Header Controllers ---
  final TextEditingController _tanggalFormController = TextEditingController();
  final TextEditingController _tanggalRDDController = TextEditingController();
  final TextEditingController _soNumberController = TextEditingController();
  final TextEditingController _doHeaderController = TextEditingController();

  // --- Temp Input Controllers ---
  final TextEditingController _tempDoController = TextEditingController();
  final TextEditingController _tempQtyController = TextEditingController();

  DateTime _tanggalForm = DateTime.now();
  DateTime? _tanggalRDD;
  String? _selectedWarehouse;
  String? selectedCustomerId;

  // --- Data Lists ---
  List<Map<String, dynamic>> selectedMaterials = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> materialList = [];
  Map<String, dynamic>? _tempSelectedMaterial;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tanggalFormController.text = DateFormat('dd/MM/yyyy').format(_tanggalForm);
    
    // Sinkronisasi otomatis dari Header ke Input Row
    _doHeaderController.addListener(() {
      if (_tempDoController.text.isEmpty || _tempDoController.text == _doHeaderController.text) {
         _tempDoController.text = _doHeaderController.text;
      }
    });
    
    _fetchInitialData();
  }

  @override
  void dispose() {
    _tanggalFormController.dispose();
    _tanggalRDDController.dispose();
    _soNumberController.dispose();
    _doHeaderController.dispose();
    _tempDoController.dispose();
    _tempQtyController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final customerResponse = await supabase
          .from('customer')
          .select('customer_id, customer_name')
          .order('customer_name', ascending: true);

      final materialResponse = await supabase
          .from('material')
          .select('material_id, material_name')
          .order('material_name', ascending: true);

      if (mounted) {
        setState(() {
          customers = List<Map<String, dynamic>>.from(customerResponse);
          materialList = List<Map<String, dynamic>>.from(materialResponse);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
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
      appBar: AppBar(
        title: const Text('Buat Permintaan Pengiriman', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInputLabel("Tanggal Form", _tanggalFormController, isDate: true, onTap: () => _pickDate(true))),
              const SizedBox(width: 8),
              Expanded(child: _buildInputLabel("Tanggal RDD *", _tanggalRDDController, isDate: true, onTap: () => _pickDate(false))),
              const SizedBox(width: 8),
              Expanded(child: _buildInputLabel("SO Number *", _soNumberController, hint: "SO-XXXXX")),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDropdownWarehouse()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildCustomerSearchable()),
            ],
          ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
      border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
      columnWidths: const {
        0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(4), 
        3: FlexColumnWidth(1.5), 4: FixedColumnWidth(45),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[100]),
          children: const [
            _PaddingCell(Text("No DO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            _PaddingCell(Text("No Mat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            _PaddingCell(Text("Deskripsi Material", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            _PaddingCell(Text("Qty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            _PaddingCell(Text("Action")),
          ],
        ),
        ...selectedMaterials.asMap().entries.map((entry) {
          int idx = entry.key;
          var item = entry.value;
          return TableRow(
            children: [
              _PaddingCell(Text(item['do_number'] ?? "", style: const TextStyle(fontSize: 12))),
              _PaddingCell(Text(item['material_id'] ?? "", style: const TextStyle(fontSize: 12))),
              _PaddingCell(Text(item['material_name'] ?? "", style: const TextStyle(fontSize: 12))),
              _PaddingCell(Text(item['qty'].toString(), style: const TextStyle(fontSize: 12))),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => setState(() => selectedMaterials.removeAt(idx)),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(flex: 2, child: _buildFieldSimple("No DO Item", _tempDoController)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _buildMaterialPicker()),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _buildFieldSimple("Qty", _tempQtyController, isNumber: true)),
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
    );
  }

  void _addItemToTable() {
    if (_tempSelectedMaterial == null || 
        _tempDoController.text.isEmpty || 
        _tempQtyController.text.isEmpty || 
        selectedCustomerId == null) {
      _showSnackBar("Lengkapi Customer, No DO, Material, dan Qty!", Colors.orange);
      return;
    }

    final String currentDo = _tempDoController.text.trim();
    final String currentMatId = _tempSelectedMaterial!['material_id'].toString();

    // Validasi: 1 DO tidak bisa memiliki 2 tujuan berbeda
    bool isDoUsedForOtherCustomer = selectedMaterials.any((item) => 
        item['do_number'] == currentDo && item['customer_id'] != selectedCustomerId);

    if (isDoUsedForOtherCustomer) {
      _showSnackBar("No DO $currentDo sudah terdaftar untuk customer lain!", Colors.red);
      return;
    }

    // Validasi: 1 DO tidak bisa memiliki 2 material yang sama
    bool isMaterialDuplicateInSameDo = selectedMaterials.any((item) => 
        item['do_number'] == currentDo && item['material_id'] == currentMatId);

    if (isMaterialDuplicateInSameDo) {
      _showSnackBar("Material ini sudah ada dalam No DO $currentDo!", Colors.red);
      return;
    }

    setState(() {
      selectedMaterials.add({
        "do_number": currentDo,
        "customer_id": selectedCustomerId,
        "material_id": currentMatId,
        "material_name": _tempSelectedMaterial!['material_name'] ?? "",
        "qty": _tempQtyController.text,
      });

      _tempQtyController.clear();
      _tempSelectedMaterial = null; 
    });
  }

  Widget _buildCustomerSearchable() {
    // Kunci dropdown jika tabel tidak kosong
    bool isLocked = selectedMaterials.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Customer Tujuan *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            if (isLocked)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.lock_outline, size: 12, color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          enabled: !isLocked, // MATIKAN DROPDOWN JIKA TABEL BERISI
          items: (filter, loadProps) => customers,
          itemAsString: (item) => "${item['customer_id']?.toString() ?? ""} - ${item['customer_name'] ?? ""}",
          compareFn: (i, s) => i['customer_id'].toString() == s['customer_id'].toString(),
          onChanged: (value) => setState(() => selectedCustomerId = value?['customer_id']?.toString()),
          selectedItem: selectedCustomerId == null 
              ? null 
              : customers.cast<Map<String, dynamic>?>().firstWhere((c) => c?['customer_id'].toString() == selectedCustomerId, orElse: () => null),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              isDense: true, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: "Pilih Customer",
              fillColor: isLocked ? Colors.grey[100] : Colors.white,
              filled: true,
            ),
          ),
          popupProps: const PopupProps.menu(showSearchBox: true),
        ),
        if (isLocked)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text("Hapus semua item tabel untuk mengganti customer", style: TextStyle(fontSize: 9, color: Colors.orange, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildMaterialPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Material", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        DropdownSearch<Map<String, dynamic>>(
          items: (f, l) => materialList,
          itemAsString: (i) => "${i['material_id']?.toString() ?? ""} - ${i['material_name'] ?? ""}",
          compareFn: (i, s) => i['material_id'].toString() == s['material_id'].toString(),
          selectedItem: _tempSelectedMaterial,
          onChanged: (v) => setState(() => _tempSelectedMaterial = v),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        Text("Total Qty: $_totalQty", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
          onPressed: _submitForm,
          child: const Text("SUBMIT REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFieldSimple(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.all(10)),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label, TextEditingController controller, {bool isDate = false, VoidCallback? onTap, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isDate,
          onTap: onTap,
          decoration: InputDecoration(hintText: hint, isDense: true, suffixIcon: isDate ? const Icon(Icons.calendar_today, size: 14) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ],
    );
  }

  Widget _buildDropdownWarehouse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Warehouse *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedWarehouse,
          items: ["GBJ Chiyo", "Warehouse Utama", "Transit"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _selectedWarehouse = v),
          decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.red[900]),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red[900])),
      ],
    );
  }

  void _pickDate(bool isTanggalForm) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isTanggalForm ? _tanggalForm : (_tanggalRDD ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isTanggalForm) {
          _tanggalForm = picked;
          _tanggalFormController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _tanggalRDD = picked;
          _tanggalRDDController.text = DateFormat('dd/MM/yyyy').format(picked);
        }
      });
    }
  }

  void _submitForm() {
    if (selectedMaterials.isEmpty) {
      _showSnackBar("Isi minimal satu item di tabel!", Colors.orange);
      return;
    }
    if (_formKey.currentState!.validate() && selectedCustomerId != null && _selectedWarehouse != null) {
      _showSnackBar("Berhasil Submit!", Colors.green);
    } else {
      _showSnackBar("Lengkapi data header!", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

class _PaddingCell extends StatelessWidget {
  final Widget child;
  const _PaddingCell(this.child);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(10.0), child: child);
}