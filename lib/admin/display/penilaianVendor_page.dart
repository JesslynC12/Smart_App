import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VendorEvaluationPage extends StatefulWidget {
  const VendorEvaluationPage({super.key});

  @override
  State<VendorEvaluationPage> createState() => _VendorEvaluationPageState();
}

class _VendorEvaluationPageState extends State<VendorEvaluationPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _vendorSearchController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedNik;
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _evaluationData = [];

Future<List<Map<String, dynamic>>> _getVendorSuggestions(String query) async {
  var request = supabase.from('master_vendor').select('nik, vendor_name');
  
  if (query.isNotEmpty) {
    request = request.or('nik.ilike.%$query%, vendor_name.ilike.%$query%');
  }
  
  final response = await request.limit(10).order('vendor_name', ascending: true);
  return List<Map<String, dynamic>>.from(response);
}

Future<void> _fetchEvaluationData() async {
  if (_selectedNik == null || _selectedDateRange == null) return;

  setState(() => _isLoading = true);
  try {
    // Kita gunakan format ISO String YYYY-MM-DD agar cocok dengan tipe date di DB
    final String startDate = _selectedDateRange!.start.toIso8601String().split('T')[0];
    final String endDate = _selectedDateRange!.end.toIso8601String().split('T')[0];

    final response = await supabase
        .from('shipping_assignments')
       .select('''
          *,
          lead_time_aktual,
          pod_return_aktual,
      id_vendor_details,
          vendor_transportasi!fk_vendor_transport_details (
            lead_time,
            pod_return
          ),
          shipping_request!inner (
            stuffing_date,
            group_id,
            delivery_order (
              do_number,
              customer (
                customer_name
              ),
              do_details (
                qty,
                material (
                  material_name
                )
              )
            )
          )
        ''')
        .inFilter('status_assignment', [
      'check in', 
      'loading', 
      'weighbridge', 
      'keluar', 
      'completed'
    ])
        .eq('nik', _selectedNik!)
        // Filter berdasarkan stuffing_date di tabel shipping_request sesuai filter UI Anda
        .gte('shipping_request.stuffing_date', startDate)
        .lte('shipping_request.stuffing_date', endDate)
        .order('loading_at', ascending: false);

    setState(() {
      _evaluationData = List<Map<String, dynamic>>.from(response);
      print("Data Ditemukan: ${_evaluationData.length}"); // Cek di console
    });
  } catch (e) {
    debugPrint("Error Fetch: $e");
    _showSnackBar("Gagal memuat data: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Penilaian Performa Vendor", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: Column(
        children: [
          _buildFilterArea(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _evaluationData.isEmpty
                    ? const Center(child: Text("Silakan pilih Vendor & Periode untuk melihat data"))
                    : _buildTableArea(),
          ),
        ],
      ),
    );
  }

// List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
//   if (source.isEmpty) return [];
  
//   Map<String, Map<String, dynamic>> groupedMap = {};

//   for (var req in source) {
//     final requestNode = req['shipping_request'];
//     final int? gId = requestNode?['group_id'];
    
//     // Tentukan ID unik baris: pakai Group ID jika ada, jika tidak pakai id_assignment
//     String uniqueKey = gId != null ? "G_$gId" : "S_${req['id_assignment']}";

//     if (!groupedMap.containsKey(uniqueKey)) {
//       groupedMap[uniqueKey] = Map<String, dynamic>.from(req);
//       groupedMap[uniqueKey]!['all_shipping_ids'] = [req['shipping_id']];
      
//       // Ambil daftar DO awal
//       List dos = requestNode?['delivery_order'] is List 
//           ? List.from(requestNode['delivery_order']) 
//           : [];
//       groupedMap[uniqueKey]!['collective_dos'] = dos;
//     } else {
//       // Tambahkan shipping_id baru ke baris yang sama
//       List ids = groupedMap[uniqueKey]!['all_shipping_ids'];
//       if (!ids.contains(req['shipping_id'])) ids.add(req['shipping_id']);
      
//       // Tambahkan DO baru ke list kolektif
//       if (requestNode?['delivery_order'] != null) {
//         groupedMap[uniqueKey]!['collective_dos'].addAll(requestNode['delivery_order']);
//       }
//     }
//   }
//   return groupedMap.values.toList();
// }
List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
  if (source.isEmpty) return [];
  
  Map<String, Map<String, dynamic>> groupedMap = {};

  for (var req in source) {
    final requestNode = req['shipping_request'];
    final int? gId = requestNode?['group_id'];
    
    // Key unik: Tetap pakai Group ID jika ada, jika tidak pakai id_assignment
    String uniqueKey = gId != null ? "G_$gId" : "S_${req['id_assignment']}";

    if (!groupedMap.containsKey(uniqueKey)) {
      groupedMap[uniqueKey] = Map<String, dynamic>.from(req);
      // Gunakan Set untuk ID agar tidak double
      groupedMap[uniqueKey]!['all_shipping_ids'] = {req['shipping_id']};
      
      List dos = requestNode?['delivery_order'] is List 
          ? List.from(requestNode['delivery_order']) 
          : [];
      groupedMap[uniqueKey]!['collective_dos'] = dos;
    } else {
      // Tambahkan ke Set (otomatis mengabaikan jika ID sudah ada)
      (groupedMap[uniqueKey]!['all_shipping_ids'] as Set).add(req['shipping_id']);
      
      // Tambahkan DO hanya jika belum ada di list (berdasarkan do_number)
      List existingDos = groupedMap[uniqueKey]!['collective_dos'];
      List newDos = requestNode?['delivery_order'] ?? [];
      
      for (var nDo in newDos) {
        bool isAlreadyExist = existingDos.any((e) => e['do_number'] == nDo['do_number']);
        if (!isAlreadyExist) {
          existingDos.add(nDo);
        }
      }
    }
  }
  return groupedMap.values.toList();
}

  Widget _buildFilterArea() {
  return Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
      children: [
        // 1. DROPDOWN SEARCH VENDOR (Lebih Panjang)
        Expanded(
          flex: 3,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) => "${option['nik']} - ${option['vendor_name']}",
              
              // Fungsi Filter & Munculkan Data saat diklik
              optionsBuilder: (TextEditingValue textEditingValue) async {
                // Memanggil fungsi yang sama dengan limit 5 agar tidak kepanjangan
                return await _getVendorSuggestions(textEditingValue.text);
              },

              // Tampilan List Dropdown ke bawah (Sesuai Gambar Anda)
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5, // Menyesuaikan lebar filter
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${option['nik']} - ${option['vendor_name']}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option['vendor_name'], // Subtitle
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },

              // Tampilan Field Inputnya
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sinkronisasi controller dengan variabel state jika diperlukan
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: "Ketik untuk mencari...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                );
              },

              onSelected: (Map<String, dynamic> selection) {
                setState(() {
                  _selectedNik = selection['nik'];
                  _vendorSearchController.text = selection['nik']; // Simpan NIK
                });
                _fetchEvaluationData();
              },
            ),
          ),
        ),
        
        const SizedBox(width: 8),

        // 2. TOMBOL PERIODE (Lebih Pendek)
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: _pickDateRange,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _selectedDateRange != null ? Colors.red.shade700 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.date_range, 
                    size: 18, 
                    color: _selectedDateRange != null ? Colors.white : Colors.black87
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _selectedDateRange == null
                          ? "Pilih Periode"
                          : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _selectedDateRange != null ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
