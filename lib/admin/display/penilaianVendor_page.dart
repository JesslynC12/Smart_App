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
          id_assignment,
          shipping_id,
          loading_at,
          no_surat_jalan,
          no_polisi,
          ketepatan_waktu_pemasukan_harian,
          ketepatan_waktu_pengiriman,
          ketepatan_jumlah_pemasukan_harian,
          kelayakan_kendaraan,
          nilai_kinerja_lk3,
          sisi_kanan,
          sisi_kiri,
          sisi_depan,
          sisi_pintu_belakang,
          sisi_atap,
          sisi_lantai,
          kondisi_tidak_standar_lainnya,
          dokumen_pendukung,
  ganjal_roda,
  rem_handrem,
  apd_supir,
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
 List<DataColumn> _buildColumns() {
  return const [
    DataColumn(label: SizedBox(width: 80, child: Text('Ship ID'))),
    DataColumn(label: SizedBox(width: 80, child: Text('Stuffing'))),
    DataColumn(label: SizedBox(width: 90, child: Text('No Polisi'))), // Baru
    DataColumn(label: SizedBox(width: 100, child: Text('No DO'))),
    DataColumn(label: SizedBox(width: 160, child: Text('Customer'))),
    //DataColumn(label: SizedBox(width: 150, child: Text('Material'))),
    //DataColumn(label: SizedBox(width: 50, child: Text('Qty'))),
    DataColumn(label: SizedBox(width: 80, child: Text('Ketepatan Waktu Pemasukan'))),
    DataColumn(label: SizedBox(width: 80, child: Text('Ketepatan Jumlah Pemasukan'))), // Baru
    DataColumn(label: SizedBox(width: 80, child: Text('Ketepatan Wakttu Pengiriman'))),
    DataColumn(label: SizedBox(width: 80, child: Text('Pengembalian Dokumen Pengiriman'))), // Baru (pengembalian_dokumen_pengiriman)
    DataColumn(label: SizedBox(width: 80, child: Text('Temuan Kasus/CAR'))), // Baru (0)
    DataColumn(label: SizedBox(width: 70, child: Text('Kelayakan Kendaraan'))),
    DataColumn(label: SizedBox(width: 70, child: Text('Nilai LK3'))),
    DataColumn(label: SizedBox(width: 50, child: Text('Nilai'))), // Baru (0)
  ];
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

Widget _buildTableArea() {
  final List<Map<String, dynamic>> displayData = _getGroupedDisplayData(_evaluationData);

  if (displayData.isEmpty) {
    return const Center(child: Text("Tidak ada data pada periode ini."));
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      return Expanded(
        child: Column(
          children: [
            // --- 1. HEADER TETAP (STICKY) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                columnSpacing: 20,
                horizontalMargin: 12,
                columns: _buildColumns(),
                rows: const [], // Baris kosong agar hanya header yang tampil
              ),
            ),

            // --- 2. BODY YANG BISA DI-SCROLL ---
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 0, // Sembunyikan header tabel body
                    dataRowMaxHeight: double.infinity,
                    dataRowMinHeight: 60,
                    columnSpacing: 20,
                    horizontalMargin: 12,
                    columns: _buildColumns(),
                    rows: displayData.map((data) {
                      double skorKelayakan = hitungKelayakanKendaraan(data);
                      double nilaiLK3 = hitungNilaiLK3(data);
                      final requestNode = data['shipping_request'];
                      final bool isGroup = requestNode?['group_id'] != null;
                      // final List dos = data['collective_dos'] ?? [];

                      // // Ekstrak Material & Qty dari semua DO yang tergabung
                      // List<String> listMaterial = [];
                      // List<String> listQty = [];
                      // for (var d in dos) {
                      //   final List details = d['do_details'] ?? [];
                      //   for (var det in details) {
                      //     listMaterial.add(det['material']?['material_name']?.toString() ?? "-");
                      //     listQty.add(det['qty']?.toString() ?? "0");
                      //   }
                      // }
                      final List dos = data['collective_dos'] ?? [];

// Gunakan List untuk menampung baris unik
List<String> listMaterial = [];
List<String> listQty = [];
List<String> listDoNumbers = [];
List<String> listCustomers = [];

// Set untuk melacak kombinasi unik (DO + Material + Qty) agar tidak double tampil
Set<String> uniqueTracker = {};

for (var d in dos) {
  final String doNum = d['do_number']?.toString() ?? "-";
  final String custName = d['customer']?['customer_name']?.toString() ?? "-";
  final List details = d['do_details'] ?? [];
  
  for (var det in details) {
    final String matName = det['material']?['material_name']?.toString() ?? "-";
    final String qty = det['qty']?.toString() ?? "0";
    
    // Kunci unik untuk validasi duplikat tampilan
    String key = "$doNum|$matName|$qty";
    
    if (!uniqueTracker.contains(key)) {
      uniqueTracker.add(key);
      listDoNumbers.add(doNum);
      listCustomers.add(custName);
      listMaterial.add(matName);
      listQty.add(qty);
    }
  }
}

                      return DataRow(
                        color: WidgetStateProperty.all(isGroup ? Colors.blue.shade50.withOpacity(0.5) : null),
                        cells: [
                          DataCell(SizedBox(width: 80, child: Text((data['all_shipping_ids'] as Set).toList().join(", "), 
    style: const TextStyle(fontSize: 10)))),
    DataCell(SizedBox(width: 80, child: Text(_formatDate(requestNode?['stuffing_date']), style: const TextStyle(fontSize: 11)))),
    DataCell(SizedBox(width: 90, child: Text(data['no_polisi']?.toString() ?? "-", style: const TextStyle(fontSize: 11)))),
                          DataCell(SizedBox(width: 100, child: _buildNestedColumn(dos.map((d) => d['do_number']?.toString()).toList()))),
                          DataCell(SizedBox(width: 190, child: _buildNestedColumn(dos.map((d) => d['customer']?['customer_name']?.toString()).toList()))),
                          // DataCell(SizedBox(width: 180, child: _buildNestedColumn(listMaterial))),
                          // DataCell(SizedBox(width: 50, child: _buildNestedColumn(listQty))),
                          
                          // DataCell(SizedBox(width: 80, child: _buildScoreText(data['ketepatan_waktu_pemasukan_harian']))),
                          // DataCell(SizedBox(width: 80, child: _buildScoreText(data['ketepatan_waktu_pengiriman']))),
                          // KETEPATAN WAKTU MASUK
    DataCell(SizedBox(width: 70, child: _buildScoreText(data['ketepatan_waktu_pemasukan_harian']))),
    
    // KOLOM BARU: KETEPATAN JUMLAH MASUK
    DataCell(SizedBox(width: 70, child: _buildScoreText(data['ketepatan_jumlah_pemasukan_harian']))),
    
    // KETEPATAN WAKTU KIRIM
    DataCell(SizedBox(width: 70, child: _buildScoreText(data['ketepatan_waktu_pengiriman']))),
    
    // KOLOM BARU: PENGEMBALIAN DOKUMEN (DOC BALIK)
    DataCell(SizedBox(width: 70, child: _buildScoreText(data['pengembalian_dokumen_pengiriman']))),

    // KOLOM BARU: TEMUAN KASUS (Sementara 0)
    DataCell(SizedBox(width: 70, child: Center(child: Text("0", style: TextStyle(color: Colors.grey.shade600))))),
                          //DataCell(SizedBox(width: 80, child: _buildScoreText(data['kelayakan_kendaraan']))),
                          DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: skorKelayakan > 0 ? Colors.orange.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(5)
          ),
          child: Text(
            skorKelayakan.toStringAsFixed(0), // Tampilkan angka bulat
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: skorKelayakan > 2 ? Colors.red : Colors.black87
            ),
          ),
        ),
      ),
                          DataCell(
        Container(
          width: 80,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            // Warna merah jika nilai minus atau rendah
            color: nilaiLK3 < 10 ? Colors.red.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            nilaiLK3.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: nilaiLK3 < 10 ? Colors.red : Colors.blue.shade900,
            )))),
            // KOLOM BARU: NILAI (Sementara 0)
    DataCell(SizedBox(width: 50, child: Center(child: Text("0", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700))))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
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
  Widget _buildNestedColumn(List<String?> items) {
  // .toSet() menghilangkan duplikat, .toList() mengembalikan ke tipe yang bisa dibaca map
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items.toSet().toList().map((item) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        item ?? "-", 
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    )).toList(),
  );
}

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
double hitungKelayakanKendaraan(Map<String, dynamic> data) {
  // 1. Kondisi fisik yang dihitung per kategori (dikalikan 0.1 dan dibulatkan ke atas)
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
      // Rumus: (Jumlah muncul * 0.1) dibulatkan ke atas
      totalSkorFisik += (jumlahMuncul * 0.1).ceilToDouble();
    }
  }

  // 2. Tambahkan Skor dari kolom kondisi_tidak_standar_lainnya
  // Sesuai permintaan: Jika ada 2 item di array, nilainya +2
  int skorTambahan = 0;
  var kondisiLainnya = data['kondisi_tidak_standar_lainnya'];
  if (kondisiLainnya != null && kondisiLainnya is List) {
    skorTambahan = kondisiLainnya.length;
  }

  return totalSkorFisik + skorTambahan;
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
double hitungNilaiLK3(Map<String, dynamic> data) {
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
  
  // Menggunakan contains agar lebih aman jika ada perbedaan spasi
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

  return (skorDokumen + skorGanjal + skorRem + skorAPD).toDouble();
  //print("Ship ID ${data['shipping_id']}: Doc($skorDokumen), Ganjal($skorGanjal), Rem($skorRem), APD($skorAPD)");
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