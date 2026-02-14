import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaterialPaginatedPage extends StatefulWidget {
  const MaterialPaginatedPage({super.key});

  @override
  State<MaterialPaginatedPage> createState() => _MaterialPaginatedPageState();
}

class _MaterialPaginatedPageState extends State<MaterialPaginatedPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _materials = [];
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
      var query = supabase.from('material').select();
      if (_searchQuery.isNotEmpty) {
       final isNumber = int.tryParse(_searchQuery) != null;
        if (isNumber) {
          // Mencari ID yang tepat (exact) ATAU nama yang mengandung angka tersebut
          query = query.or('material_id.eq.$_searchQuery, material_name.ilike.%$_searchQuery%');
        } else {
          query = query.ilike('material_name', '%$_searchQuery%');
        }
        
  }
      final data = await query.order('material_id', ascending: true);

      if (mounted) {
        setState(() {
          _materials = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DELETE DATA ---
  Future<void> _deleteMaterial(int id) async {
    try {
      await supabase.from('material').delete().match({'material_id': id});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data material berhasil dihapus"),
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
    TextEditingController boxPallet,
    TextEditingController mDiv,
    TextEditingController divDesc,
    TextEditingController gw,
    TextEditingController nw,
    TextEditingController type,
  ) async {
    try {
      await supabase.from('material').upsert({
        'material_id': int.parse(id.text),
        'material_name': name.text,
        'box_per_pallet': boxPallet.text,
        'marketing_division': mDiv.text,
        'division_description': divDesc.text,
        'gross_weight': double.tryParse(gw.text) ?? 0.0,
        'net_weight': double.tryParse(nw.text) ?? 0.0,
        'material_type': type.text,
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
  void _showFormDialog([Map<String, dynamic>? material]) {
    final bool isEdit = material != null;
    
    final idController = TextEditingController(text: material?['material_id']?.toString() ?? '');
    final nameController = TextEditingController(text: material?['material_name'] ?? '');
    final boxController = TextEditingController(text: material?['box_per_pallet'] ?? '');
    final mDivController = TextEditingController(text: material?['marketing_division'] ?? '');
    final divDescController = TextEditingController(text: material?['division_description'] ?? '');
    final gwController = TextEditingController(text: material?['gross_weight']?.toString() ?? '');
    final nwController = TextEditingController(text: material?['net_weight']?.toString() ?? '');
    final typeController = TextEditingController(text: material?['material_type'] ?? '');

    // List Opsi Dropdown
    final List<String> mDivOptions = ['OilBR', 'OilBI', 'OilBX', 'OilTR', 'MarshoBR', 'MarshoBI', 'MarshoBX', 'MarshoTR'];
    final List<String> divDescOptions = ['Branded', 'Branded Industry', 'Branded Export'];
    final List<String> typeOptions = ['OILS', 'MARG', 'SHRT', 'SPEC'];

    // FocusNodes
    final f1 = FocusNode(); final f2 = FocusNode(); final f3 = FocusNode();
    final f4 = FocusNode(); final f5 = FocusNode(); final f6 = FocusNode();
    final f7 = FocusNode(); final f8 = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Gunakan StatefulBuilder agar UI dropdown terupdate saat dipilih
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Material' : 'Tambah Material'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(idController, 'No Mat', f1, f2, !isEdit, isNumber: true),
                  _buildTextField(nameController, 'Material Deskripsi', f2, f3, true),
                  _buildTextField(boxController, 'Box/Pallet', f3, f4, true),
                  
                  // DROPDOWN: Marketing Division
                  _buildDropdownField('Marketing Div', mDivController, mDivOptions, f4, (val) {
                    setDialogState(() => mDivController.text = val ?? '');
                  }),

                  // DROPDOWN: Div Description
                  _buildDropdownField('Div Deskripsi', divDescController, divDescOptions, f5, (val) {
                    setDialogState(() => divDescController.text = val ?? '');
                  }),

                  _buildTextField(gwController, 'Gross Weight (GW)', f6, f7, true, isNumber: true),
                  _buildTextField(nwController, 'Net Weight (NW)', f7, f8, true, isNumber: true),

                  // DROPDOWN: Material Type
                  _buildDropdownField('Type', typeController, typeOptions, f8, (val) {
                    setDialogState(() => typeController.text = val ?? '');
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
              ElevatedButton(
                onPressed: () => _validateAndSave(isEdit, idController, nameController, boxController, mDivController, divDescController, gwController, nwController, typeController),
                child: const Text("Simpan"),
              )
            ],
          );
        }
      ),
    );
  }

  void _validateAndSave(bool isEdit, TextEditingController id, TextEditingController name, TextEditingController box, TextEditingController mDiv, TextEditingController div, TextEditingController gw, TextEditingController nw, TextEditingController type) {
    if (id.text.isEmpty || name.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Mat dan Deskripsi tidak boleh kosong!"), backgroundColor: Colors.orange),
      );
      return;
    }
    _saveData(isEdit, id, name, box, mDiv, div, gw, nw, type);
  }

  // --- HELPER WIDGETS ---

  Widget _buildTextField(TextEditingController controller, String label, FocusNode current, FocusNode? next, bool enabled, {bool isNumber = false, bool isLast = false, VoidCallback? onSave}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        focusNode: current,
        enabled: enabled,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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

  Widget _buildDropdownField(String label, TextEditingController controller, List<String> options, FocusNode focusNode, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: options.contains(controller.text) ? controller.text : null,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DataTableSource dataContent = MaterialDataSource(
      _materials,
      context,
      onEdit: (mat) => _showFormDialog(mat),
      onDelete: (id) => _deleteMaterial(id),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50),
              child: Column(
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: "Cari Deskripsi Material...",
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Theme(
                      data: Theme.of(context).copyWith(scrollbarTheme: ScrollbarThemeData(
                        thumbVisibility: WidgetStateProperty.all(true),
                      )),
                      child: PaginatedDataTable(
                        rowsPerPage: 10,
                        columns: const [
                          DataColumn(label: Text('No Mat', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Material Deskripsi', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Box/Pallet', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('M.Div', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Div Deskripsi', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('GW', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('NW', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
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
class MaterialDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  MaterialDataSource(this.data, this.context, {required this.onEdit, required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final mat = data[index];

    return DataRow(cells: [
      DataCell(Text(mat['material_id'].toString())),
      DataCell(Text(mat['material_name'] ?? '-')),
      DataCell(Text(mat['box_per_pallet'] ?? '-')),
      DataCell(Text(mat['marketing_division'] ?? '-')),
      DataCell(Text(mat['division_description'] ?? '-')),
      DataCell(Text(mat['gross_weight']?.toString() ?? '0')),
      DataCell(Text(mat['net_weight']?.toString() ?? '0')),
      DataCell(Text(mat['material_type'] ?? '-')),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => onEdit(mat)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirm(mat['material_id'])),
        ],
      )),
    ]);
  }

  void _confirm(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus?"),
        content: const Text("Data material ini akan dihapus secara permanen."),
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