//  List<DataColumn> _buildColumns() {
//   return const [
//     DataColumn(label: SizedBox(width: 80, child: Text('Ship ID'))),
//     DataColumn(label: SizedBox(width: 80, child: Text('Stuffing'))),
//     DataColumn(label: SizedBox(width: 90, child: Text('No Polisi'))), // Baru
//     DataColumn(label: SizedBox(width: 100, child: Text('No DO'))),
//     DataColumn(label: SizedBox(width: 160, child: Text('Customer'))),
//     //DataColumn(label: SizedBox(width: 150, child: Text('Material'))),
//     //DataColumn(label: SizedBox(width: 50, child: Text('Qty'))),
//     DataColumn(label: SizedBox(width: 100, child: Text('Ketepatan Waktu Pemasukan'))),
//     DataColumn(label: SizedBox(width: 100, child: Text('Ketepatan Jumlah Pemasukan'))), // Baru
//     DataColumn(label: SizedBox(width: 100, child: Text('Ketepatan Waktu Pengiriman'))),
//     DataColumn(label: SizedBox(width: 100, child: Text('Pengembalian Dokumen Pengiriman'))), // Baru (pengembalian_dokumen_pengiriman)
//     DataColumn(label: SizedBox(width: 100, child: Text('Temuan Kasus/CAR'))), // Baru (0)
//     DataColumn(label: SizedBox(width: 100, child: Text('Kelayakan Kendaraan'))),
//     DataColumn(label: SizedBox(width: 90, child: Text('Nilai LK3'))),
//     DataColumn(label: SizedBox(width: 50, child: Text('Nilai'))), // Baru (0)
//   ];
// }

// List<DataColumn> _buildColumns() {
//   return [
//     _buildCustomColumn('Ship ID', 60),
//     _buildCustomColumn('Stuffing', 80),
//     _buildCustomColumn('No Polisi', 90),
//     _buildCustomColumn('No DO', 100),
//     _buildCustomColumn('Customer Tujuan', 190),
//     _buildCustomColumn('Ketepatan Waktu Pemasukan Harian', 80), // Teks panjang
//     _buildCustomColumn('Ketepatan Jumlah Pemasukan Harian', 75), // Teks panjang
//     _buildCustomColumn('Ketepatan Waktu Kirim', 75),
//     _buildCustomColumn('Doc Balik', 70),
//     _buildCustomColumn('Temuan Kasus', 70),
//     _buildCustomColumn('Kelayakan Unit', 75),
//     _buildCustomColumn('Nilai LK3', 70),
//     _buildCustomColumn('Nilai Akhir', 75),
//   ];
// }

// // Fungsi helper agar kode lebih bersih
// DataColumn _buildCustomColumn(String label, double width) {
//   return DataColumn(
//     label: Container(
//       width: width,
//       child: Text(
//         label,
//         softWrap: true, // Mengizinkan teks turun ke bawah
//         textAlign: TextAlign.center,
//         style: const TextStyle(height: 1.2), // Mengatur jarak antar baris teks
//       ),
//     ),
//   );
// }

// double hitungPengembalianPOD(Map<String, dynamic> data) {
//   try {
//     // 1. Ambil POD Return Aktual (dari shipping_assignments)
//     int aktual = int.tryParse(data['pod_return_aktual']?.toString() ?? "0") ?? 0;

//     // 2. Ambil POD Return Standar (dari relasi vendor_transportasi)
//     var vendorTransport = data['vendor_transportasi'];
//     int standar = 0;
//     if (vendorTransport != null) {
//       standar = int.tryParse(vendorTransport['pod_return']?.toString() ?? "0") ?? 0;
//     }

//     // Jika data standar tidak ada, kita asumsikan tidak bisa dinilai (0)
//     if (standar == 0) return 0.0;

//     // 3. Hitung Selisih Keterlambatan
//     int selisih = aktual - standar;

//     // --- LOGIKA PENILAIAN ---
//     if (selisih <= 0) {
//       return 5.0; // Tidak telat (Aktual <= Standar)
//     } else if (selisih <= 2) {
//       return 3.0; // Telat 1 - 2 hari
//     } else {
//       return 1.0; // Telat > 2 hari
//     }
//   } catch (e) {
//     debugPrint("Error Hitung Doc Balik: $e");
//     return 0.0;
//   }
// }
double hitungPengembalianPOD(Map<String, dynamic> data) {
  try {
    // 1. Ambil POD Return Aktual (Gunakan int? agar bisa mendeteksi null)
    int? aktual = data['pod_return_aktual'] != null 
        ? int.tryParse(data['pod_return_aktual'].toString()) 
        : null;

    // 2. Ambil POD Return Standar
    var vendorTransport = data['vendor_transportasi'];
    int? standar = (vendorTransport != null && vendorTransport['pod_return'] != null)
        ? int.tryParse(vendorTransport['pod_return'].toString())
        : null;

    // LOGIKA KRUSIAL: Jika data aktual atau standar belum ada di DB
    // Kembalikan 0.0 agar UI menampilkan tanda "-"
    if (aktual == null || standar == null) {
      return 0.0;
    }

    // 3. Hitung Selisih Keterlambatan
    int selisih = aktual - standar;

    // --- LOGIKA PENILAIAN ---
    if (selisih <= 0) {
      return 5.0; // Tepat waktu / Lebih cepat
    } else if (selisih <= 2) {
      return 3.0; // Telat 1 - 2 hari
    } else {
      return 1.0; // Telat > 2 hari
    }
  } catch (e) {
    debugPrint("Error Hitung Doc Balik: $e");
    return 0.0;
  }
}
double hitungKetepatanWaktuKirim(Map<String, dynamic> data) {
  try {
    // 1. Ambil Lead Time Aktual (dari shipping_assignments)
    int? aktual = data['lead_time_aktual'] != null 
        ? int.tryParse(data['lead_time_aktual'].toString()) 
        : null;

    // 2. Ambil Lead Time Standar (dari relasi vendor_transportasi)
    var vendorTransport = data['vendor_transportasi'];
    int? standar = vendorTransport != null && vendorTransport['lead_time'] != null
        ? int.tryParse(vendorTransport['lead_time'].toString())
        : null;

    // JIKA DATA TIDAK LENGKAP
    if (aktual == null || standar == null) {
      return 0.0; // Muncul tanda "-" di UI
    }

    // --- LOGIKA PENILAIAN ---
    // Jika aktual <= standar (Misal: standar 3 hari, aktual 2 hari atau 3 hari) -> Poin 5
    if (aktual <= standar) {
      return 5.0;
    } 
    // Jika aktual > standar (Misal: standar 3 hari, aktual 4 hari) -> Poin 1
    else {
      return 1.0;
    }
  } catch (e) {
    debugPrint("Error Hitung Waktu Kirim: $e");
    return 0.0;
  }
}

