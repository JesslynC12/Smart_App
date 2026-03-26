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
  String _searchQuery = "";
DateTimeRange? _selectedDateRange;
  
  // Menggunakan Set<String> untuk menyimpan kunci unik "shippingId_doNumber"
  //final Set<String> _selectedKeys = {}; 
  final Set<int> _selectedIds = {};
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


// Future<void> _fetchShippingRequests() async {
//   try {
//     setState(() => _isLoading = true);
    
//     // Query dengan filter status 'waiting approval'
//     // Dan filter agar hanya menampilkan yang belum ada di shipping_request_details
//     final response = await supabase
//         .from('shipping_request')
//         .select('''
//           *,
//           delivery_order (
//             do_number,
//             customer (customer_name),
//             do_details (qty, material_id, material (material_name))
//           ),
//           shipping_request_details!left(do_number)
//         ''')
//         .eq('status', 'waiting approval') // Hanya yang berstatus waiting approval
//         .isFilter('shipping_request_details', null) // Hanya yang belum diproses
//         .order('shipping_id', ascending: false); // Urutkan dari yang terbaru

//     List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);
//     List<Map<String, dynamic>> flattenedData = [];

//     for (var request in rawData) {
//       final List dos = request['delivery_order'] ?? [];
      
//       // Mengatasi error _JsonMap vs List<dynamic>
//       final dynamic rawDetails = request['shipping_request_details'];
//       List processedDetails = [];
//       if (rawDetails is List) {
//         processedDetails = rawDetails;
//       } else if (rawDetails is Map) {
//         processedDetails = [rawDetails];
//       }

//       // Ambil daftar nomor DO yang sudah ada di tabel detail (jika ada)
//       final List<String> processedDoNumbers = processedDetails
//           .map((d) => d['do_number'].toString())
//           .toList();

//       for (var doItem in dos) {
//         String doNum = doItem['do_number'] ?? "no-do";
        
//         // Filter di sisi client: Hanya masukkan DO yang belum diproses
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
//     _showSnackBar("Gagal ambil data: $e", Colors.red);
//     print("Error Detail: $e");
//   }
// }

Future<void> _fetchShippingRequests() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await supabase
          .from('shipping_request')
          .select('''
            *,
            delivery_order (
              do_number,
              customer (customer_name),
              do_details (qty, material (material_name, net_weight))
            )
          ''')
          .eq('status', 'waiting approval') 
          .order('shipping_id', ascending: false);

      List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      setState(() {
        _allRequests = data;
        _filteredRequests = _allRequests;
        _isLoading = false;
        _selectedIds.clear();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal ambil data: $e", Colors.red);
    }
  }

