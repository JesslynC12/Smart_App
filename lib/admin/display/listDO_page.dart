import 'package:flutter/material.dart';
import 'package:project_app/admin/input%20form/formDO_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ListDOPage extends StatefulWidget {
  const ListDOPage({super.key});

  @override
  State<ListDOPage> createState() => _ListDOPageState();
}

class _ListDOPageState extends State<ListDOPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  final Set<int> _selectedIds = {}; 
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchShippingRequests();
  }
  Future<void> _fetchShippingRequests() async {
  try {
    final response = await supabase
        .from('shipping_request')
        .select('''
          *,
          delivery_order (
            do_number,
            customer (customer_name),
            do_details (qty, material_id, material (material_name))
          ),
          shipping_request_details!left(id)
        ''')
        .isFilter('shipping_request_details', null) // TAMPILKAN HANYA YANG BELUM DIPROSES
        .order('shipping_id', ascending: false);

    setState(() {
      _allRequests = List<Map<String, dynamic>>.from(response);
      _filteredRequests = _allRequests;
      _isLoading = false;
    });
  } catch (e) {
    _showSnackBar("Gagal ambil data: $e", Colors.red);
  }
}

// Future<void> _prosesKePermintaan() async {
//   try {
//     List<Map<String, dynamic>> dataToInsert = _selectedIds.map((id) => {'shipping_id': id}).toList();

//     await supabase.from('shipping_request_details').insert(dataToInsert);

//     _showSnackBar("Berhasil dipindahkan ke Permintaan Pengiriman", Colors.green);
//     setState(() {
//       _selectedIds.clear(); 
//     });
    
//     await _fetchShippingRequests(); // Menjalankan fetch ulang agar item hilang (karena filter .isFilter('shipping_request_details', null))
//   } catch (e) {
//     setState(() => _isLoading = false); // Matikan loading jika gagal
//     _showSnackBar("Gagal proses: $e", Colors.red);
//     print("Error Detail: $e");
//   }

// }

Future<void> _prosesKePermintaan() async {
  if (_selectedIds.isEmpty) return;

  try {
    setState(() => _isLoading = true);

    // 1. Siapkan data untuk bulk insert ke tabel shipping_request_details
    List<Map<String, dynamic>> dataToInsert = _selectedIds.map((id) => {
      'shipping_id': id,
    }).toList();

    // 2. Eksekusi Insert ke tabel detail
    await supabase.from('shipping_request_details').insert(dataToInsert);

    // 3. Update Status di tabel shipping_request menjadi 'waiting GBJ'
    // Kita melakukan update untuk semua ID yang ada di dalam set _selectedIds
    await supabase
        .from('shipping_request')
        .update({'status': 'waiting GBJ'})
        .inFilter('shipping_id', _selectedIds.toList());

    _showSnackBar("Berhasil! ${dataToInsert.length} data dipindahkan ke Permintaan Pengiriman", Colors.green);
    
    // 4. Bersihkan pilihan dan refresh data
    setState(() {
      _selectedIds.clear(); 
    });
    
    // Fetch ulang agar data yang sudah diproses hilang dari list ini
    await _fetchShippingRequests(); 
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal proses: $e", Colors.red);
    print("Error Detail: $e");
  }
}

  void _runFilter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRequests = _allRequests;
      } else {
        _filteredRequests = _allRequests.where((req) {
          final String soNum = (req['so'] ?? "").toString().toLowerCase();
          final List dos = req['delivery_order'] ?? [];
          
          bool matchInDO = dos.any((doItem) {
            final String doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
            final String custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
            
            // Tambah filter berdasarkan nama material
            final List details = doItem['do_details'] ?? [];
            bool matchInMaterial = details.any((det) => 
              (det['material']?['material_name'] ?? "").toString().toLowerCase().contains(query.toLowerCase())
            );

            return doNum.contains(query.toLowerCase()) || custName.contains(query.toLowerCase()) || matchInMaterial;
          });
          return soNum.contains(query.toLowerCase()) || matchInDO;
        }).toList();
      }
    });
  }

  Future<void> _deleteRequest(int shippingId, String label) async {
    try {
      setState(() => _isLoading = true);
      await supabase.from('shipping_request').delete().eq('shipping_id', shippingId);
      _showSnackBar("SO $label berhasil dihapus", Colors.green);
      _fetchShippingRequests();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal menghapus: $e", Colors.red);
    }
  }

  void _editRequest(Map<String, dynamic> req) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShippingRequestPage(editData: req),
      ),
    );
    if (result == true) {
      _fetchShippingRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("List DO", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTableArea(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIds.isNotEmpty ? _buildActionBottomBar() : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        onChanged: _runFilter,
        decoration: InputDecoration(
          hintText: "Cari SO, DO, Customer, atau Material...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTableArea() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
          dataRowMaxHeight: 120, // Diperlebar agar muat list material
          columns: const [
            DataColumn(label: Text('Pilih',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('SO Number',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('No DO',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Customer',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('No Material',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nama Material',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Qty',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('RDD',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Stuffing',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status',style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Aksi',style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredRequests.map((req) {
            final int id = req['shipping_id'];
            final isSelected = _selectedIds.contains(id);
            final List dos = req['delivery_order'] ?? [];

            // Flat list untuk material
            List<Widget> doWidgets = [];
            List<Widget> custWidgets = [];
            List<Widget> matIdWidgets = [];
            List<Widget> matNameWidgets = [];
            List<Widget> qtyWidgets = [];

            for (var d in dos) {
              final List details = d['do_details'] ?? [];
              for (var det in details) {
                doWidgets.add(_buildTextItem(d['do_number'] ?? "-"));
                custWidgets.add(_buildTextItem(d['customer']?['customer_name'] ?? "-"));
                matIdWidgets.add(_buildTextItem(det['material_id']?.toString() ?? "-"));
                matNameWidgets.add(_buildTextItem(det['material']?['material_name'] ?? "-"));
                qtyWidgets.add(_buildTextItem(det['qty']?.toString() ?? "0", isBold: true));
              }
            }

            return DataRow(
              selected: isSelected,
              cells: [
                DataCell(Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) _selectedIds.add(id);
                      else _selectedIds.remove(id);
                    });
                  },
                )),
                DataCell(Text(req['so'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: doWidgets)),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: custWidgets)),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: matIdWidgets)),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: matNameWidgets)),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: qtyWidgets)),
                DataCell(Text(_formatDate(req['rdd']))),
                DataCell(Text(_formatDate(req['stuffing_date']))), // Munculkan Stuffing Date
                DataCell(_buildStatusBadge(req['status'])),
                DataCell(Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editRequest(req)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(id, req['so'] ?? "Tanpa No SO"),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTextItem(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: text.contains('DO') ? Colors.blue : Colors.black,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color = status?.toLowerCase() == 'approved' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color)),
      child: Text(status?.toUpperCase() ?? 'PENDING', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade200,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
       onPressed: () => _prosesKePermintaan(), 
      icon: const Icon(Icons.check_circle),
      label: Text("Proses ${_selectedIds.length} Item"),
      ),
    );
  }

  void _confirmDelete(int id, String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Data?"),
        content: Text("Yakin ingin menghapus SO $label? Data DO di dalamnya akan ikut terhapus."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(context); _deleteRequest(id, label); },
            child: const Text("Hapus Permanen"),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd/MM/yy').format(DateTime.parse(dateStr));
    } catch (e) {
      return "-";
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}