double hitungKetepatanWaktuMasuk(Map<String, dynamic> data) {
  try {
    // 1. Ambil jam_booking (Contoh: "15:00 - 17:00")
    String? jamBookingRaw = data['jam_booking'];
    // 2. Ambil checkIn_at (Timestamptz dari Supabase)
    dynamic checkInRaw = data['checkIn_at'];

    if (jamBookingRaw == null || checkInRaw == null) return 0.0;

    // --- PROSES JAM BOOKING ---
    // Ambil bagian depan "15:00", lalu ambil angka jamnya saja "15"
    // split(' - ')[0] mengambil "15:00"
    // split(':')[0] mengambil "15"
    String jamDepanStr = jamBookingRaw.split(' - ')[0].split(':')[0];
    int jamBookingBatas = int.parse(jamDepanStr);

    // --- PROSES JAM CHECK-IN ---
    DateTime checkInAt = DateTime.parse(checkInRaw.toString());
    int jamCheckIn = checkInAt.hour;
    int menitCheckIn = checkInAt.minute;

    // --- LOGIKA PENILAIAN ---
    // Sesuai aturan: Datang sebelum atau pas di jam booking depan = 5
    // Jika jam check-in lebih kecil dari jam booking batas -> Poin 5
    if (jamCheckIn < jamBookingBatas) {
      return 5.0;
    } 
    // Jika jam sama, tapi menit ke-0 (tepat waktu) -> Poin 5
    else if (jamCheckIn == jamBookingBatas && menitCheckIn == 0) {
      return 5.0;
    } 
    // Selebihnya (jam lebih besar atau jam sama tapi menit > 0) -> Poin 1
    else {
      return 1.0;
    }
  } catch (e) {
    debugPrint("Error Hitung Waktu: $e");
    return 0.0;
  }
}
List<DataColumn> _buildColumns() {
    return [
      _buildLabel('Ship ID', 60),
      _buildLabel('Stuffing', 70),
      _buildLabel('No Polisi', 85),
      _buildLabel('No DO', 60),
      _buildLabel('Customer Tujuan', 190),
      _buildLabel('Ketepatan Waktu Pemasukan Harian', 70),
      _buildLabel('Ketepatan Jumlah Pemasukan Harian', 70),
      _buildLabel('Ketepatan Waktu Pengiriman', 70),
      _buildLabel('Pengembalian Dokumen Pengiriman', 80),
      _buildLabel('Temuan Kasus/CAR', 60),
      _buildLabel('Kelayakan Unit', 70),
      _buildLabel('Nilai LK3', 60),
      _buildLabel('Nilai Akhir', 60),
    ];
  }

  DataColumn _buildLabel(String label, double width) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, softWrap: true),
      ),
    );
  }

// Widget _buildTableArea() {
//     final List<Map<String, dynamic>> displayData = _getGroupedDisplayData(_evaluationData);

//     if (displayData.isEmpty) {
//       return const Center(child: Text("Tidak ada data pada periode ini."));
//     }

//     return LayoutBuilder(
//       builder: (context, constraints) {
//         return Expanded(
//           child: Column(
//             children: [
//               // --- 1. HEADER TETAP (STICKY) ---
//               SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 child: DataTable(
//                   headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
//                   headingTextStyle: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 12),
//                   columnSpacing: 20,
//                   horizontalMargin: 12,
//                   columns: _buildColumns(),
//                   rows: const [], // Baris kosong hanya untuk menampilkan header
//                 ),
//               ),

//               // --- 2. BODY YANG BISA DI-SCROLL ---
//               Expanded(
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.vertical,
//                   child: SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: DataTable(
//                       headingRowHeight: 0, // Sembunyikan header asli di tabel body
//                       dataRowMaxHeight: double.infinity, // Supaya cell bisa melar ke bawah
//                       dataRowMinHeight: 60,
//                       columnSpacing: 20,
//                       horizontalMargin: 12,
//                       columns: _buildColumns(),
//                       rows: displayData.map((data) {
//                         final requestNode = data['shipping_request'];
//                         final bool isGroup = requestNode?['group_id'] != null;
//                         final List dos = data['collective_dos'] ?? [];

//                         // Ekstrak list material dan qty secara flat
// List<String> listMaterial = [];
// List<String> listQty = [];

// for (var d in dos) {
//   final List details = d['do_details'] ?? [];
//   for (var det in details) {
//     listMaterial.add(det['material']?['material_name']?.toString() ?? "-");
//     listQty.add(det['qty']?.toString() ?? "0");
//   }
// }

//                         return DataRow(
//                           color: WidgetStateProperty.all(isGroup 
//                               ? Colors.blue.shade50.withOpacity(0.5) 
//                               : null),
//                           cells: [
//                             // Ship ID (Menampilkan list ID unik jika grup)
//                             DataCell(SizedBox(
//                               width: 80,
//                               child: Text((data['all_shipping_ids'] as List).toSet().join(", "),
//                                   style: const TextStyle(fontSize: 11)),
//                             )),
                            
//                             // No DO (Menampilkan banyak DO ke bawah)
//                             DataCell(SizedBox(
//                               width: 100,
//                               child: _buildNestedColumn(
//                                   dos.map((d) => d['do_number']?.toString()).toList()),
//                             )),

//                             // Customer Tujuan (Menampilkan banyak Customer ke bawah)
//                             DataCell(SizedBox(
//                               width: 180,
//                               child: _buildNestedColumn(
//                                   dos.map((d) => d['customer']?['customer_name']?.toString()).toList()),
//                             )),
// // KOLOM BARU: MATERIAL
//     DataCell(SizedBox(width: 180, child: _buildNestedColumn(listMaterial))),
    
//     // KOLOM BARU: QTY
//     DataCell(SizedBox(width: 50, child: _buildNestedColumn(listQty))),
//                             // Stuffing Date
//                             DataCell(SizedBox(
//                               width: 80,
//                               child: Text(_formatDate(requestNode?['stuffing_date']),
//                                   style: const TextStyle(fontSize: 11)),
//                             )),

//                             // Kolom-kolom Skor
//                             DataCell(SizedBox(width: 80, child: _buildScoreText(data['ketepatan_waktu_pemasukan_harian']))),
//                             DataCell(SizedBox(width: 80, child: _buildScoreText(data['ketepatan_waktu_pengiriman']))),
//                             DataCell(SizedBox(width: 80, child: _buildScoreText(data['kelayakan_kendaraan']))),
//                             DataCell(SizedBox(width: 80, child: _buildScoreText(data['nilai_kinerja_lk3']))),
//                           ],
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

// Widget _buildTableArea() {
//   final List<Map<String, dynamic>> displayData = _getGroupedDisplayData(_evaluationData);

//   if (displayData.isEmpty) {
//     return const Center(child: Text("Tidak ada data pada periode ini."));
//   }

//   return LayoutBuilder(
//     builder: (context, constraints) {
//       return Expanded(
//         child: Column(
//           children: [
//             // --- 1. HEADER TETAP (STICKY) ---
//             SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: DataTable(
//                 headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
//                 headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
//                 columnSpacing: 20,
//                 horizontalMargin: 12,
//                 columns: _buildColumns(),
//                 rows: const [], // Baris kosong agar hanya header yang tampil
//               ),
//             ),

//             // --- 2. BODY YANG BISA DI-SCROLL ---
//             Expanded(
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.vertical,
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     headingRowHeight: 0, // Sembunyikan header tabel body
//                     dataRowMaxHeight: double.infinity,
//                     dataRowMinHeight: 60,
//                     columnSpacing: 20,
//                     horizontalMargin: 12,
//                     columns: _buildColumns(),
//                     rows: displayData.map((data) {
//                       double skorKelayakan = hitungKelayakanKendaraan(data);
//                       double nilaiLK3 = hitungNilaiLK3(data);
//                       final requestNode = data['shipping_request'];
//                       final bool isGroup = requestNode?['group_id'] != null;
//                       // final List dos = data['collective_dos'] ?? [];

//                       // // Ekstrak Material & Qty dari semua DO yang tergabung
//                       // List<String> listMaterial = [];
//                       // List<String> listQty = [];
//                       // for (var d in dos) {
//                       //   final List details = d['do_details'] ?? [];
//                       //   for (var det in details) {
//                       //     listMaterial.add(det['material']?['material_name']?.toString() ?? "-");
//                       //     listQty.add(det['qty']?.toString() ?? "0");
//                       //   }
//                       // }
//                       final List dos = data['collective_dos'] ?? [];

// // Gunakan List untuk menampung baris unik
// List<String> listMaterial = [];
// List<String> listQty = [];
// List<String> listDoNumbers = [];
// List<String> listCustomers = [];