void _toggleSelectAll(bool? selected) {
  setState(() {
    if (selected == true) {
      // Masukkan semua unique_key dari data yang sedang tampil (filtered)
      for (var req in _filteredRequests) {
        // _selectedKeys.add(req['shipping_id']);
        _selectedIds.add(req['shipping_id']);
      }
    } else {
      // Kosongkan pilihan
      _selectedIds.clear();
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
  if (_selectedIds.isEmpty) return;

  try {
    setState(() => _isLoading = true);

    // 1. Siapkan data insert yang menyertakan do_number
    // List<Map<String, dynamic>> dataToInsert = _selectedKeys.map((key) {
    //   return {
    //     'shipping_id': int.parse(key.split('_')[0]),
    //     'do_number': key.split('_')[1], // Ambil nomor DO dari unique_key
    //   };
    // }).toList();

    // // 2. Insert ke tabel detail
    // await supabase.from('shipping_request_details').insert(dataToInsert);

// Update status shipping_request ke 'waiting GBJ'
      await supabase
          .from('shipping_request')
          .update({'status': 'waiting GBJ'})
          .inFilter('shipping_id', _selectedIds.toList());

    // CATATAN: Jangan update status 'shipping_request' ke 'waiting GBJ' di sini 
    // jika masih ada DO lain yang belum diproses dalam ID yang sama.

    _showSnackBar("Berhasil memproses ${_selectedIds.length} DO", Colors.green);
    setState(() => _selectedIds.clear());
    await _fetchShippingRequests(); 
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal proses: $e", Colors.red);
  }
}

  // void _runFilter(String query) {
  //   setState(() {
  //     if (query.isEmpty) {
  //       _filteredRequests = _allRequests;
  //     } else {
  //       final q = query.toLowerCase();
  //       _filteredRequests = _allRequests.where((item) {
  //         final soNum = (item['so'] ?? "").toString().toLowerCase();
  //         final doItem = item['single_do'] ?? {};
  //         final doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
  //         final custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
          
  //         final List details = doItem['do_details'] ?? [];
  //         bool matchMaterial = details.any((det) => 
  //           (det['material']?['material_name'] ?? "").toString().toLowerCase().contains(q)
  //         );

  //         return soNum.contains(q) || doNum.contains(q) || custName.contains(q) || matchMaterial;
  //       }).toList();
  //     }
  //   });
  // }

  // void _runFilter(String query) {
  //   setState(() {
  //     if (query.isEmpty) {
  //       _filteredRequests = _allRequests;
  //     } else {
  //       final q = query.toLowerCase();
  //       _filteredRequests = _allRequests.where((req) {
  //         final soNum = (req['so'] ?? "").toString().toLowerCase();
  //         final List dos = req['delivery_order'] ?? [];
          
  //         bool matchInDO = dos.any((doItem) {
  //           final doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
  //           final custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
  //           final List details = doItem['do_details'] ?? [];
  //           bool matchMat = details.any((det) => 
  //             (det['material']?['material_name'] ?? "").toString().toLowerCase().contains(q)
  //           );
  //           return doNum.contains(q) || custName.contains(q) || matchMat;
  //         });

  //         return soNum.contains(q) || matchInDO;
  //       }).toList();
  //     }
  //   });
  // }

  void _runFilter(String query) {
  setState(() {
    _searchQuery = query.toLowerCase();

    _filteredRequests = _allRequests.where((req) {
      // 1. --- LOGIKA FILTER TEKS (Termasuk matchInDO) ---
      final soNum = (req['so'] ?? "").toString().toLowerCase();
      final List dos = req['delivery_order'] ?? [];

      // Cek apakah teks ada di Nomor SO
      bool matchInSO = soNum.contains(_searchQuery);

      // Cek apakah teks ada di dalam List DO (Nomor DO, Customer, atau Material)
      bool matchInDO = dos.any((doItem) {
        final doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
        final custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
        final List details = doItem['do_details'] ?? [];

        // Cek kecocokan nama material di dalam detail DO
        bool matchMat = details.any((det) =>
            (det['material']?['material_name'] ?? "").toString().toLowerCase().contains(_searchQuery));

        return doNum.contains(_searchQuery) || custName.contains(_searchQuery) || matchMat;
      });

      // Hasil akhir filter teks: Cocok di SO atau cocok di salah satu DO
      bool matchText = matchInSO || matchInDO;

      // 2. --- LOGIKA FILTER TANGGAL ---
      bool matchDate = true;
      if (_selectedDateRange != null) {
        // Kita gunakan RDD sebagai acuan filter tanggal
        DateTime? rddDate = req['rdd'] != null ? DateTime.tryParse(req['rdd'].toString()) : null;
        
        if (rddDate != null) {
          // Normalisasi tanggal agar hanya membandingkan YYYY-MM-DD
          final startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
          final checkDate = DateTime(rddDate.year, rddDate.month, rddDate.day);

          matchDate = checkDate.isAtSameMomentAs(startDate) || 
                      checkDate.isAtSameMomentAs(endDate) ||
                      (checkDate.isAfter(startDate) && checkDate.isBefore(endDate));
        } else {
          matchDate = false; // Jika tidak ada tanggal RDD, anggap tidak cocok dengan filter tanggal
        }
      }

      // Return TRUE jika teks COCOK dan tanggal COCOK
      return matchText && matchDate;
    }).toList();
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
      bottomNavigationBar: _selectedIds.isNotEmpty ? _buildActionBottomBar() : null,
    //bottomNavigationBar: (_selectedKeys != null && _selectedKeys.isNotEmpty) 
    // ? _buildActionBottomBar() 
    // : null,
    );
  }

String formatSmart(dynamic value) {
  if (value == null) return "0";
  // Parsing ke double dulu untuk memastikan itu angka
  double n = double.tryParse(value.toString()) ?? 0.0;
  
  String rounded = n.toStringAsFixed(3);
  // Trick cerdas: .toString() pada tipe 'num' di Dart 
  // otomatis menghilangkan nol yang tidak perlu.
  return n.toString().replaceAll(RegExp(r'\.0$'), '');
}

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
      children: [
        // Input Pencarian
        Expanded(
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
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _pickDateRange,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedDateRange != null ? Colors.red.shade700 : Colors.grey.shade200,
            foregroundColor: _selectedDateRange != null ? Colors.white : Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(
            _selectedDateRange == null 
                ? " Filter Tanggal" 
                : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
            style: const TextStyle(fontSize: 12),
          ),
        ),

        // Tombol Reset Filter (Hanya muncul jika filter aktif)
        if (_selectedDateRange != null || _searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedDateRange = null;
              });
              _runFilter("");
            },
          ),
      ],
    ),
  );
}
  

  Future<void> _pickDateRange() async {
  DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2023),
    lastDate: DateTime(2100),
    initialDateRange: _selectedDateRange,
    locale: const Locale('id', 'ID'), 
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.red.shade700,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          // Ini memastikan teks input mengikuti format lokal
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
        ),
        child: child!,
      );
    },

  );
  if (picked != null) {
    setState(() => _selectedDateRange = picked);
    _runFilter(_searchController.text);
  }
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
               dataRowMaxHeight: double.infinity, 
                dataRowMinHeight: 70,
                columnSpacing: 1,
                columns: [
                  //DataColumn(label: Text('Pilih')),
                  DataColumn(
    label: Row(
      children: [
        //const Text('Pilih'),
        const SizedBox(width: 1),
        SizedBox(
          width: 20,
          height: 24,
          child: Checkbox(
            side: const BorderSide(color: Colors.white, width: 1.5), // Agar terlihat di header merah
            activeColor: Colors.white,
            checkColor: Colors.red,
            value: _filteredRequests.isNotEmpty && 
                   _filteredRequests.every((req) => _selectedIds.contains(req['shipping_id'])),
            onChanged: _toggleSelectAll,
          ),
          
        ),
        //const SizedBox(width: 1),
        const Text('Pilih'),
      ],
    ),
  ),
                  const DataColumn(label: Text('Ship ID')),
                  const DataColumn(label: Text('No DO')),
                  const DataColumn(label: Text('SO Number')),
                  const DataColumn(label: Text('Customer')),
                  const DataColumn(label: Text('Nama Material')),
                  const DataColumn(label: Text('Qty')),
                  const DataColumn(label: Text('NW')),
const DataColumn(label: Text('TNW')),
                  const DataColumn(label: Text('RDD')),
                  //const DataColumn(label: Text('Status')),
                  const DataColumn(label: Text('Stuffing')),
                  const DataColumn(label: Text('Aksi')),
                ],
                rows: _filteredRequests.map((req) {
                  // final String uniqueKey = req['unique_key'];
                  // final bool isSelected = _selectedKeys.contains(uniqueKey);
                  // final Map<String, dynamic> doItem = req['single_do'] ?? {};
                  // final List details = doItem['do_details'] ?? [];

                  final int shippingId = req['shipping_id'];
                  final bool isSelected = _selectedIds.contains(shippingId);
                  final List dos = req['delivery_order'] ?? [];

                  // Material List UI
                  // List<Widget> matNameWidgets = [];
                  // List<Widget> qtyWidgets = [];
                  List<Widget> doNumW = [], custW = [], matW = [], qtyW = [], nwW = [];
                  double totalNetWeight = 0; // Variabel penampung TNW
                  List<Widget> doNumWidgets = [];
                  List<Widget> custNameWidgets = [];
                  List<Widget> matNameWidgets = [];
                  List<Widget> qtyWidgets = [];

                //   for (var doItem in dos) {
                //     final String currentDo = doItem['do_number'] ?? "-";
                //     final String currentCust = doItem['customer']?['customer_name'] ?? "-";
                //     final List details = doItem['do_details'] ?? [];
                  
                // for (var det in details) {
                //       doNumWidgets.add(_buildTextItem(currentDo, isBold: true, width: 70));
                //       custNameWidgets.add(_buildTextItem(currentCust, width: 180));
                //       matNameWidgets.add(_buildTextItem(det['material']?['material_name'] ?? "-", width: 180));
                //       qtyWidgets.add(_buildTextItem(det['qty']?.toString() ?? "0", isBold: true));
                //     }
                //   }
                for (var d in dos) {
            for (var det in d['do_details']) {
              double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
    double nwValue = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
    
    // Hitung TNW akumulatif untuk Shipping ID ini
    totalNetWeight += (qty * nwValue);

    // Widget untuk kolom NW (per material)
    nwW.add(_buildTextItem(nwValue.toStringAsFixed(2), width: 50));
    
    // Widget eksisting untuk DO Number, Customer, Material, dan Qty
              doNumW.add(_buildTextItem(d['do_number'] ?? "-", isBold: true, width: 80));
              custW.add(_buildTextItem(d['customer']?['customer_name'] ?? "-", width: 140));
              matW.add(_buildTextItem(det['material']?['material_name'] ?? "-", width: 180));
              qtyW.add(_buildTextItem(det['qty']?.toString() ?? "0", isBold: true));
            }
          }
          // Hasil akhir TNW dibagi 1000 sesuai logika Java Anda
double finalTNW = totalNetWeight / 1000;

                  return DataRow(
                    selected: _selectedIds.contains(shippingId),
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) return Colors.red.withOpacity(0.05);
                      return null;
                    }),
                    // cells: [
                    //   DataCell(Checkbox(
                    //     activeColor: Colors.red.shade700,
                    //     value: isSelected,
                    //     onChanged: (val)  {
                    //       setState(() {
                    //         // if (val == true) _selectedKeys.add(uniqueKey);
                    //         // else _selectedKeys.remove(uniqueKey);
                    //         if (val == true) _selectedIds.add(shippingId);
                    //         else _selectedIds.remove(shippingId);
                    //       });
                    //     },
                    //   )),
                    cells: [
              DataCell(Checkbox(
                value: _selectedIds.contains(shippingId),
                onChanged: (v) => setState(() => v! ? _selectedIds.add(shippingId) : _selectedIds.remove(shippingId)),
              )),
                      DataCell(Text(shippingId.toString())),
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: doNumW),
                      )),
                     // DataCell(Text(doItem['do_number'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(req['so'] ?? "-")),
                      // DataCell(_buildTextItem(doItem['customer']?['customer_name'] ?? "-", width: 140)),
                      // DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: matNameWidgets)),
                      // DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: qtyWidgets)),
                      // DataCell(Text(_formatDate(req['rdd']))),
                      DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: custW)),
                      DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: matW)),
                      DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: qtyW)),
                      DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: nwW)),
                      DataCell(Text(
  formatSmart(finalTNW), 
  style: const TextStyle(fontWeight: FontWeight.bold)
)),
                      DataCell(Text(_formatDate(req['rdd']))),
                      DataCell(Text(_formatDate(req['stuffing_date']))),
                      //DataCell(_buildStatusBadge(req['status'])),
                      DataCell(Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 22),onPressed: () => _editShippingRequest(req), // Panggil fungsi Edit
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 22), onPressed: () => _deleteShippingRequest(shippingId), // Panggil fungsi Delete
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
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

