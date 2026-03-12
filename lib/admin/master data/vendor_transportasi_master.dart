import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorTransportasiPage extends StatefulWidget {
  const VendorTransportasiPage({super.key});

  @override
  State<VendorTransportasiPage> createState() => _VendorTransportasiPageState();
}

class _VendorTransportasiPageState extends State<VendorTransportasiPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var query = supabase.from('vendor_transportasi').select();
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('vendor_name', '%$_searchQuery%');
      }
      final data = await query.order('id', ascending: true);

      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal mengambil data: $e";
        });
      }
    }
  }

  // --- DELETE & SAVE ---
  Future<void> _deleteVendor(int id) async => await supabase.from('vendor_transportasi').delete().match({'id': id}).then((_) => _fetchData());

  Future<void> _saveData(bool isEdit, int? id, Map<String, dynamic> data) async {
    if (isEdit) data['id'] = id;
    await supabase.from('vendor_transportasi').upsert(data);
    if (mounted) Navigator.pop(context);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Vendor Transportasi'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical, // Scroll Atas-Bawah
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal, // Scroll Kiri-Kanan
                          child: ConstrainedBox(
                            // PAKSA LEBAR MINIMAL AGAR TIDAK ERROR "NO SIZE"
                            // 3000px cukup untuk menampung 26 kolom dengan lega
                            constraints: const BoxConstraints(minWidth: 3200),
                            child: PaginatedDataTable(
                              header: const Text("Master Data Vendor"),
                              rowsPerPage: _vendors.isEmpty ? 1 : (_vendors.length < 10 ? _vendors.length : 10),
                              columns: _buildColumns(),
                              source: VendorDataSource(
                                _vendors,
                                context,
                                onEdit: (v) => _showFormDialog(v),
                                onDelete: (id) => _deleteVendor(id),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.indigo.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Cari Nama Vendor...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onSubmitted: (v) { _searchQuery = v; _fetchData(); },
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      'ID', 'ID Rekom', 'ID Standar', 'QCF', 'Area', 'City', 'Jenis QCF', 'Type Unit', 
      'Rank', 'Vendor Name', 'Mode', 'Alokasi %', 'Alokasi Cont', 'Cost Type', 
      'Fixed Cost', 'Var Cost', 'Gudang', 'Remark', 'Lead Time', 'POD Return', 
      'Shipment Type', 'No Vendor', 'Ship Cond', 'Special Proc', 'Part Funct', 'Vehicle Type', 'Aksi'
    ].map((s) => DataColumn(label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)))).toList();
  }

  // --- DIALOG FORM ---
  void _showFormDialog([Map<String, dynamic>? vendor]) {
    final bool isEdit = vendor != null;
    final Map<String, TextEditingController> ctrls = {};
    final fields = [
      'id_rekomendasi_winner', 'id_standarisasi', 'qcf', 'area', 'city', 'jenis_qcf',
      'type_unit', 'winner_rank', 'vendor_name', 'transportation_mode', 'alokasi_persen',
      'alokasi_container', 'fix_var_cost', 'fixed_cost', 'variable_cost', 'lokasi_gudang',
      'remark', 'lead_time', 'pod_return', 'shipment_type', 'no_vendor', 'shipping_conditions',
      'special_proc_indicator', 'part_funct', 'vehicle_type'
    ];
    
    for (var f in fields) {
      ctrls[f] = TextEditingController(text: vendor?[f]?.toString() ?? '');
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Edit Vendor" : "Tambah Vendor"),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              children: fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(controller: ctrls[f], decoration: InputDecoration(labelText: f.toUpperCase().replaceAll('_', ' '), border: const OutlineInputBorder())),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(onPressed: () {
            final data = ctrls.map((k, v) => MapEntry(k, v.text));
            _saveData(isEdit, vendor?['id'], data);
          }, child: const Text("Simpan"))
        ],
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
      DataCell(Text(v['id_rekomendasi_winner'] ?? '')),
      DataCell(Text(v['id_standarisasi'] ?? '')),
      DataCell(Text(v['qcf'] ?? '')),
      DataCell(Text(v['area'] ?? '')),
      DataCell(Text(v['city'] ?? '')),
      DataCell(Text(v['jenis_qcf'] ?? '')),
      DataCell(Text(v['type_unit'] ?? '')),
      DataCell(Text(v['winner_rank']?.toString() ?? '')),
      DataCell(Text(v['vendor_name'] ?? '')),
      DataCell(Text(v['transportation_mode'] ?? '')),
      DataCell(Text(v['alokasi_persen']?.toString() ?? '')),
      DataCell(Text(v['alokasi_container'] ?? '')),
      DataCell(Text(v['fix_var_cost'] ?? '')),
      DataCell(Text(v['fixed_cost']?.toString() ?? '')),
      DataCell(Text(v['variable_cost']?.toString() ?? '')),
      DataCell(Text(v['lokasi_gudang'] ?? '')),
      DataCell(Text(v['remark'] ?? '')),
      DataCell(Text(v['lead_time']?.toString() ?? '')),
      DataCell(Text(v['pod_return'] ?? '')),
      DataCell(Text(v['shipment_type'] ?? '')),
      DataCell(Text(v['no_vendor'] ?? '')),
      DataCell(Text(v['shipping_conditions'] ?? '')),
      DataCell(Text(v['special_proc_indicator'] ?? '')),
      DataCell(Text(v['part_funct'] ?? '')),
      DataCell(Text(v['vehicle_type'] ?? '')),
      DataCell(Row(
        children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => onEdit(v)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => onDelete(v['id'])),
        ],
      )),
    ]);
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}