// // Set untuk melacak kombinasi unik (DO + Material + Qty) agar tidak double tampil
// Set<String> uniqueTracker = {};

// for (var d in dos) {
//   final String doNum = d['do_number']?.toString() ?? "-";
//   final String custName = d['customer']?['customer_name']?.toString() ?? "-";
//   final List details = d['do_details'] ?? [];
  
//   for (var det in details) {
//     final String matName = det['material']?['material_name']?.toString() ?? "-";
//     final String qty = det['qty']?.toString() ?? "0";
    
//     // Kunci unik untuk validasi duplikat tampilan
//     String key = "$doNum|$matName|$qty";
    
//     if (!uniqueTracker.contains(key)) {
//       uniqueTracker.add(key);
//       listDoNumbers.add(doNum);
//       listCustomers.add(custName);
//       listMaterial.add(matName);
//       listQty.add(qty);
//     }
//   }
// }

//                       return DataRow(
//                         color: WidgetStateProperty.all(isGroup ? Colors.blue.shade50.withOpacity(0.5) : null),
//                         cells: [
//                           DataCell(SizedBox(width: 80, child: Text((data['all_shipping_ids'] as Set).toList().join(", "), 
//     style: const TextStyle(fontSize: 10)))),
//     DataCell(SizedBox(width: 80, child: Text(_formatDate(requestNode?['stuffing_date']), style: const TextStyle(fontSize: 11)))),
//     DataCell(SizedBox(width: 90, child: Text(data['no_polisi']?.toString() ?? "-", style: const TextStyle(fontSize: 11)))),
//                           DataCell(SizedBox(width: 100, child: _buildNestedColumn(dos.map((d) => d['do_number']?.toString()).toList()))),
//                           DataCell(SizedBox(width: 190, child: _buildNestedColumn(dos.map((d) => d['customer']?['customer_name']?.toString()).toList()))),
//                           // DataCell(SizedBox(width: 180, child: _buildNestedColumn(listMaterial))),
//                           // DataCell(SizedBox(width: 50, child: _buildNestedColumn(listQty))),
                          
//                           // DataCell(SizedBox(width: 80, child: _buildScoreText(data['ketepatan_waktu_pemasukan_harian']))),
//                           // DataCell(SizedBox(width: 80, child: _buildScoreText(data['ketepatan_waktu_pengiriman']))),
//                           // KETEPATAN WAKTU MASUK
//     DataCell(SizedBox(width: 70, child: _buildScoreText(data['ketepatan_waktu_pemasukan_harian']))),
    
//     // KOLOM BARU: KETEPATAN JUMLAH MASUK
//     DataCell(SizedBox(width: 70, child: _buildScoreText(data['ketepatan_jumlah_pemasukan_harian']))),
    
//     // KETEPATAN WAKTU KIRIM
//     DataCell(SizedBox(width: 70, child: _buildScoreText(data['ketepatan_waktu_pengiriman']))),
    
//     // KOLOM BARU: PENGEMBALIAN DOKUMEN (DOC BALIK)
//     DataCell(SizedBox(width: 70, child: _buildScoreText(data['pengembalian_dokumen_pengiriman']))),

//     // KOLOM BARU: TEMUAN KASUS (Sementara 0)
//     DataCell(SizedBox(width: 70, child: Center(child: Text("0", style: TextStyle(color: Colors.grey.shade600))))),
//                           //DataCell(SizedBox(width: 80, child: _buildScoreText(data['kelayakan_kendaraan']))),
//                           DataCell(
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//           decoration: BoxDecoration(
//             color: skorKelayakan > 0 ? Colors.orange.shade50 : Colors.green.shade50,
//             borderRadius: BorderRadius.circular(5)
//           ),
//           child: Text(
//             skorKelayakan.toStringAsFixed(0), // Tampilkan angka bulat
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: skorKelayakan > 2 ? Colors.red : Colors.black87
//             ),
//           ),
//         ),
//       ),
//                           DataCell(
//         Container(
//           width: 80,
//           alignment: Alignment.center,
//           padding: const EdgeInsets.symmetric(vertical: 5),
//           decoration: BoxDecoration(
//             // Warna merah jika nilai minus atau rendah
//             color: nilaiLK3 < 10 ? Colors.red.shade50 : Colors.blue.shade50,
//             borderRadius: BorderRadius.circular(4),
//           ),
//           child: Text(
//             nilaiLK3.toStringAsFixed(0),
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: nilaiLK3 < 10 ? Colors.red : Colors.blue.shade900,
//             )))),
//             // KOLOM BARU: NILAI (Sementara 0)
//     DataCell(SizedBox(width: 50, child: Center(child: Text("0", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700))))),
//                         ],
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

// Widget _buildTableArea() {
//   final List<Map<String, dynamic>> displayData = _getGroupedDisplayData(_evaluationData);

//   if (displayData.isEmpty) {
//     return const Center(child: Text("Tidak ada data pada periode ini."));
//   }

