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

  // Variabel Form
  DateTime _tanggalForm = DateTime.now();
  DateTime? _tanggalRDD;
  final TextEditingController _tanggalFormController = TextEditingController();
  final TextEditingController _tanggalRDDController = TextEditingController();
  final TextEditingController _soNumberController = TextEditingController();
  final TextEditingController _doNumberController = TextEditingController();
  
  String? _selectedWarehouse;
  String? selectedCustomerId;
  
  List<Map<String, dynamic>> selectedMaterials = [];

  // Data Referensi
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> materialList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tanggalFormController.text = DateFormat('dd/MM/yyyy').format(_tanggalForm);
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      // Mengambil data dengan urutan A-Z berdasarkan Nama
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
          customers = List<Map<String, dynamic>>.from(customerResponse ?? []);
          materialList = List<Map<String, dynamic>>.from(materialResponse ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  int get _totalQty {
    int total = 0;
    for (var item in selectedMaterials) {
      total += int.tryParse(item['qty'].toString()) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Buat Permintaan Pengiriman', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildInputLabel("Tanggal Form", _tanggalFormController, isDate: true, onTap: () => _pickDate(true))),
                          const SizedBox(width: 8),
                          Expanded(child: _buildInputLabel("Tanggal RDD *", _tanggalRDDController, isDate: true, onTap: () => _pickDate(false))),
                          const SizedBox(width: 8),
                          Expanded(child: _buildInputLabel("SO Number *", _soNumberController, hint: "SO-XXXXX")),
                          const SizedBox(width: 8),
                          Expanded(child: _buildInputLabel("No DO *", _doNumberController, hint: "DO-XXXXX")),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildDropdownWarehouse()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildCustomerSearchable()),
                        ],
                      ),

                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 10),
                      
                      _buildSectionHeader(Icons.inventory_2_outlined, "DETAIL MATERIAL"),
                      const SizedBox(height: 16),
                      
                      if (selectedMaterials.isNotEmpty)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: selectedMaterials.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildMaterialRowSearchable(index),
                        ),

                      const SizedBox(height: 20),
                      _buildAddMaterialButton(),
                      const SizedBox(height: 40),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Qty: $_totalQty", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _submitForm,
                            child: const Text("SUBMIT REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- WIDGET SEARCHABLE CUSTOMER (FORMAT: ID - NAMA) ---
  Widget _buildCustomerSearchable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Customer Tujuan *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          items: (filter, loadProps) => customers,
          // Format Tampilan: ID - Nama
          itemAsString: (item) => "${item['customer_id']} - ${item['customer_name']}",
          compareFn: (item, selectedItem) => item['customer_id'] == selectedItem['customer_id'],
          // Filter: Bisa cari berdasarkan ID atau Nama
          filterFn: (item, filter) {
            final searchContent = "${item['customer_id']} ${item['customer_name']}".toLowerCase();
            return searchContent.contains(filter.toLowerCase());
          },
          onChanged: (value) => setState(() => selectedCustomerId = value?['customer_id'].toString()),
          selectedItem: selectedCustomerId == null 
              ? null 
              : customers.firstWhere((c) => c['customer_id'].toString() == selectedCustomerId, orElse: () => {}),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              hintText: "Pilih Customer",
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          popupProps: const PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: "Cari ID atau nama customer...",
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET SEARCHABLE MATERIAL ROW (FORMAT: ID - NAMA) ---
  Widget _buildMaterialRowSearchable(int index) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: DropdownSearch<Map<String, dynamic>>(
            items: (filter, loadProps) => materialList,
            // Format Tampilan: ID - Nama
            itemAsString: (item) => "${item['material_id']} - ${item['material_name']}",
            compareFn: (item, selectedItem) => item['material_id'] == selectedItem['material_id'],
            // Filter: Bisa cari berdasarkan ID atau Nama
            filterFn: (item, filter) {
              final searchContent = "${item['material_id']} ${item['material_name']}".toLowerCase();
              return searchContent.contains(filter.toLowerCase());
            },
            onChanged: (value) => setState(() {
              selectedMaterials[index]['material_id'] = value?['material_id'];
            }),
            selectedItem: selectedMaterials[index]['material_id'] == null 
                ? null 
                : materialList.firstWhere(
                    (m) => m['material_id'] == selectedMaterials[index]['material_id'],
                    orElse: () => {},
                  ),
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                hintText: "Pilih Material",
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: "Cari ID atau nama material...", 
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            key: ValueKey("qty_$index"), 
            initialValue: selectedMaterials[index]['qty'],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Qty",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 12), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) {
              selectedMaterials[index]['qty'] = val;
              setState(() {}); 
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey), 
          onPressed: () => setState(() => selectedMaterials.removeAt(index))
        ),
      ],
    );
  }

  // --- FUNGSI HELPER LAINNYA ---
  Widget _buildInputLabel(String label, TextEditingController controller, {bool isDate = false, VoidCallback? onTap, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isDate,
          onTap: onTap,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            suffixIcon: isDate ? const Icon(Icons.calendar_today, size: 14) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedWarehouse,
              hint: const Text("Pilih Gudang", style: TextStyle(fontSize: 13)),
              items: ["GBJ Chiyo", "Warehouse Utama", "Transit"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _selectedWarehouse = v),
            ),
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
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red[900])),
      ],
    );
  }

  Widget _buildAddMaterialButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => selectedMaterials.add({"material_id": null, "qty": ""})),
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Tambah Item"),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700], side: BorderSide(color: Colors.red.shade200)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tambahkan minimal satu material")));
      return;
    }
    if (_formKey.currentState!.validate() && 
        selectedCustomerId != null && 
        _selectedWarehouse != null && 
        _doNumberController.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Berhasil Submit!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi semua field bertanda *")));
    }
  }
}