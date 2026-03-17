import 'package:flutter/material.dart';
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
  
  // Menggunakan Set<String> untuk menyimpan kunci unik "shippingId_doNumber"
  final Set<String> _selectedKeys = {}; 
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchShippingRequests();
  }

  // Future<void> _fetchShippingRequests() async {
  //   try {
  //     setState(() => _isLoading = true);
  //     final response = await supabase
  //         .from('shipping_request')
  //         .select('''
  //           *,
  //           delivery_order (
  //             do_number,
  //             customer (customer_name),
  //             do_details (qty, material_id, material (material_name))
  //           ),
  //           shipping_request_details!left(id)
  //         ''')
  //         .isFilter('shipping_request_details', null)
  //         .order('shipping_id', ascending: false);

  //     List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);
  //     List<Map<String, dynamic>> flattenedData = [];

  //     // Logic Flattening: Pecah data agar 1 Baris = 1 DO
  //     for (var request in rawData) {
  //       final List dos = request['delivery_order'] ?? [];
  //       for (var doItem in dos) {
  //         String doNum = doItem['do_number'] ?? "no-do";
  //         flattenedData.add({
  //           ...request,
  //           'single_do': doItem,
  //           'unique_key': "${request['shipping_id']}_$doNum", // Key Unik
  //         });
  //       }
  //     }

  //     setState(() {
  //       _allRequests = flattenedData;
  //       _filteredRequests = _allRequests;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     _showSnackBar("Gagal ambil data: $e", Colors.red);
  //   }
  // }

//   Future<void> _fetchShippingRequests() async {
//   try {
//     setState(() => _isLoading = true);
//     final response = await supabase
//         .from('shipping_request')
//         .select('''
//           *,
//           delivery_order (
//             do_number,
//             customer (customer_name),
//             do_details (qty, material_id, material (material_name))
//           ),
//           shipping_request_details(do_number) 
//         '''); // Ambil list do_number yang sudah diproses

//     List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);
//     List<Map<String, dynamic>> flattenedData = [];

//     for (var request in rawData) {
//       final List dos = request['delivery_order'] ?? [];
//       // Ambil daftar DO yang sudah diproses untuk ID ini
//       //final List processedDetails = request['shipping_request_details'] ?? [];
//       final dynamic rawDetails = request['shipping_request_details'];
// List processedDetails = [];

// if (rawDetails is List) {
//   processedDetails = rawDetails;
// } else if (rawDetails is Map) {
//   processedDetails = [rawDetails]; // Bungkus jadi list jika dia Map
// }
//       final List<String> processedDoNumbers = processedDetails
//           .map((d) => d['do_number'].toString())
//           .toList();

//       for (var doItem in dos) {
//         String doNum = doItem['do_number'] ?? "no-do";
        
//         // FILTER DI SINI: Hanya masukkan DO yang BELUM ada di tabel detail
//         if (!processedDoNumbers.contains(doNum)) {
//           flattenedData.add({
//             ...request,
//             'single_do': doItem,
//             'unique_key': "${request['shipping_id']}_$doNum",
//           });
//         }
//       }
//     }

//     setState(() {
//       _allRequests = flattenedData;
//       _filteredRequests = _allRequests;
//       _isLoading = false;
//     });
//   } catch (e) {
//     setState(() => _isLoading = false);
//     _showSnackBar("Gagal: $e", Colors.red);
//   }
// }