//   return LayoutBuilder(
//     builder: (context, constraints) {
//       // HAPUS Expanded di sini, karena fungsi ini biasanya dipanggil 
//       // di dalam Expanded yang ada di method build() utama.
//       return Column(
//         children: [
//           // --- 1. HEADER TETAP (STICKY) ---
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: DataTable(
//               headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
//               headingTextStyle: const TextStyle(
//                   color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
//               headingRowHeight: 70, // Sesuaikan tinggi agar cukup untuk 2-3 baris teks
//     columnSpacing: 20,
//     horizontalMargin: 10,
//     columns: _buildColumns(),
//               rows: const [], // Baris kosong agar hanya header yang tampil
//             ),
//           ),

//           // --- 2. BODY YANG BISA DI-SCROLL ---
//           Expanded(
//             child: SingleChildScrollView(
//               scrollDirection: Axis.vertical,
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 child: DataTable(
//                   headingRowHeight: 0, // Sembunyikan header tabel body
//                   dataRowMaxHeight: double.infinity,
//                   dataRowMinHeight: 60,
//                   columnSpacing: 16,
//                   horizontalMargin: 12,
//                   columns: _buildColumns(),
//                   rows: displayData.map((data) {
//                     double skorKelayakan = hitungKelayakanKendaraan(data);
//                     double nilaiLK3 = hitungNilaiLK3(data);
//                     final requestNode = data['shipping_request'];
//                     final bool isGroup = requestNode?['group_id'] != null;
//                     final List dos = data['collective_dos'] ?? [];

//                     // Logika unik tracker untuk mencegah material double dalam satu baris
//                     List<String> listMaterial = [];
//                     List<String> listQty = [];
//                     List<String> listDoNumbers = [];
//                     List<String> listCustomers = [];
//                     Set<String> uniqueTracker = {};

//                     for (var d in dos) {
//                       final String doNum = d['do_number']?.toString() ?? "-";
//                       final String custName = d['customer']?['customer_name']?.toString() ?? "-";
//                       final List details = d['do_details'] ?? [];

//                       for (var det in details) {
//                         final String matName = det['material']?['material_name']?.toString() ?? "-";
//                         final String qty = det['qty']?.toString() ?? "0";
//                         String key = "$doNum|$matName|$qty";

//                         if (!uniqueTracker.contains(key)) {
//                           uniqueTracker.add(key);
//                           if (!listDoNumbers.contains(doNum)) listDoNumbers.add(doNum);
//                           if (!listCustomers.contains(custName)) listCustomers.add(custName);
//                           listMaterial.add(matName);
//                           listQty.add(qty);
//                         }
//                       }
//                     }

//                     return DataRow(
//                       color: WidgetStateProperty.all(
//                           isGroup ? Colors.blue.shade50.withOpacity(0.5) : null),
//                       cells: [
//                         // 1. Ship ID
//                         DataCell(SizedBox(
//                             width: 60,
//                             child: Text(
//                                 (data['all_shipping_ids'] as Set).toList().join(", "),
//                                 style: const TextStyle(fontSize: 10)))),
//                         // 2. Stuffing
//                         DataCell(SizedBox(
//                             width: 50,
//                             child: Text(_formatDate(requestNode?['stuffing_date']),
//                                 style: const TextStyle(fontSize: 11)))),
//                         // 3. No Polisi
//                         DataCell(SizedBox(
//                             width: 65,
//                             child: Text(data['no_polisi']?.toString() ?? "-",
//                                 style: const TextStyle(fontSize: 11)))),
//                         // 4. No DO
//                         DataCell(SizedBox(
//                             width: 65,
//                             child: _buildNestedColumn(listDoNumbers))),
                            
//                         // 5. Customer
//                         DataCell(SizedBox(
//                             width: 210,
//                             child: _buildNestedColumn(listCustomers))),
//                         // 6. Kwt Waktu Masuk
//                         DataCell(SizedBox(
//                             width: 70,
//                             child: _buildScoreText(
//                                 data['ketepatan_waktu_pemasukan_harian']))),
//                         // 7. Kwt Jumlah Masuk
//                         DataCell(SizedBox(
//                             width: 70,
//                             child: _buildScoreText(
//                                 data['ketepatan_jumlah_pemasukan_harian']))),
//                         // 8. Kwt Waktu Kirim
//                         DataCell(SizedBox(
//                             width: 70,
//                             child: _buildScoreText(
//                                 data['ketepatan_waktu_pengiriman']))),
//                         // 9. Doc Balik
//                         DataCell(SizedBox(
//                             width: 70,
//                             child: _buildScoreText(
//                                 data['pengembalian_dokumen_pengiriman']))),
//                         // 10. Temuan Kasus
//                         DataCell(SizedBox(
//                             width: 70,
//                             child: Center(
//                                 child: Text("0",
//                                     style: TextStyle(
//                                         color: Colors.grey.shade600))))),
//                         // 11. Kelayakan
//                         DataCell(Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                               color: skorKelayakan > 0
//                                   ? Colors.orange.shade50
//                                   : Colors.green.shade50,
//                               borderRadius: BorderRadius.circular(5)),
//                           child: Text(skorKelayakan.toStringAsFixed(0),
//                               style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: skorKelayakan > 2
//                                       ? Colors.red
//                                       : Colors.black87)),
//                         )),
//                         // 12. Nilai LK3
//                         DataCell(Container(
//                             width: 80,
//                             alignment: Alignment.center,
//                             padding: const EdgeInsets.symmetric(vertical: 5),
//                             decoration: BoxDecoration(
//                               color: nilaiLK3 < 10
//                                   ? Colors.red.shade50
//                                   : Colors.blue.shade50,
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                             child: Text(nilaiLK3.toStringAsFixed(0),
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: nilaiLK3 < 10
//                                       ? Colors.red
//                                       : Colors.blue.shade900,
//                                 )))),
//                         // 13. Nilai (Final)
//                         DataCell(SizedBox(
//                             width: 50,
//                             child: Center(
//                                 child: Text("0",
//                                     style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.grey.shade700))))),
//                       ],
//                     );
//                   }).toList(),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
//     },
//   );
// }
Widget _buildTableArea() {
    final List<Map<String, dynamic>> displayData = _getGroupedDisplayData(_evaluationData);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // 1. HEADER (FIXED)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
                headingTextStyle: const TextStyle(color: Colors.white),
                headingRowHeight: 80,
                columnSpacing: 22,
                horizontalMargin: 12,
                columns: _buildColumns(),
                rows: const [],
              ),
            ),
            // 2. BODY (SCROLLABLE)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 0,
                    dataRowMaxHeight: double.infinity,
                    dataRowMinHeight: 60,
                    columnSpacing: 20,
                    horizontalMargin: 12,
                    columns: _buildColumns(),
                    rows: displayData.map((data) {
                      double skorKelayakan = hitungKelayakanKendaraan(data);
                      double nilaiLK3 = hitungNilaiLK3(data);
                      double poinWaktuMasuk = hitungKetepatanWaktuMasuk(data);
                      double poinDocBalik = hitungPengembalianPOD(data);
                      double poinWaktuKirim = hitungKetepatanWaktuKirim(data);
                      double nilaiAkhir = hitungNilaiAkhir(data);
                      final List dos = data['collective_dos'] ?? [];
                      
                      Set<String> uniqueDOs = dos.map((d) => d['do_number']?.toString() ?? "").toSet();
                      Set<String> uniqueCusts = dos.map((d) => d['customer']?['customer_name']?.toString() ?? "").toSet();

                      return DataRow(
                        color: WidgetStateProperty.all(data['shipping_request']?['group_id'] != null ? Colors.blue.shade50.withOpacity(0.4) : null),
                        cells: [
                          _buildValueCell((data['all_shipping_ids'] as Set).toList().join(", "), 40),
                          _buildValueCell(_formatDate(data['shipping_request']?['stuffing_date']), 60),
                          _buildValueCell(data['no_polisi']?.toString() ?? "-", 95),
                          DataCell(SizedBox(width: 60, child: _buildNestedColumn(uniqueDOs.toList()))),
                          DataCell(SizedBox(width: 180, child: _buildNestedColumn(uniqueCusts.toList()))),
                         // _buildScoreCell(data['ketepatan_waktu_pemasukan_harian'], 70),
                         // KOLOM KETEPATAN WAKTU MASUK
    DataCell(
  SizedBox(
    width: 70,
    child: Center(
      child: Container(
        // Perkecil padding agar seragam (horizontal 4, vertical 2)
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        // Tambahkan constraints agar ukuran kotak konsisten
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(
          color: poinWaktuMasuk == 5 ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            width: 0.8, // Garis lebih tipis agar halus
            color: poinWaktuMasuk == 5 ? Colors.green.shade200 : Colors.red.shade200,
          ),
        ),
        child: Text(
          poinWaktuMasuk == 0 ? "-" : poinWaktuMasuk.toStringAsFixed(0),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12, // Samakan ukuran font ke 9
            color: poinWaktuMasuk == 5 ? Colors.green.shade900 : Colors.red.shade900,
          ),
        ),
      ),
    ),
  ),
),
                          _buildScoreCell(data['ketepatan_jumlah_pemasukan_harian'], 75),
                          //_buildScoreCell(data['ketepatan_waktu_pengiriman'], 70),
                          // KOLOM KETEPATAN WAKTU PENGIRIMAN
    DataCell(
      SizedBox(
        width: 70,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              // Hijau untuk poin 5, Merah untuk poin 1
              color: poinWaktuKirim == 5 ? Colors.green.shade50 : 
                     (poinWaktuKirim == 1 ? Colors.red.shade50 : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                width: 0.8,
                color: poinWaktuKirim == 5 ? Colors.green.shade200 : 
                       (poinWaktuKirim == 1 ? Colors.red.shade200 : Colors.grey.shade200),
              ),
            ),
            child: Text(
              poinWaktuKirim == 0 ? "-" : poinWaktuKirim.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: poinWaktuKirim == 5 ? Colors.green.shade900 : 
                       (poinWaktuKirim == 1 ? Colors.red.shade900 : Colors.grey.shade900),
              ),
            ),
          ),
        ),
      ),
    ),
                          //_buildScoreCell(data['pengembalian_dokumen_pengiriman'], 70),
                          // KOLOM DOC BALIK
    DataCell(
      SizedBox(
        width: 70,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: poinDocBalik == 5 ? Colors.green.shade50 : 
                     (poinDocBalik == 3 ? Colors.orange.shade50 : Colors.red.shade50),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                width: 0.8,
                color: poinDocBalik == 5 ? Colors.green.shade200 : 
                       (poinDocBalik == 3 ? Colors.orange.shade200 : Colors.red.shade200),
              ),
            ),
            child: Text(
              poinDocBalik == 0 ? "-" : poinDocBalik.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: poinDocBalik == 5 ? Colors.green.shade900 : 
                       (poinDocBalik == 3 ? Colors.orange.shade900 : Colors.red.shade900),
              ),
            ),
          ),
        ),
      ),
    ),
                          _buildValueCell("0", 65),
                          // DataCell(SizedBox(width: 70, child: Center(child: _buildBadge(skorKelayakan.toStringAsFixed(0), skorKelayakan > 0 ? Colors.red : Colors.green)))),
                          // DataCell(SizedBox(width: 65, child: Center(child: Text(nilaiLK3.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: nilaiLK3 < 30 ? Colors.orange : Colors.blue))))),
                          // 1. KOLOM KELAYAKAN UNIT
