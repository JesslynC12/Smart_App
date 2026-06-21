import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComplainConfirmPage extends StatefulWidget {
  const ComplainConfirmPage({Key? key}) : super(key: key);

  @override
  State<ComplainConfirmPage> createState() => _ComplainConfirmPageState();
}

class _ComplainConfirmPageState extends State<ComplainConfirmPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _rawMasterData = [];
  List<Map<String, dynamic>> _filteredData = [];
  
  bool _isLoading = false;
  bool _showHistory = false; 
  Set<int> _selectedIds = {};
RealtimeChannel? _complainChannel;

  @override
  void initState() {
    super.initState();
    _loadComplainData();
    _subscribeToComplainRealtime();
  }
  
  @override
  void dispose() {
    if (_complainChannel != null) {
      supabase.removeChannel(_complainChannel!);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeToComplainRealtime() {
    _complainChannel = supabase
        .channel('public:complain')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'complain',
          callback: (payload) {
            _loadComplainData(isRealtimeTrigger: true);
          },
        );
        
    _complainChannel?.subscribe();
  }

  Future<void> _loadComplainData({bool isRealtimeTrigger = false}) async {
    if (!isRealtimeTrigger) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await supabase.rpc('get_complain_list', params: {
        'p_show_history': _showHistory,
      }) as List<dynamic>;

      setState(() {
        _rawMasterData = List<Map<String, dynamic>>.from(response);
        _applyFilter(_searchController.text);
        _selectedIds.clear();
      });
    } catch (e) {
      _showSnackbar("Gagal memuat data: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredData = _rawMasterData;
      } else {
        final lowercaseQuery = query.toLowerCase();
        _filteredData = _rawMasterData.where((item) {
          return (item['do_number'] ?? '').toLowerCase().contains(lowercaseQuery) ||
                 (item['customer_name'] ?? '').toLowerCase().contains(lowercaseQuery) ||
                 (item['material_name'] ?? '').toLowerCase().contains(lowercaseQuery) ||
                 (item['material_id']?.toString() ?? '').contains(lowercaseQuery) ||
                 (item['nama_supir'] ?? '').toLowerCase().contains(lowercaseQuery);
        }).toList();
      }
    });
  }

  Future<void> _updateComplainStatus(String newStatus) async {
    if (_selectedIds.isEmpty) {
      _showSnackbar("Pilih minimal satu data komplain terlebih dahulu!", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      for (int id in _selectedIds) {
        await supabase
            .from('complain')
            .update({'complain_status': newStatus})
            .eq('complain_id', id);
      }

      _showSnackbar("Sukses! Data komplain berhasil di-$newStatus.");
    } catch (e) {
      _showSnackbar("Gagal memproses data: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complainDataSource = _ComplainDataTableSource(
      data: _filteredData,
      selectedIds: _selectedIds,
      onRowSelected: (id, selected) {
        setState(() {
          if (selected == true) {
            _selectedIds.add(id);
          } else {
            _selectedIds.remove(id);
          }
        });
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActionBar(),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: PaginatedDataTable(
                        header: const Text("Daftar Masalah Distribusi"),
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Tgl Komplain')),
                          DataColumn(label: Text('Tipe')),
                          DataColumn(label: Text('No DO')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Armada/Supir')),
                          DataColumn(label: Text('Vendor')), 
                          DataColumn(label: Text('Checker')),
                          DataColumn(label: Text('Material')),
                          DataColumn(label: Text('Qty (Box)')),
                          DataColumn(label: Text('Catatan')),
                          DataColumn(label: Text('Status')),
                        ],
                        source: complainDataSource,
                        rowsPerPage: 10,
                        showCheckboxColumn: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            onChanged: _applyFilter,
            decoration: InputDecoration(
              hintText: "Cari No DO, Customer, Supir atau Nama Barang...",
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Row(
          children: [
            const Text("Tampilkan Riwayat", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            Switch.adaptive(
              value: _showHistory,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                setState(() => _showHistory = val);
                _loadComplainData();
              },
            ),
          ],
        ),
        const Spacer(),
        if (_selectedIds.isNotEmpty) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text("Reject Pilihan (${_selectedIds.length})"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => _updateComplainStatus('rejected'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text("Approve Pilihan (${_selectedIds.length})"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => _updateComplainStatus('approved'),
          ),
        ]
      ],
    );
  }
}

class _ComplainDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final Set<int> selectedIds;
  final Function(int id, bool? selected) onRowSelected;

  _ComplainDataTableSource({
    required this.data,
    required this.selectedIds,
    required this.onRowSelected,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final row = data[index];
    final int complainId = row['complain_id'];
    final bool isSelected = selectedIds.contains(complainId);

    return DataRow.byIndex(
      index: index,
      selected: isSelected,
      onSelectChanged: (selected) => onRowSelected(complainId, selected),
      cells: [
        DataCell(Text("#$complainId", style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(row['date_created'] ?? '-')),
        DataCell(Text(row['complain_type'] ?? '-')),
        DataCell(Text(row['do_number'] ?? '-', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600))),
        DataCell(Text(row['customer_name'] ?? '-')),
        DataCell(Text("${row['no_polisi'] ?? '-'}\n(${row['nama_supir'] ?? '-'})")),
        DataCell(Text(row['vendor_name'] ?? '-')), 
        DataCell(Text(row['checker_name'] ?? '-')),
        DataCell(Text("[${row['material_id']}] ${row['material_name'] ?? '-'}")),
        DataCell(Text(row['qty']?.toString() ?? '0')),
        DataCell(Text(row['complain_note'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis)),
        DataCell(_buildStatusBadge(row['complain_status'])),
      ],
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bg = Colors.grey.shade100;
    Color text = Colors.black87;
    
    if (status == 'pending') {
      bg = Colors.orange.shade50;
      text = Colors.orange.shade800;
    } else if (status == 'approved') {
      bg = Colors.green.shade50;
      text = Colors.green.shade800;
    } else if (status == 'rejected') {
      bg = Colors.red.shade50;
      text = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status?.toUpperCase() ?? 'UNKNOWN',
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => selectedIds.length;
}