Future<void> _fetchShippingRequests() async {
  try {
    setState(() => _isLoading = true);
    
    // Query dengan filter status 'waiting approval'
    // Dan filter agar hanya menampilkan yang belum ada di shipping_request_details
    final response = await supabase
        .from('shipping_request')
        .select('''
          *,
          delivery_order (
            do_number,
            customer (customer_name),
            do_details (qty, material_id, material (material_name))
          ),
          shipping_request_details!left(do_number)
        ''')
        .eq('status', 'waiting approval') // Hanya yang berstatus waiting approval
        .isFilter('shipping_request_details', null) // Hanya yang belum diproses
        .order('shipping_id', ascending: false); // Urutkan dari yang terbaru

    List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);
    List<Map<String, dynamic>> flattenedData = [];

    for (var request in rawData) {
      final List dos = request['delivery_order'] ?? [];
      
      // Mengatasi error _JsonMap vs List<dynamic>
      final dynamic rawDetails = request['shipping_request_details'];
      List processedDetails = [];
      if (rawDetails is List) {
        processedDetails = rawDetails;
      } else if (rawDetails is Map) {
        processedDetails = [rawDetails];
      }

      // Ambil daftar nomor DO yang sudah ada di tabel detail (jika ada)
      final List<String> processedDoNumbers = processedDetails
          .map((d) => d['do_number'].toString())
          .toList();

      for (var doItem in dos) {
        String doNum = doItem['do_number'] ?? "no-do";
        
        // Filter di sisi client: Hanya masukkan DO yang belum diproses
        if (!processedDoNumbers.contains(doNum)) {
          flattenedData.add({
            ...request,
            'single_do': doItem,
            'unique_key': "${request['shipping_id']}_$doNum",
          });
        }
      }
    }

    setState(() {
      _allRequests = flattenedData;
      _filteredRequests = _allRequests;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal ambil data: $e", Colors.red);
    print("Error Detail: $e");
  }
}

void _toggleSelectAll(bool? selected) {
  setState(() {
    if (selected == true) {
      // Masukkan semua unique_key dari data yang sedang tampil (filtered)
      for (var req in _filteredRequests) {
        _selectedKeys.add(req['unique_key']);
      }
    } else {
      // Kosongkan pilihan
      _selectedKeys.clear();
    }
  });
}

  // Future<void> _prosesKePermintaan() async {
  //   if (_selectedKeys.isEmpty) return;

  //   try {
  //     setState(() => _isLoading = true);

  //     // 1. Ambil list shipping_id unik untuk update status SO
  //     List<int> selectedShippingIds = _selectedKeys
  //         .map((key) => int.parse(key.split('_')[0]))
  //         .toSet()
  //         .toList();

  //     // 2. Siapkan data untuk insert (Satu baris per DO yang dipilih)
  //     List<Map<String, dynamic>> dataToInsert = _selectedKeys.map((key) {
  //       return {
  //         'shipping_id': int.parse(key.split('_')[0]),
  //         // 'do_number': key.split('_')[1], // Jika tabel details punya kolom do_number
  //       };
  //     }).toList();

  //     // 3. Eksekusi Insert ke tabel detail
  //     await supabase.from('shipping_request_details').insert(dataToInsert);

  //     // 4. Update Status di tabel shipping_request
  //     await supabase
  //         .from('shipping_request')
  //         .update({'status': 'waiting GBJ'})
  //         .inFilter('shipping_id', selectedShippingIds);

  //     _showSnackBar("Berhasil! ${_selectedKeys.length} DO diproses", Colors.green);
      
  //     setState(() => _selectedKeys.clear());
  //     await _fetchShippingRequests(); 
      
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     _showSnackBar("Gagal proses: $e", Colors.red);
  //   }
  // }

  Future<void> _prosesKePermintaan() async {
  if (_selectedKeys.isEmpty) return;

  try {
    setState(() => _isLoading = true);

    // 1. Siapkan data insert yang menyertakan do_number
    List<Map<String, dynamic>> dataToInsert = _selectedKeys.map((key) {
      return {
        'shipping_id': int.parse(key.split('_')[0]),
        'do_number': key.split('_')[1], // Ambil nomor DO dari unique_key
      };
    }).toList();

    // 2. Insert ke tabel detail
    await supabase.from('shipping_request_details').insert(dataToInsert);

    // CATATAN: Jangan update status 'shipping_request' ke 'waiting GBJ' di sini 
    // jika masih ada DO lain yang belum diproses dalam ID yang sama.

    _showSnackBar("Berhasil memproses ${_selectedKeys.length} DO", Colors.green);
    setState(() => _selectedKeys.clear());
    await _fetchShippingRequests(); 
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal proses: $e", Colors.red);
  }
}

  void _runFilter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRequests = _allRequests;
      } else {
        final q = query.toLowerCase();
        _filteredRequests = _allRequests.where((item) {
          final soNum = (item['so'] ?? "").toString().toLowerCase();
          final doItem = item['single_do'] ?? {};
          final doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
          final custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
          
          final List details = doItem['do_details'] ?? [];
          bool matchMaterial = details.any((det) => 
            (det['material']?['material_name'] ?? "").toString().toLowerCase().contains(q)
          );

          return soNum.contains(q) || doNum.contains(q) || custName.contains(q) || matchMaterial;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("List DO (Per DO)", style: TextStyle(fontWeight: FontWeight.bold)),
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
      //bottomNavigationBar: _selectedKeys.isNotEmpty ? _buildActionBottomBar() : null,
    bottomNavigationBar: (_selectedKeys != null && _selectedKeys.isNotEmpty) 
    ? _buildActionBottomBar() 
    : null,
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
    if (_filteredRequests.isEmpty) {
      return const Center(child: Text("Tidak ada data ditemukan"));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                dataRowMaxHeight: 100, 
                columnSpacing: 20,
                columns: [
                  //DataColumn(label: Text('Pilih')),
                  DataColumn(
    label: Row(
      children: [
        //const Text('Pilih'),
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            side: const BorderSide(color: Colors.white, width: 1.5), // Agar terlihat di header merah
            activeColor: Colors.white,
            checkColor: Colors.red,
            value: _filteredRequests.isNotEmpty && 
                   _filteredRequests.every((req) => _selectedKeys.contains(req['unique_key'])),
            onChanged: _toggleSelectAll,
          ),
          
        ),
        const Text('Pilih'),
      ],
    ),
  ),
                  
                  const DataColumn(label: Text('No DO')),
                  const DataColumn(label: Text('SO Number')),
                  const DataColumn(label: Text('Customer')),
                  const DataColumn(label: Text('Nama Material')),
                  const DataColumn(label: Text('Qty')),
                  const DataColumn(label: Text('RDD')),
                  //const DataColumn(label: Text('Status')),
                  const DataColumn(label: Text('Aksi')),
                ],
                rows: _filteredRequests.map((req) {
                  final String uniqueKey = req['unique_key'];
                  final bool isSelected = _selectedKeys.contains(uniqueKey);
                  final Map<String, dynamic> doItem = req['single_do'] ?? {};
                  final List details = doItem['do_details'] ?? [];

                  // Material List UI
                  List<Widget> matNameWidgets = [];
                  List<Widget> qtyWidgets = [];
                  for (var det in details) {
                    matNameWidgets.add(_buildTextItem(det['material']?['material_name'] ?? "-", width: 180));
                    qtyWidgets.add(_buildTextItem(det['qty']?.toString() ?? "0", isBold: true));
                  }

                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) return Colors.red.withOpacity(0.05);
                      return null;
                    }),
                    cells: [
                      DataCell(Checkbox(
                        activeColor: Colors.red.shade700,
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) _selectedKeys.add(uniqueKey);
                            else _selectedKeys.remove(uniqueKey);
                          });
                        },
                      )),
                      DataCell(Text(doItem['do_number'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(req['so'] ?? "-")),
                      DataCell(_buildTextItem(doItem['customer']?['customer_name'] ?? "-", width: 140)),
                      DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: matNameWidgets)),
                      DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: qtyWidgets)),
                      DataCell(Text(_formatDate(req['rdd']))),
                      //DataCell(_buildStatusBadge(req['status'])),
                      DataCell(Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 18), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () {}),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextItem(String text, {bool isBold = false, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color = status?.toLowerCase() == 'approved' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(4), 
        border: Border.all(color: color, width: 0.5)
      ),
      child: Text(status?.toUpperCase() ?? 'PENDING', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700, 
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 45)
        ),
        onPressed: _prosesKePermintaan, 
        icon: const Icon(Icons.check_circle),
        label: Text("Proses ${_selectedKeys.length} Delivery Order"),
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