DataCell(
  SizedBox(
    width: 70,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(
          // Tambahkan logika: jika 0 maka warna abu-abu netral
          color: skorKelayakan == 5 ? Colors.green.shade50 : 
                 skorKelayakan == 3 ? Colors.orange.shade50 : 
                 skorKelayakan == 1 ? Colors.red.shade50 : 
                 Colors.grey.shade50, // Untuk nilai 0
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            width: 0.8,
            color: skorKelayakan == 5 ? Colors.green.shade200 : 
                   skorKelayakan == 3 ? Colors.orange.shade200 : 
                   skorKelayakan == 1 ? Colors.red.shade200 : 
                   Colors.grey.shade300, // Untuk nilai 0
          ),
        ),
        child: Text(
          // LOGIKA UTAMA: Jika 0 maka tampilkan "-"
          skorKelayakan == 0 ? "-" : skorKelayakan.toStringAsFixed(0),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12, // Sesuaikan dengan standar yang tadi (9)
            color: skorKelayakan == 5 ? Colors.green.shade900 : 
                   skorKelayakan == 3 ? Colors.orange.shade900 : 
                   skorKelayakan == 1 ? Colors.red.shade900 : 
                   Colors.grey.shade600, // Warna teks untuk nilai 0
          ),
        ),
      ),
    ),
  ),
),

// 2. KOLOM NILAI LK3
DataCell(
  SizedBox(
    width: 65,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(
          color: nilaiLK3 == 5 ? Colors.green.shade50 : 
                 nilaiLK3 >= 3 ? Colors.orange.shade50 : 
                 nilaiLK3 > 0 ? Colors.red.shade50 : 
                 Colors.grey.shade50, // Untuk nilai 0
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            width: 0.8,
            color: nilaiLK3 == 5 ? Colors.green.shade200 : 
                   nilaiLK3 >= 3 ? Colors.orange.shade200 : 
                   nilaiLK3 > 0 ? Colors.red.shade200 : 
                   Colors.grey.shade300,
          ),
        ),
        child: Text(
          nilaiLK3 == 0 ? "-" : nilaiLK3.toStringAsFixed(0),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: nilaiLK3 == 5 ? Colors.green.shade900 : 
                   nilaiLK3 >= 3 ? Colors.orange.shade900 : 
                   nilaiLK3 > 0 ? Colors.red.shade900 : 
                   Colors.grey.shade600,
          ),
        ),
      ),
    ),
  ),
),
                          // KOLOM NILAI AKHIR (Final Score)
    DataCell(
      SizedBox(
        width: 60,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            constraints: const BoxConstraints(minWidth: 25),
            decoration: BoxDecoration(
              // Warna Biru untuk hasil akhir agar menonjol
              color: nilaiAkhir == 0 ? Colors.grey.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                width: 0.8,
                color: nilaiAkhir == 0 ? Colors.grey.shade300 : Colors.blue.shade200,
              ),
            ),
            child: Text(
              nilaiAkhir == 0 ? "-" : nilaiAkhir.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: nilaiAkhir == 0 ? Colors.grey.shade600 : Colors.blue.shade900,
              ),
            ),
          ),
        ),
      ),
    ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildAvgBox(String label, double value, {bool isFinal = false}) {
  return Container(
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isFinal ? Colors.blue.shade700 : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isFinal ? Colors.blue.shade900 : Colors.grey.shade300),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: isFinal ? Colors.white70 : Colors.grey.shade600
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value == 0 ? "-" : value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: isFinal ? Colors.white : Colors.black87
          ),
        ),
      ],
    ),
  );
}
  // --- UI HELPERS ---
  DataCell _buildValueCell(String txt, double width) => DataCell(SizedBox(width: width, child: Text(txt, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)));

  DataCell _buildScoreCell(dynamic score, double width) => DataCell(SizedBox(width: width, child: Center(child: _buildScoreText(score))));

  Widget _buildBadge(String txt, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color)), child: Text(txt, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)));

  Widget _buildNestedColumn(List<String?> items) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: items.map((item) => Text(item ?? "-", style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)).toList());
  }
  // Helper untuk menampilkan item list secara vertikal di dalam satu cell
  // Widget _buildNestedColumn(List<String?> items) {
  //   // Gunakan .toSet() jika ingin menghilangkan duplikat di tampilan dalam 1 baris
  //   return Column(
  //     mainAxisAlignment: MainAxisAlignment.center,
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: items.map((item) => Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 4),
  //           child: Text(item ?? "-", 
  //               overflow: TextOverflow.ellipsis,
  //               style: const TextStyle(fontSize: 11)),
  //         )).toList(),
  //   );
  // }