Future<void> _deleteShippingRequest(int shippingId) async {
  // Tampilkan dialog konfirmasi
  bool confirm = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Hapus Data"),
      content: Text("Apakah Anda yakin ingin menghapus Shipping ID: $shippingId?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
        TextButton(
          onPressed: () => Navigator.pop(context, true), 
          child: const Text("Hapus", style: TextStyle(color: Colors.red))
        ),
      ],
    ),
  ) ?? false;

  if (confirm) {
    try {
      setState(() => _isLoading = true);
      await supabase.from('shipping_request').delete().eq('shipping_id', shippingId);
      _showSnackBar("Data berhasil dihapus", Colors.green);
      _fetchShippingRequests(); // Refresh data
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal menghapus: $e", Colors.red);
    }
  }
}

// void _editShippingRequest(Map<String, dynamic> req) {
//   final TextEditingController soController = TextEditingController(text: req['so']);
  
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     builder: (context) => Padding(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//         left: 20, right: 20, top: 20
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text("Edit Shipping Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//           const SizedBox(height: 15),
//           TextField(
//             controller: soController,
//             decoration: const InputDecoration(labelText: "Nomor SO", border: OutlineInputBorder()),
//           ),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.blue),
//             onPressed: () async {
//               try {
//                 await supabase
//                     .from('shipping_request')
//                     .update({'so': soController.text})
//                     .eq('shipping_id', req['shipping_id']);
                
//                 Navigator.pop(context);
//                 _showSnackBar("Data berhasil diperbarui", Colors.blue);
//                 _fetchShippingRequests();
//               } catch (e) {
//                 _showSnackBar("Gagal update: $e", Colors.red);
//               }
//             },
//             child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.white)),
//           ),
//           const SizedBox(height: 20),
//         ],
//       ),
//     ),
//   );
// }


// void _editShippingRequest(Map<String, dynamic> req) async {
//   final TextEditingController soController = TextEditingController(text: req['so']?.toString() ?? "");
  
//   // Gunakan parsing yang aman untuk tanggal
//   DateTime? selectedRDD = req['rdd'] != null ? DateTime.tryParse(req['rdd'].toString()) : null;
//   DateTime? selectedStuffing = req['stuffing_date'] != null ? DateTime.tryParse(req['stuffing_date'].toString()) : null;

//   List dos = req['delivery_order'] ?? [];
//   Map<int, TextEditingController> qtyControllers = {};

//   // PERBAIKAN DI SINI: Pastikan details_id tidak null sebelum dimasukkan ke Map
//   for (var doItem in dos) {
//     final List details = doItem['do_details'] ?? [];
//     for (var det in details) {
//       final dynamic rawId = det['details_id'];
//       if (rawId != null) {
//         int detailsId = int.parse(rawId.toString());
//         qtyControllers[detailsId] = TextEditingController(text: det['qty']?.toString() ?? "0");
//       }
//     }
//   }

//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
//     builder: (context) => StatefulBuilder(
//       builder: (context, setModalState) => Padding(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom, 
//           left: 20, right: 20, top: 20
//         ),
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text("Edit Detail Shipping", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//               const Divider(),
              
//               TextField(controller: soController, decoration: const InputDecoration(labelText: "Nomor SO")),
              
//               Row(
//                 children: [
//                   Expanded(
//                     child: ListTile(
//                       title: const Text("RDD", style: TextStyle(fontSize: 12)),
//                       subtitle: Text(selectedRDD == null ? "-" : DateFormat('dd/MM/yy').format(selectedRDD!)),
//                       onTap: () async {
//                         DateTime? picked = await showDatePicker(
//                           context: context, 
//                           initialDate: selectedRDD ?? DateTime.now(), 
//                           firstDate: DateTime(2000), 
//                           lastDate: DateTime(2100)
//                         );
//                         if (picked != null) setModalState(() => selectedRDD = picked);
//                       },
//                     ),
//                   ),
//                   Expanded(
//                     child: ListTile(
//                       title: const Text("Stuffing", style: TextStyle(fontSize: 12)),
//                       subtitle: Text(selectedStuffing == null ? "-" : DateFormat('dd/MM/yy').format(selectedStuffing!)),
//                       onTap: () async {
//                         DateTime? picked = await showDatePicker(
//                           context: context, 
//                           initialDate: selectedStuffing ?? DateTime.now(), 
//                           firstDate: DateTime(2000), 
//                           lastDate: DateTime(2100)
//                         );
//                         if (picked != null) setModalState(() => selectedStuffing = picked);
//                       },
//                     ),
//                   ),
//                 ],
//               ),

//               const Text("Edit Qty per Material", style: TextStyle(fontWeight: FontWeight.bold)),
//               if (qtyControllers.isEmpty) const Text("Tidak ada detail material"),
              
//               ...qtyControllers.entries.map((entry) {
//                 String matName = "Material";
//                 try {
//                   for(var d in dos) {
//                     for(var det in d['do_details']) {
//                       if(det['details_id'].toString() == entry.key.toString()) {
//                         matName = det['material']?['material_name'] ?? "Unknown";
//                       }
//                     }
//                   }
//                 } catch (_) {}

//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4),
//                   child: TextField(
//                     controller: entry.value,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(labelText: "Qty: $matName", isDense: true),
//                   ),
//                 );
//               }).toList(),

//               const SizedBox(height: 20),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   minimumSize: const Size(double.infinity, 50), 
//                   backgroundColor: Colors.blue
//                 ),
//                 onPressed: () async {
//                   try {
//                     // Update Shipping Request
//                     await supabase.from('shipping_request').update({
//                       'so': soController.text,
//                       'rdd': selectedRDD?.toIso8601String(),
//                       'stuffing_date': selectedStuffing?.toIso8601String(),
//                     }).eq('shipping_id', req['shipping_id']);

//                     // Update Qty
//                     for (var entry in qtyControllers.entries) {
//                       int? newQty = int.tryParse(entry.value.text);
//                       if (newQty != null) {
//                         await supabase.from('do_details')
//                             .update({'qty': newQty})
//                             .eq('details_id', entry.key);
//                       }
//                     }

//                     Navigator.pop(context);
//                     _showSnackBar("Data berhasil diperbarui!", Colors.blue);
//                     _fetchShippingRequests();
//                   } catch (e) {
//                     _showSnackBar("Gagal simpan: $e", Colors.red);
//                   }
//                 },
//                 child: const Text("Simpan Semua Perubahan", style: TextStyle(color: Colors.white)),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );
// }

void _editShippingRequest(Map<String, dynamic> req) async {
  // Debugging: Cek di console apakah delivery_order ada isinya
  print("Data yang diedit: $req");

  final TextEditingController soController = TextEditingController(text: req['so']?.toString() ?? "");
  DateTime? selectedRDD = req['rdd'] != null ? DateTime.tryParse(req['rdd'].toString()) : null;
  DateTime? selectedStuffing = req['stuffing_date'] != null ? DateTime.tryParse(req['stuffing_date'].toString()) : null;

  List dos = req['delivery_order'] ?? [];
  
  // Gunakan Map untuk menampung controller qty dan nama material
  // Key: details_id (int), Value: Map berisi controller dan metadata
  Map<int, Map<String, dynamic>> detailEditors = {};

  for (var doItem in dos) {
    // Ambil customer dari level Delivery Order
    String custName = doItem['customer']?['customer_name'] ?? "No Customer";
    List details = doItem['do_details'] ?? [];

    for (var det in details) {
      final int? dId = int.tryParse(det['details_id']?.toString() ?? "");
      if (dId != null) {
        final nw = det['material']?['net_weight'] ?? 0;
        detailEditors[dId] = {
          'controller': TextEditingController(text: det['qty']?.toString() ?? "0"),
          'material_name': det['material']?['material_name'] ?? "Unknown Material",
          'net_weight': nw,
          'customer_name': custName,
          'do_number': doItem['do_number'] ?? "-",
        };
      }
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 20, right: 20, top: 20
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text("Edit Detail Shipping", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              const Divider(),
              
              TextField(controller: soController, decoration: const InputDecoration(labelText: "Nomor SO")),
              
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("RDD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(selectedRDD == null ? "-" : DateFormat('dd/MM/yy').format(selectedRDD!)),
                      trailing: const Icon(Icons.calendar_month, size: 20),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context, 
                          initialDate: selectedRDD ?? DateTime.now(), 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2100)
                        );
                        if (picked != null) setModalState(() => selectedRDD = picked);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Stuffing", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(selectedStuffing == null ? "-" : DateFormat('dd/MM/yy').format(selectedStuffing!)),
                      trailing: const Icon(Icons.calendar_month, size: 20),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context, 
                          initialDate: selectedStuffing ?? DateTime.now(), 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2100)
                        );
                        if (picked != null) setModalState(() => selectedStuffing = picked);
                      },
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text("Edit Material & Qty", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ),

              if (detailEditors.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Data detail material tidak ditemukan."),
                )),
              
              // Tampilkan List Editor untuk Material, Qty, dan Info Customer
              ...detailEditors.entries.map((entry) {
                final data = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("DO: ${data['do_number']} | Cust: ${data['customer_name']}", 
                           style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 5),
                      Text("Material: ${data['material_name']}", style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: data['controller'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Input Qty Baru",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), 
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: () async {
                  try {
                    // 1. Update Tabel Shipping Request
                    await supabase.from('shipping_request').update({
                      'so': soController.text,
                      'rdd': selectedRDD?.toIso8601String(),
                      'stuffing_date': selectedStuffing?.toIso8601String(),
                    }).eq('shipping_id', req['shipping_id']);

                    // 2. Update Qty di do_details
                    for (var entry in detailEditors.entries) {
                      int? newQty = int.tryParse(entry.value['controller'].text);
                      if (newQty != null) {
                        await supabase.from('do_details')
                            .update({'qty': newQty})
                            .eq('details_id', entry.key);
                      }
                    }

                    Navigator.pop(context);
                    _showSnackBar("Perubahan berhasil disimpan!", Colors.green);
                    _fetchShippingRequests();
                  } catch (e) {
                    _showSnackBar("Gagal menyimpan: $e", Colors.red);
                  }
                },
                child: const Text("Simpan Semua Perubahan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    ),
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
        label: Text("Proses ${_selectedIds.length} Delivery Order"),
        //label: Text("Approve ${_selectedIds.length} Shipping Request"),
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