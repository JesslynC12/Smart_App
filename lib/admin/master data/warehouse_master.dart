import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNumberField(codeController, 'Warehouse Code', f1, f2),
                  _buildTextField(nameController, 'Warehouse Name', f2, f3),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      value: selectedLokasi,
                      decoration: const InputDecoration(labelText: 'Lokasi', border: OutlineInputBorder()),
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
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
              ElevatedButton(
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
    if (code.text.isEmpty || name.text.isEmpty || cap.text.isEmpty) {
      _showMsg("WH Code, Nama Warehouse, dan Kapasitas wajib diisi!", Colors.orange);
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
          helperText: "Input angka saja",
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
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: "Cari Nama Warehouse...",
                      prefixIcon: const Icon(Icons.search),
                      suffix: IconButton(
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
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
    return DataRow(cells: [
      DataCell(Text(wh['wh_code']?.toString() ?? '-')),
      DataCell(Text(wh['warehouse_name'] ?? '-')),
      DataCell(Text(wh['lokasi'] ?? '-')),
      DataCell(Text(wh['kapasitas']?.toString() ?? '0')),
      DataCell(Text("${wh['max_utilize'] ?? 0}")),
      // DATA TIPE DIMUNCULKAN DI SINI
      DataCell(Text(wh['tipe'] ?? '-')),
      DataCell(Text(wh['status'] ?? '-')),
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
          TextButton(onPressed: () { onDelete(id); Navigator.pop(c); }, child: const Text("Hapus")),
        ],
      ),
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}