//   Widget _buildNestedColumn(List<String?> items) {
//   // .toSet() menghilangkan duplikat, .toList() mengembalikan ke tipe yang bisa dibaca map
//   return Column(
//     mainAxisAlignment: MainAxisAlignment.center,
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: items.toSet().toList().map((item) => Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Text(
//         item ?? "-", 
//         overflow: TextOverflow.ellipsis,
//         style: const TextStyle(fontSize: 11),
//       ),
//     )).toList(),
//   );
// }

//   double hitungKelayakanKendaraan(Map<String, dynamic> data) {
//   // 1. Daftar kata kunci kondisi yang dicari
//   List<String> daftarKondisi = [
//     "Berkarat",
//     "Bagian Tajam",
//     "Kotor",
//     "Basah",
//     "Berlubang",
//     "Push In/Out"
//   ];

//   // 2. Gabungkan semua data dari 6 sisi ke dalam satu List besar
//   List<dynamic> gabunganSisi = [];
  
//   // Daftar kolom sisi sesuai database Anda
//   List<String> kolomSisi = [
//     'sisi_kanan',
//     'sisi_kiri',
//     'sisi_depan',
//     'sisi_pintu_belakang',
//     'sisi_atap',
//     'sisi_lantai'
//   ];

//   for (var kolom in kolomSisi) {
//     if (data[kolom] != null && data[kolom] is List) {
//       gabunganSisi.addAll(data[kolom]);
//     }
//   }

//   double totalSkorAkhir = 0;

//   // 3. Hitung per kondisi
//   for (var kondisi in daftarKondisi) {
//     // Hitung berapa kali kata 'kondisi' muncul di semua sisi
//     int jumlahMuncul = gabunganSisi.where((item) => 
//       item.toString().toLowerCase() == kondisi.toLowerCase()).length;

//     if (jumlahMuncul > 0) {
//       // Rumus: (Jumlah * 0.1) dibulatkan ke atas
//       // Contoh: 2 * 0.1 = 0.2 -> ceil = 1
//       double hasilPerKondisi = (jumlahMuncul * 0.1).ceilToDouble();
//       totalSkorAkhir += hasilPerKondisi;
//     }
//   }

//   return totalSkorAkhir;
// }

// double hitungKelayakanKendaraan(Map<String, dynamic> data) {
//   // 1. Kondisi fisik yang dihitung per kategori (dikalikan 0.1 dan dibulatkan ke atas)
//   List<String> daftarKondisi = [
//     "Berkarat",
//     "Bagian Tajam",
//     "Kotor",
//     "Basah",
//     "Berlubang",
//     "Push In/Out"
//   ];

//   List<dynamic> gabunganSisi = [];
//   List<String> kolomSisi = [
//     'sisi_kanan', 'sisi_kiri', 'sisi_depan', 
//     'sisi_pintu_belakang', 'sisi_atap', 'sisi_lantai'
//   ];

//   for (var kolom in kolomSisi) {
//     var val = data[kolom];
//     if (val != null && val is List) {
//       gabunganSisi.addAll(val);
//     }
//   }

//   double totalSkorFisik = 0;

//   for (var kondisi in daftarKondisi) {
//     int jumlahMuncul = gabunganSisi.where((item) {
//       if (item == null) return false;
//       return item.toString().trim().toLowerCase() == kondisi.toLowerCase();
//     }).length;

//     if (jumlahMuncul > 0) {
//       // Rumus: (Jumlah muncul * 0.1) dibulatkan ke atas
//       totalSkorFisik += (jumlahMuncul * 0.1).ceilToDouble();
//     }
//   }

//   // 2. Tambahkan Skor dari kolom kondisi_tidak_standar_lainnya
//   // Sesuai permintaan: Jika ada 2 item di array, nilainya +2
//   int skorTambahan = 0;
//   var kondisiLainnya = data['kondisi_tidak_standar_lainnya'];
//   if (kondisiLainnya != null && kondisiLainnya is List) {
//     skorTambahan = kondisiLainnya.length;
//   }

//   //return totalSkorFisik + skorTambahan;
//   double totalTemuan = totalSkorFisik + skorTambahan;

//   if (totalTemuan > 3) {
//     return 1.0; // Jika temuan banyak (>3), poin rendah
//   } else if (totalTemuan > 0) {
//     return 3.0; // Jika ada temuan tapi sedikit (1-3), poin sedang
//   } else {
//     return 5.0; // Jika tidak ada temuan sama sekali (0), poin sempurna
//   }
// }
double hitungKelayakanKendaraan(Map<String, dynamic> data) {
  // --- PENGECEKAN VALIDASI DATA ---
  // Kita cek salah satu kolom sisi (misal sisi_kanan) atau kolom keputusan.
  // Jika null, artinya unit ini memang belum melewati proses inspeksi/check-in.
  if (data['sisi_kanan'] == null && data['decision_for_unit'] == null) {
    return 0.0; // Mengembalikan 0.0 agar muncul tanda "-" di UI
  }

  // 1. Kondisi fisik yang dihitung per kategori
  List<String> daftarKondisi = [
    "Berkarat",
    "Bagian Tajam",
    "Kotor",
    "Basah",
    "Berlubang",
    "Push In/Out"
  ];

  List<dynamic> gabunganSisi = [];
  List<String> kolomSisi = [
    'sisi_kanan', 'sisi_kiri', 'sisi_depan', 
    'sisi_pintu_belakang', 'sisi_atap', 'sisi_lantai'
  ];

  for (var kolom in kolomSisi) {
    var val = data[kolom];
    if (val != null && val is List) {
      gabunganSisi.addAll(val);
    }
  }

  double totalSkorFisik = 0;
  for (var kondisi in daftarKondisi) {
    int jumlahMuncul = gabunganSisi.where((item) {
      if (item == null) return false;
      return item.toString().trim().toLowerCase() == kondisi.toLowerCase();
    }).length;

    if (jumlahMuncul > 0) {
      totalSkorFisik += (jumlahMuncul * 0.1).ceilToDouble();
    }
  }

  // 2. Tambahkan Skor dari kolom kondisi_tidak_standar_lainnya
  int skorTambahan = 0;
  var kondisiLainnya = data['kondisi_tidak_standar_lainnya'];
  if (kondisiLainnya != null && kondisiLainnya is List) {
    skorTambahan = kondisiLainnya.length;
  }

  // --- LOGIKA POIN AKHIR ---
  double totalTemuan = totalSkorFisik + skorTambahan;

  if (totalTemuan > 3) {
    return 1.0; // Temuan banyak
  } else if (totalTemuan > 0) {
    return 3.0; // Temuan sedikit
  } else {
    return 5.0; // Tidak ada temuan (Layak Sempurna)
  }
}

// double hitungNilaiLK3(Map<String, dynamic> data) {
//   // --- 1. Dokumen Pendukung (Array) ---
//   // Setiap item bernilai 5
//   int skorDokumen = 0;
//   var dokumen = data['dokumen_pendukung'];
//   if (dokumen != null && dokumen is List) {
//     skorDokumen = dokumen.length * 5;
//   }

//   // --- 2. Ganjal Roda (Text) ---
//   int skorGanjal = 0;
//   String ganjal = (data['ganjal_roda'] ?? "").toString().toLowerCase();
  
//   if (ganjal == "1 Standard") {
//     skorGanjal = 1 * 5;
//   } else if (ganjal == "2 Standard") {
//     skorGanjal = 2 * 5;
//   } else if (ganjal == "1 Tidak Standard") {
//     skorGanjal = 1 * 3;
//   } else if (ganjal == "2 Tidak Standard") {
//     skorGanjal = 2 * 3;
//   } else if (ganjal == "Tidak Ada") {
//     skorGanjal = -5;
//   }

//   // --- 3. Rem / Handrem (Text) ---
//   int skorRem = 0;
//   String rem = (data['rem_handrem'] ?? "").toString().toLowerCase();
  
//   if (rem == "Hand Rem") {
//     skorRem = 5;
//   } else if (rem == "Tidak Ada/Tidak Standard") {
//     skorRem = -5;
//   }

//   // --- 4. APD Supir (Array) ---
//   // Setiap item bernilai 5
//   int skorAPD = 0;
//   var apd = data['apd_supir'];
//   if (apd != null && apd is List) {
//     skorAPD = apd.length * 5;
//   }

//   // TOTAL PENJUMLAHAN
//   return (skorDokumen + skorGanjal + skorRem + skorAPD).toDouble();
// }

// double hitungNilaiLK3(Map<String, dynamic> data) {
//   // --- 1. Dokumen Pendukung (Array) ---
//   int skorDokumen = 0;
//   var dokumen = data['dokumen_pendukung'];
//   if (dokumen != null && dokumen is List) {
//     skorDokumen = dokumen.length * 5;
//   }

//   // --- 2. Ganjal Roda (Text) ---
//   int skorGanjal = 0;
//   String ganjal = (data['ganjal_roda']?.toString() ?? "").trim().toLowerCase();
  
//   if (ganjal.contains("2 standard") || ganjal.contains("2 standar")) {
//     skorGanjal = 10;
//   } else if (ganjal.contains("1 standard") || ganjal.contains("1 standar")) {
//     skorGanjal = 5;
//   } else if (ganjal.contains("2 tidak standard") || ganjal.contains("2 tidak standar")) {
//     skorGanjal = 6;
//   } else if (ganjal.contains("1 tidak standard") || ganjal.contains("1 tidak standar")) {
//     skorGanjal = 3;
//   } else if (ganjal.contains("tidak ada")) {
//     skorGanjal = -5;
//   }

//   // --- 3. Rem / Handrem (Text) ---
//   int skorRem = 0;
//   String rem = (data['rem_handrem']?.toString() ?? "").trim().toLowerCase();
  
//   // Menggunakan contains agar lebih aman jika ada perbedaan spasi
//   if (rem.contains("hand rem") || rem.contains("handrem")) {
//     skorRem = 5;
//   } else if (rem.contains("tidak ada") || rem.contains("tidak standard")) {
//     skorRem = -5;
//   }

//   // --- 4. APD Supir (Array) ---
//   int skorAPD = 0;
//   var apd = data['apd_supir'];
//   if (apd != null && apd is List) {
//     skorAPD = apd.length * 5;
//   }

//   return (skorDokumen + skorGanjal + skorRem + skorAPD).toDouble();
//   //print("Ship ID ${data['shipping_id']}: Doc($skorDokumen), Ganjal($skorGanjal), Rem($skorRem), APD($skorAPD)");
// }
double hitungNilaiLK3(Map<String, dynamic> data) {
  // --- PENGECEKAN DATA NULL ---
  // Kita cek ganjal_roda atau rem_handrem. 
  // Jika keduanya null, berarti penilaian LK3 belum dilakukan.
  if (data['ganjal_roda'] == null && data['rem_handrem'] == null) {
    return 0.0; // Mengembalikan 0.0 agar muncul "-" di UI
  }

  // --- 1. Dokumen Pendukung (Array) ---
  int skorDokumen = 0;
  var dokumen = data['dokumen_pendukung'];
  if (dokumen != null && dokumen is List) {
    skorDokumen = dokumen.length * 5;
  }

  // --- 2. Ganjal Roda (Text) ---
  int skorGanjal = 0;
  String ganjal = (data['ganjal_roda']?.toString() ?? "").trim().toLowerCase();
  
  if (ganjal.contains("2 standard") || ganjal.contains("2 standar")) {
    skorGanjal = 10;
  } else if (ganjal.contains("1 standard") || ganjal.contains("1 standar")) {
    skorGanjal = 5;
  } else if (ganjal.contains("2 tidak standard") || ganjal.contains("2 tidak standar")) {
    skorGanjal = 6;
  } else if (ganjal.contains("1 tidak standard") || ganjal.contains("1 tidak standar")) {
    skorGanjal = 3;
  } else if (ganjal.contains("tidak ada")) {
    skorGanjal = -5;
  }

  // --- 3. Rem / Handrem (Text) ---
  int skorRem = 0;
  String rem = (data['rem_handrem']?.toString() ?? "").trim().toLowerCase();
  
  if (rem.contains("hand rem") || rem.contains("handrem")) {
    skorRem = 5;
  } else if (rem.contains("tidak ada") || rem.contains("tidak standard")) {
    skorRem = -5;
  }

  // --- 4. APD Supir (Array) ---
  int skorAPD = 0;
  var apd = data['apd_supir'];
  if (apd != null && apd is List) {
    skorAPD = apd.length * 5;
  }

  // Hitung Skor Kalkulasi Awal
  int totalKalkulasi = skorDokumen + skorGanjal + skorRem + skorAPD;

  // --- LOGIKA KONVERSI KE POIN (1 - 5) ---
  if (totalKalkulasi < 40) {
    return 1.0;
  } else if (totalKalkulasi < 43) {
    return 2.0;
  } else if (totalKalkulasi < 45) {
    return 3.0;
  } else if (totalKalkulasi < 50) {
    return 4.0;
  } else {
    return 5.0; // Jika skor == 50 (atau lebih)
  }
}
double hitungNilaiAkhir(Map<String, dynamic> data) {
  // 1. Ambil semua poin dari fungsi yang sudah ada
  double pWaktuMasuk = hitungKetepatanWaktuMasuk(data);
  double pJumlahMasuk = double.tryParse(data['ketepatan_jumlah_pemasukan_harian']?.toString() ?? "0") ?? 0;
  double pWaktuKirim = hitungKetepatanWaktuKirim(data);
  double pDocBalik = hitungPengembalianPOD(data);
  double pKelayakan = hitungKelayakanKendaraan(data);

  // Jika semua data masih 0 (belum ada penilaian), kembalikan 0 agar muncul "-"
  if (pWaktuMasuk == 0 && pWaktuKirim == 0 && pDocBalik == 0 && pKelayakan == 0) {
    return 0.0;
  }

  // 2. Hitung berdasarkan bobot
  // Waktu Masuk (20%), Jumlah Masuk (20%), Waktu Kirim (10%), Doc Balik (15%), Kelayakan (20%)
  double total = (pWaktuMasuk * 0.20) + 
                 (pJumlahMasuk * 0.20) + 
                 (pWaktuKirim * 0.10) + 
                 (pDocBalik * 0.15) + 
                 (pKelayakan * 0.20);

  return total;
}
double _calculateColumnAvg(List<Map<String, dynamic>> displayData, String type) {
  if (displayData.isEmpty) return 0.0;

  double totalPoints = 0;
  int countFilledRows = 0; 

  for (var data in displayData) {
    double point = 0;
    
    switch (type) {
      case 'waktu_masuk': point = hitungKetepatanWaktuMasuk(data); break;
      case 'jumlah_masuk': point = double.tryParse(data['ketepatan_jumlah_pemasukan_harian']?.toString() ?? "0") ?? 0; break;
      case 'waktu_kirim': point = hitungKetepatanWaktuKirim(data); break;
      case 'doc_balik': point = hitungPengembalianPOD(data); break;
      case 'kelayakan': point = hitungKelayakanKendaraan(data); break;
      case 'lk3': point = hitungNilaiLK3(data); break;
      case 'akhir': point = hitungNilaiAkhir(data); break;
    }

    // LOGIKA: Karena nilai 1-5 adalah nilai sah, maka 
    // kita hanya menghitung baris yang poinnya > 0 (artinya bukan "-")
    if (point > 0) {
      totalPoints += point;
      countFilledRows++; 
    }
  }

  // Menghasilkan rata-rata hanya dari baris yang sudah dinilai
  return countFilledRows > 0 ? totalPoints / countFilledRows : 0.0;
}
// Widget Helper untuk teks dalam Column agar rapi
Widget _buildCellText(String? text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(text ?? "-", style: const TextStyle(fontSize: 12)),
  );
}

  // UI Helper: Pewarnaan skor otomatis
  Widget _buildScoreText(dynamic score) {
    double val = double.tryParse(score?.toString() ?? "0") ?? 0;
    Color color = val >= 80 ? Colors.green : (val >= 60 ? Colors.orange : Colors.red);
    return Text(
      val.toStringAsFixed(1),
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Future<void> _pickDateRange() async {
  DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2023),
    lastDate: DateTime(2100),
    initialDateRange: _selectedDateRange,
    locale: const Locale('id', 'ID'), // Format hari/bulan Indonesia
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.red.shade700, // Warna header & seleksi
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700, // Warna tombol OKE/BATAL
            ),
          ),
        ),
        // BAGIAN KUNCI: Mengatur ukuran agar tidak Full Screen
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,  // Batasi lebar maksimal agar terlihat seperti pop-up
              maxHeight: 550, // Batasi tinggi maksimal
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15), // Sudut melengkung agar elegan
              child: child!,
            ),
          ),
        ),
      );
    },
  );

  if (picked != null) {
    setState(() {
      _selectedDateRange = picked;
    });
    // Panggil fungsi untuk memfilter data setelah tanggal dipilih
    _fetchEvaluationData(); 
  }
}

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd/MM/yy').format(DateTime.parse(dateStr));
    } catch (e) { return "-"; }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}