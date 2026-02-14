import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      var query = supabase.from('customer').select();
      if (_searchQuery.isNotEmpty) {
        final isNumber = int.tryParse(_searchQuery) != null;

  if (isNumber) {
  query = query.eq('customer_id', int.parse(_searchQuery));
} else {
  query = query.ilike('customer_name', '%$_searchQuery%');
}

}
        
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(idController, 'No Cust', f1, f2, !isEdit, isNumber: true),
              _buildTextField(nameController, 'Nama Customer', f2, f3, true),
              _buildTextField(typeController, 'Customer Type', f3, f4, true),
              _buildTextField(delTypeController, 'Del Type', f4, f5, true),
              _buildTextField(cityController, 'City', f5, f6, true),
              _buildTextField(areaController, 'Area', f6, f7, true),
              _buildTextField(reportController, 'Report Area', f7, f8, true),
              _buildTextField(podController, 'POD Area', f8, null, true, isLast: true, onSave: () {
                _validateAndSave(isEdit, idController, nameController, typeController, delTypeController, cityController, areaController, reportController, podController);
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () => _validateAndSave(isEdit, idController, nameController, typeController, delTypeController, cityController, areaController, reportController, podController),
            child: const Text("Simpan"),
          )
        ],
      ),
    );
  }

  void _validateAndSave(bool isEdit, TextEditingController id, TextEditingController name, TextEditingController type, TextEditingController del, TextEditingController city, TextEditingController area, TextEditingController report, TextEditingController pod) {
    if (id.text.isEmpty || name.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Cust dan Nama tidak boleh kosong!"), backgroundColor: Colors.orange),
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

  @override
  Widget build(BuildContext context) {
    final DataTableSource dataContent = CustomerDataSource(
      _customers,
      context,
      onEdit: (cust) => _showFormDialog(cust),
      onDelete: (id) => _deleteCustomer(id),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50),
              child: Column(
                children: [
                  // --- SEARCH BAR DENGAN ICON SILANG (CLEAR) ---
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: "Cari Nama Customer...",
                          prefixIcon: const Icon(Icons.search),
                          // Munculkan icon silang HANYA jika ada teks
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = "";
                                    _fetchData(); // Ambil semua data lagi
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Theme(
    // Opsional: Agar scrollbar selalu terlihat (khusus desktop/web)
    data: Theme.of(context).copyWith(scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.all(true),
    )),
     child: PaginatedDataTable(
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
          TextButton(
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