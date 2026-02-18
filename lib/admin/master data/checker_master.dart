import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckerPaginatedPage extends StatefulWidget {
  const CheckerPaginatedPage({super.key});

  @override
  State<CheckerPaginatedPage> createState() => _CheckerPaginatedPageState();
}

class _CheckerPaginatedPageState extends State<CheckerPaginatedPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _checkers = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
void initState() {
  super.initState();
  _fetchData();
  // Tambahkan ini agar widget merefresh saat user mengetik
  _searchController.addListener(() {
    setState(() {});
  });
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
      var query = supabase.from('checker').select();
      
      if (_searchQuery.isNotEmpty) {
        final isNumber = int.tryParse(_searchQuery) != null;
        if (isNumber) {
          // Cari berdasarkan ID atau Nama jika input angka
          query = query.or('checker_id.eq.$_searchQuery, checker_name.ilike.%$_searchQuery%');
        } else {
          // Cari berdasarkan Nama jika input teks
          query = query.ilike('checker_name', '%$_searchQuery%');
        }
      }

      final data = await query.order('checker_id', ascending: true);

      if (mounted) {
        setState(() {
          _checkers = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChecker(int id) async {
    try {
      await supabase.from('checker').delete().match({'checker_id': id});
      if (mounted) {
        _showMsg("Data checker berhasil dihapus", Colors.redAccent);
      }
      _fetchData();
    } catch (e) {
      debugPrint("Error Delete: $e");
    }
  }

  Future<void> _processSave(bool isEdit, int? id, String name, String shift, String lokasi, String status) async {
  try {
    // Pastikan Map didefinisikan sebagai <String, dynamic> agar bisa menerima String dan int
    final Map<String, dynamic> payload = {
      'checker_name': name,
      'shift': shift,
      'lokasi': lokasi,
      'status': status,
    };

    // Jika sedang edit, masukkan ID ke dalam payload
    if (isEdit && id != null) {
      payload['checker_id'] = id; 
    }

    // Gunakan upsert
    await supabase.from('checker').upsert(payload);

    if (mounted) {
      Navigator.pop(context);
      _showMsg(isEdit ? "Data diperbarui" : "Data disimpan", Colors.green);
    }
    _fetchData();
  } catch (e) {
    debugPrint("Error Save: $e");
    if (mounted) _showMsg("Error: $e", Colors.red);
  }
}

  void _showFormDialog([Map<String, dynamic>? checker]) {
    final bool isEdit = checker != null;

    final nameController = TextEditingController(text: checker?['checker_name'] ?? '');
    final shiftController = TextEditingController(text: (checker?['shift'] ?? '').toString());
    
  String rawLokasi = (checker?['lokasi'] ?? 'Rungkut').toString();
  String selectedLokasi = ['Rungkut', 'Tambak Langon'].contains(rawLokasi) ? rawLokasi : 'Rungkut';

  String rawStatus = (checker?['status'] ?? 'active').toString().toLowerCase();
  String selectedStatus = ['active', 'inactive'].contains(rawStatus) ? rawStatus : 'active';

   showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Checker' : 'Tambah Checker'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Nama Checker'),
                
                // INPUT TEXT BIASA UNTUK SHIFT
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: shiftController,
                    decoration: const InputDecoration(
                      labelText: 'Shift (Contoh: A, B, atau C)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      helperText: "Ketik kode shift secara manual",
                    ),
                    // Membatasi hanya 1 karakter sesuai dengan skema DB character varying(1)
                    inputFormatters: [LengthLimitingTextInputFormatter(1)],
                    textCapitalization: TextCapitalization.characters, // Otomatis huruf kapital
                  ),
                ),

                _buildDropdownField(
                  label: 'Lokasi',
                  value: selectedLokasi,
                  items: ['Rungkut', 'Tambak Langon'],
                  onChanged: (val) => setDialogState(() => selectedLokasi = val!),
                ),

                _buildDropdownField(
                  label: 'Status',
                  value: selectedStatus,
                  items: ['active', 'inactive'],
                  onChanged: (val) => setDialogState(() => selectedStatus = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty || shiftController.text.isEmpty) {
                  _showMsg("Nama dan Shift wajib diisi!", Colors.orange);
                  return;
                }
                _processSave(
                  isEdit, 
                  checker?['checker_id'], 
                  nameController.text, 
                  shiftController.text, // Mengambil nilai dari text field
                  selectedLokasi, 
                  selectedStatus
                );
              },
              child: const Text("Simpan"),
            )
          ],
        );
      },
    ),
  );
}

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        ),
      ),
    );
  }

  Widget _buildDropdownField({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = CheckerDataSource(_checkers, context, 
      onEdit: (data) => _showFormDialog(data), 
      onDelete: (id) => _deleteChecker(id)
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Checker'),
        backgroundColor: Colors.red.shade700, // Warna dibedakan dengan Warehouse
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
                      labelText: "Cari ID atau Nama Checker...",
                      prefixIcon: const Icon(Icons.search),
                      
                     suffixIcon: _searchController.text.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _searchQuery = "";
              _fetchData();
              setState(() {}); // Refresh untuk menyembunyikan icon kembali
            },
          )
        : null,
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
                      header: const Text("Daftar Checker"),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Shift', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Lokasi', style: TextStyle(fontWeight: FontWeight.bold))),
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

class CheckerDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  CheckerDataSource(this.data, this.context, {required this.onEdit, required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final item = data[index];
    return DataRow(cells: [
      DataCell(Text(item['checker_id']?.toString() ?? '-')),
      DataCell(Text(item['checker_name'] ?? '-')),
      DataCell(Text(" ${item['shift']?.toString().toUpperCase() ?? '-'}")),
      DataCell(Text(item['lokasi'] ?? '-')),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: item['status'] == 'active' ? Colors.green.shade100 : Colors.red.shade100,
          borderRadius: BorderRadius.circular(5)
        ),
        child: Text(item['status'] ?? '-', style: TextStyle(color: item['status'] == 'active' ? Colors.green.shade900 : Colors.red.shade900)),
      )),
      DataCell(Row(
        children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => onEdit(item)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirm(item['checker_id'])),
        ],
      )),
    ]);
  }

  void _confirm(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus?"),
        content: const Text("Data checker ini akan dihapus permanen."),
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