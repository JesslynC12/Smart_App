import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';

class InDashboardItem {
  final String name;
  final String shift;
  final int truck, box, countA, countB, countC, countD;
  final bool isSubtotal;
  InDashboardItem({required this.name,
    required this.shift,
    required this.truck,
    required this.box,
    required this.countA,
    required this.countB,
    required this.countC,
    required this.countD,
    this.isSubtotal = false,});
}

class ChartData {
  final String label;
  final double value;
  final Color color;
  ChartData(this.label, this.value, this.color);
}

class DashboardCombinedPage extends StatefulWidget {
  const DashboardCombinedPage({super.key});
  @override
  State<DashboardCombinedPage> createState() => _DashboardCombinedPageState();
}

class _DashboardCombinedPageState extends State<DashboardCombinedPage> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  bool isRangeMode = false;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();
  String selectedLokasi = 'Semua Lokasi';
  List<String> lokasiOptions = ['Semua Lokasi', 'Rungkut', 'Tambak Langon'];

  bool isLoading = false;
  List<InDashboardItem> tableData = [];
  List<InDashboardItem> grandTotalData = [];
  List<ChartData> barDataDivisi = [];
  List<ChartData> pieDataShift = [];
  List<ChartData> barDataWarehouse = [];

  @override
  void initState() {
    super.initState();
    _refreshAllData();
   // loadDashboardData();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) supabase.removeChannel(_realtimeChannel!);
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = supabase.channel('public:dashboard_stats').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'shipping_assignments',
      callback: (payload) => _refreshAllData(),
    )..subscribe();
  }

// Future<void> loadDashboardData() async {
//     setState(() => isLoading = true);
//     try {
//       final sDate = DateFormat('yyyy-MM-dd').format(startDate);
//       final eDate = isRangeMode ? DateFormat('yyyy-MM-dd').format(endDate) : sDate;
//       final lokasiFilter = selectedLokasi == 'Semua Lokasi' ? ['Rungkut', 'Tambak Langon'] : [selectedLokasi];

//       // Panggil RPC yang sudah diperbaiki (Pastikan RPC mengembalikan kolom 'shift')
//       final response = await supabase.rpc('get_dashboard_checker_stats_v3', params: {
//         'p_start_date': sDate,
//         'p_end_date': eDate,
//         'p_lokasi': lokasiFilter,
//       });

//       if (response == null || (response as List).isEmpty) {
//         setState(() { tableData = []; grandTotalData = []; });
//         return;
//       }

//       // 1. Map data mentah dari DB
//       List<InDashboardItem> rawData = (response as List).map((item) {
//         return InDashboardItem(
//           name: item['checker_name'] ?? 'Belum diisi *',
//           shift: item['shift']?.toString() ?? '*', // Ambil data shift
//           truck: int.parse(item['truck_count'].toString()),
//           box: int.parse(item['total_qty'].toString()),
//           countA: int.parse(item['cat_a'].toString()),
//           countB: int.parse(item['cat_b'].toString()),
//           countC: int.parse(item['cat_c'].toString()),
//           countD: int.parse(item['cat_d'].toString()),
//         );
//       }).toList();

//       // 2. LOGIKA GROUPING & SUBTOTAL PER SHIFT
//       List<InDashboardItem> groupedList = [];
//       int gTruck = 0, gBox = 0, gA = 0, gB = 0, gC = 0, gD = 0;

//       // Ambil shift unik dan urutkan
//       var shifts = rawData.map((e) => e.shift).toSet().toList();
//       shifts.sort();

//       for (var s in shifts) {
//         var itemsInShift = rawData.where((e) => e.shift == s).toList();
//         int sTruck = 0, sBox = 0, sA = 0, sB = 0, sC = 0, sD = 0;

//         for (var item in itemsInShift) {
//           groupedList.add(item);
//           sTruck += item.truck; sBox += item.box;
//           sA += item.countA; sB += item.countB; sC += item.countC; sD += item.countD;
//         }

//         // Tambahkan baris SUBTOTAL setelah setiap grup shift
//         groupedList.add(InDashboardItem(
//           name: "SUBTOTAL SHIFT $s",
//           shift: s,
//           truck: sTruck, box: sBox,
//           countA: sA, countB: sB, countC: sC, countD: sD,
//           isSubtotal: true,
//         ));

//         // Akumulasi untuk GRAND TOTAL
//         gTruck += sTruck; gBox += sBox;
//         gA += sA; gB += sB; gC += sC; gD += sD;
//       }

//       setState(() {
//         tableData = groupedList;
//         grandTotalData = [
//           InDashboardItem(
//             name: "GRAND TOTAL",
//             shift: "",
//             truck: gTruck, box: gBox,
//             countA: gA, countB: gB, countC: gC, countD: gD,
//             isSubtotal: true,
//           )
//         ];
//       });
//     } catch (e) {
//       debugPrint("Error Dashboard: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
Future<void> loadDashboardData() async {
  setState(() => isLoading = true);
  try {
    final sDate = DateFormat('yyyy-MM-dd').format(startDate);
    final eDate = isRangeMode ? DateFormat('yyyy-MM-dd').format(endDate) : sDate;
    final lokasiFilter = [selectedLokasi];

    final response = await supabase.rpc('get_dashboard_checker_stats_v4', params: {
      'p_start_date': sDate,
      'p_end_date': eDate,
      'p_lokasi': lokasiFilter,
    });

    if (response == null || (response as List).isEmpty) {
      setState(() { tableData = []; grandTotalData = []; });
      return;
    }

    List<InDashboardItem> rawData = (response).map((item) {
      return InDashboardItem(
        name: item['checker_name'] ?? 'N/A',
        shift: item['shift']?.toString() ?? '*', 
        truck: int.parse(item['truck_count'].toString()),
        box: int.parse(item['total_qty'].toString()),
        countA: int.parse(item['cat_a'].toString()),
        countB: int.parse(item['cat_b'].toString()),
        countC: int.parse(item['cat_c'].toString()),
        countD: int.parse(item['cat_d'].toString()),
      );
    }).toList();

    // 2. PROSES GROUPING & PERHITUNGAN SUBTOTAL
    List<InDashboardItem> processedList = [];
    int gTruck = 0, gBox = 0, gA = 0, gB = 0, gC = 0, gD = 0;

    // Ambil semua daftar shift unik (misal: ['A', 'B'])
    var availableShifts = rawData.map((e) => e.shift).toSet().toList();
    availableShifts.sort(); // Urutkan A ke Z

    for (var shiftLabel in availableShifts) {
      // Ambil checker yang hanya di shift ini
      var checkersInShift = rawData.where((e) => e.shift == shiftLabel).toList();
      
      // Inisialisasi variabel penampung Subtotal untuk shift ini
      int subTruck = 0, subBox = 0, subA = 0, subB = 0, subC = 0, subD = 0;

      for (var checker in checkersInShift) {
        processedList.add(checker); // Tambahkan baris checker ke tabel
        
        // Akumulasi angka ke Subtotal Shift
        subTruck += checker.truck;
        subBox += checker.box;
        subA += checker.countA;
        subB += checker.countB;
        subC += checker.countC;
        subD += checker.countD;
      }

      // 3. Tambahkan baris SUBTOTAL setelah loop checker di shift ini selesai
      processedList.add(InDashboardItem(
        name: "SUBTOTAL SHIFT $shiftLabel",
        shift: shiftLabel,
        truck: subTruck, 
        box: subBox,
        countA: subA, 
        countB: subB, 
        countC: subC, 
        countD: subD,
        isSubtotal: true,
      ));

      // Akumulasi subtotal shift ke Grand Total
      gTruck += subTruck; gBox += subBox;
      gA += subA; gB += subB; gC += subC; gD += subD;
    }

    setState(() {
      tableData = processedList;
      grandTotalData = [
        InDashboardItem(
          name: "GRAND TOTAL",
          shift: "",
          truck: gTruck, box: gBox,
          countA: gA, countB: gB, countC: gC, countD: gD,
          isSubtotal: true,
        )
      ];
    });
  } catch (e) {
    debugPrint("Error Grouping: $e");
  } finally {
    setState(() => isLoading = false);
  }
}
// Future<void> loadDashboardData() async {
//   setState(() => isLoading = true);
//   try {
//     final sDate = DateFormat('yyyy-MM-dd').format(startDate);
//     final eDate = isRangeMode ? DateFormat('yyyy-MM-dd').format(endDate) : sDate;
    
//     // Pastikan lokasi dikirim sebagai List of String
//     final List<String> lokasiFilter = [selectedLokasi];

//     // Gunakan nama RPC terbaru (v3)
//     final response = await supabase.rpc('get_dashboard_checker_stats_v3', params: {
//       'p_start_date': sDate,
//       'p_end_date': eDate,
//       'p_lokasi': lokasiFilter,
//     });

//     if (response == null || (response as List).isEmpty) {
//       debugPrint("Data kosong untuk tanggal $sDate s/d $eDate di lokasi $selectedLokasi");
//       setState(() {
//         tableData = [];
//         grandTotalData = [];
//       });
//     } else {
//       List<InDashboardItem> tempList = [];
//       int tTruck = 0, tBox = 0, tA = 0, tB = 0, tC = 0, tD = 0;

//       for (var item in (response as List)) {
//         var d = InDashboardItem(
//           name: item['checker_name'] ?? 'N/A',
//           truck: int.parse(item['truck_count'].toString()),
//           box: int.parse(item['total_qty'].toString()),
//           countA: int.parse(item['cat_a'].toString()),
//           countB: int.parse(item['cat_b'].toString()),
//           countC: int.parse(item['cat_c'].toString()),
//           countD: int.parse(item['cat_d'].toString()),
//         );
//         tempList.add(d);
//         tTruck += d.truck;
//         tBox += d.box;
//         tA += d.countA;
//         tB += d.countB;
//         tC += d.countC;
//         tD += d.countD;
//       }

//       setState(() {
//         tableData = tempList;
//         grandTotalData = [
//           InDashboardItem(
//             name: "GRAND TOTAL",
//             truck: tTruck,
//             box: tBox,
//             countA: tA,
//             countB: tB,
//             countC: tC,
//             countD: tD,
//           )
//         ];
//       });
//     }
//   } catch (e) {
//     debugPrint("Error Fetching Dashboard: $e");
//   } finally {
//     setState(() => isLoading = false);
//   }
// }

// Future<void> fetchWarehouseChartData() async {
//     final sDate = DateFormat('yyyy-MM-dd').format(startDate);
//     final eDate = isRangeMode ? DateFormat('yyyy-MM-dd').format(endDate) : sDate;

//     try {
//       final response = await supabase.rpc('get_checkin_density_by_warehouse_v2', params: {
//         'p_start': sDate,
//         'p_end': eDate,
//       });

//       if (response != null) {
//         final List<ChartData> updatedData = (response as List).map((item) {
//           return ChartData(
//             item['warehouse_name'],
//             (item['truck_count'] as int).toDouble(),
//             _getWarehouseColor((response as List).indexOf(item)),
//           );
//         }).toList();

//         setState(() {
//           barDataWarehouse = updatedData;
//         });
//       }
//     } catch (e) {
//       debugPrint("Error chart: $e");
//     }
//   }
// Future<void> fetchWarehouseChartData() async {
//   print("DEBUG: Menjalankan fetchWarehouseChartData...");
  
//   final sDate = DateFormat('yyyy-MM-dd').format(startDate);
//   final eDate = isRangeMode ? DateFormat('yyyy-MM-dd').format(endDate) : sDate;

//   try {
//     final response = await supabase.rpc('get_checkin_density_by_warehouse_v2', params: {
//       'p_start': sDate,
//       'p_end': eDate,
//     });

//     print("DEBUG: Respon dari Database = $response");

//     if (response != null && (response as List).isNotEmpty) {
//       final List<ChartData> updatedData = (response as List).map((item) {
//         // Pastikan nama kolom 'warehouse_name' dan 'count' sesuai dengan hasil di Supabase
//         return ChartData(
//           item['warehouse_name']?.toString() ?? 'N/A',
//           //double.tryParse(item['count'].toString()) ?? 0.0,
//           double.tryParse(item['truck_count'].toString()) ?? 0.0,
//           _getWarehouseColor((response as List).indexOf(item)),
//         );
//       }).toList();

//       setState(() {
//         barDataWarehouse = updatedData;
//       });
//       print("DEBUG: barDataWarehouse berhasil diupdate. Jumlah item: ${barDataWarehouse.length}");
//     } else {
//       print("DEBUG: Respon kosong atau null.");
//       setState(() {
//         barDataWarehouse = [];
//       });
//     }
//   } catch (e) {
//     print("DEBUG ERROR: Terjadi kesalahan saat fetch chart: $e");
//   }
// }
Future<void> fetchDivisionChartData() async {
  final sDate = DateFormat('yyyy-MM-dd').format(startDate);
  final eDate = isRangeMode ? DateFormat('yyyy-MM-dd').format(endDate) : sDate;

  try {
    final response = await supabase.rpc('get_outbound_by_division_v2', params: {
      'p_start': sDate,
      'p_end': eDate,
      'p_lokasi': [selectedLokasi],
    });

    if (response != null) {
      setState(() {
        barDataDivisi = (response as List).map((item) {
          return ChartData(
            item['division_name'] ?? 'Unknown',
            double.tryParse(item['truck_count'].toString()) ?? 0.0,
            Colors.blueAccent,
          );
        }).toList();
      });
    }
  } catch (e) {
    debugPrint("Error Division Chart: $e");
  }
}

// Widget _buildDivisionBarChart() {
//   if (barDataDivisi.isEmpty) return const Center(child: Text("No Data"));
  
//   double maxVal = barDataDivisi.map((e) => e.value).fold(0, (p, e) => e > p ? e : p);

//   return BarChart(
//     BarChartData(
//       alignment: BarChartAlignment.spaceAround,
//       maxY: maxVal * 1.3,
//       barTouchData: BarTouchData(enabled: true),
//       titlesData: FlTitlesData(
//         show: true,
//         bottomTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 40,
//             getTitlesWidget: (v, m) {
//               if (v >= 0 && v < barDataDivisi.length) {
//                 return SideTitleWidget(
//                   axisSide: m.axisSide,
//                   child: Transform.rotate(
//                     angle: -0.4, // Miringkan sedikit agar tidak bertumpuk
//                     child: Text(barDataDivisi[v.toInt()].label, 
//                         style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
//                   ),
//                 );
//               }
//               return const SizedBox();
//             },
//           ),
//         ),
//         leftTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 30,
//             getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
//           ),
//         ),
//         topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//         rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//       ),
//       gridData: const FlGridData(show: false),
//       borderData: FlBorderData(show: false),
//       barGroups: barDataDivisi.asMap().entries.map((e) {
//         return BarChartGroupData(
//           x: e.key,
//           barRods: [
//             BarChartRodData(
//               toY: e.value.value,
//               color: Colors.blueAccent,
//               width: 25,
//               borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
//             )
//           ],
//           showingTooltipIndicators: [0],
//         );
//       }).toList(),
//     ),
//   );
// }
Widget _buildDivisionBarChart() {
  if (barDataDivisi.isEmpty) return const SizedBox(height: 250, child: Center(child: Text("No Data")));
  
  double maxVal = barDataDivisi.map((e) => e.value).fold(0, (p, e) => e > p ? e : p);
  // Jika maxVal adalah 6, kita batasi maxY menjadi 7 atau 8 agar ruang atas tidak terlalu kosong
  double computedMaxY =maxVal + (maxVal * 0.2);

  return SizedBox(
    height: 250, 
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: computedMaxY,
        minY: 0,
        // PERBAIKAN TOOLTIP: Rapatkan margin dan matikan padding bawaan agar pas di atas batang
        barTouchData: BarTouchData(
          enabled: false, // Set false jika ingin tooltip selalu muncul di atas tanpa disentuh
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 8, // Jarak super rapat antara ujung batang dan angka tooltip
            tooltipBgColor: Colors.transparent, // Menghilangkan kotak abu-abu tebal jika dirasa mengganggu
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.round().toString(),
                const TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87, 
                  fontSize: 12
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (v, m) {
                int index = v.toInt();
                if (index >= 0 && index < barDataDivisi.length) {
                  return SideTitleWidget(
                    axisSide: m.axisSide,
                    child: Transform.rotate(
                      angle: -0.3, // Kemiringan teks label bawah
                      child: Text(
                        barDataDivisi[index].label, 
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: maxVal > 50 ? 10 : (maxVal > 20 ? 5 : 2), // Memaksa angka sumbu Y naik tepat 1 per 1 (0, 1, 2... tidak ada angka kembar)
              getTitlesWidget: (v, m) {
                // Jangan tampilkan angka sumbu Y yang melebihi batas nilai maksimum data + 1
                //if (v > maxVal + 1) return const SizedBox();
                return Text(v.toInt().toString(), style: const TextStyle(fontSize: 9, color: Colors.grey));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        //gridData: const FlGridData(show: false),
gridData: FlGridData(
          show: true, 
          drawVerticalLine: false,
          horizontalInterval: maxVal > 50 ? 10 : (maxVal > 20 ? 5 : 2),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barDataDivisi.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: const Color(0xFF536DFE), // Warna biru solid seperti di gambar Anda
                width: 32,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
            showingTooltipIndicators: [0], // Menjaga angka tetap muncul di atas batang
          );
        }).toList(),
      ),
    ),
  );
}
Future<void> fetchWarehouseChartData() async {
    final sDate = DateFormat('yyyy-MM-dd').format(startDate);
    final eDate = isRangeMode ? DateFormat('yyyy-MM-dd').format(endDate) : sDate;

    try {
      final response = await supabase.rpc('get_checkin_density_by_warehouse_v3', params: {
        'p_start': sDate,
        'p_end': eDate,
      });

      if (response != null && (response as List).isNotEmpty) {
        barDataWarehouse = (response).map((item) {
          return ChartData(
            item['warehouse_name']?.toString() ?? 'N/A',
            double.tryParse(item['count'].toString()) ?? 0.0,
            _getWarehouseColor((response).indexOf(item)),
          );
        }).toList();
      } else {
        barDataWarehouse = [];
      }
    } catch (e) {
      debugPrint("Error Chart: $e");
    }
  }
// Widget _buildHorizontalBarChart() {
//     if (barDataWarehouse.isEmpty) return const Center(child: Text("No Data"));
//     double maxVal = barDataWarehouse.map((e) => e.value).fold(0, (prev, e) => e > prev ? e : prev);

//     return BarChart(
//       BarChartData(
//         alignment: BarChartAlignment.center,
//         maxY: maxVal * 1.2,
//         barTouchData: BarTouchData(enabled: true),
//         titlesData: FlTitlesData(
//           show: true,
//           leftTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               reservedSize: 120,
//               getTitlesWidget: (value, meta) {
//                 if (value.toInt() >= 0 && value.toInt() < barDataWarehouse.length) {
//                   return Text(barDataWarehouse[value.toInt()].label, style: const TextStyle(fontSize: 10));
//                 }
//                 return const SizedBox();
//               },
//             ),
//           ),
//           bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
//           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//         ),
//         gridData: const FlGridData(show: false),
//         borderData: FlBorderData(show: false),
//         barGroups: barDataWarehouse.asMap().entries.map((e) {
//           return BarChartGroupData(
//             x: e.key,
//             barRods: [
//               BarChartRodData(
//                 toY: e.value.value,
//                 color: e.value.color,
//                 width: 18,
//                 borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
//               )
//             ],
//             showingTooltipIndicators: [0],
//           );
//         }).toList(),
//       ),
//     );
//   }

// Widget _buildHorizontalBarChart() {
//   if (barDataWarehouse.isEmpty) return const Center(child: Text("No Data In List"));

//   // Hitung Max Value secara dinamis
//   double maxVal = barDataWarehouse.map((e) => e.value).fold(0, (prev, e) => e > prev ? e : prev);
//   if (maxVal == 0) maxVal = 10; // Hindari pembagian nol atau chart datar

//   return BarChart(
//     BarChartData(
//       alignment: BarChartAlignment.center,
//       maxY: maxVal * 1.5, // Beri ruang di ujung batang untuk label
//       barTouchData: BarTouchData(enabled: true),
//       titlesData: FlTitlesData(
//         show: true,
//         leftTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 120, // PASTIKAN UKURAN INI CUKUP UNTUK NAMA GUDANG
//             getTitlesWidget: (value, meta) {
//               int index = value.toInt();
//               if (index >= 0 && index < barDataWarehouse.length) {
//                 return Text(
//                   barDataWarehouse[index].label,
//                   style: const TextStyle(fontSize: 9),
//                   textAlign: TextAlign.right,
//                 );
//               }
//               return const SizedBox();
//             },
//           ),
//         ),
//         // Matikan title lain yang tidak perlu agar fokus
//         rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//         topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//         bottomTitles: const AxisTitles(
//           axisNameWidget: Text("Jumlah Truk", style: TextStyle(fontSize: 10)),
//           sideTitles: SideTitles(showTitles: true, reservedSize: 20),
//         ),
//       ),
//       gridData: const FlGridData(show: false),
//       borderData: FlBorderData(show: false),
//       barGroups: barDataWarehouse.asMap().entries.map((e) {
//         return BarChartGroupData(
//           x: e.key,
//           barRods: [
//             BarChartRodData(
//               toY: e.value.value, // Nilai jumlah truk
//               color: e.value.color,
//               width: 16,
//               borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
//             )
//           ],
//           showingTooltipIndicators: [0], // Munculkan angka di ujung batang
//         );
//       }).toList(),
//     ),
//   );
// }

// Widget _buildHorizontalBarChart() {
//   if (barDataWarehouse.isEmpty) return const Center(child: Text("No Data"));

//   // Ambil nilai truk tertinggi untuk menentukan batas sumbu X
//   double maxVal = barDataWarehouse.map((e) => e.value).fold(0, (prev, e) => e > prev ? e : prev);
//   if (maxVal < 5) maxVal = 5; // Batas minimal agar grafik tidak terlalu sempit

//   return BarChart(
//     BarChartData(
//       // Penting: alignment harus start agar batang mulai dari sisi kiri (nama gudang)
//       alignment: BarChartAlignment.start,
//       // Sumbu Y di fl_chart adalah sumbu horizontal jika dilihat secara logika data kita
//       maxY: maxVal * 1.2, 
//       minY: 0,
//       groupsSpace: 12, // Jarak antar batang gudang
//       barTouchData: BarTouchData(enabled: true),
//       titlesData: FlTitlesData(
//         show: true,
//         // Sumbu Kiri: Nama Gudang
//         leftTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 120, 
//             getTitlesWidget: (value, meta) {
//               int index = value.toInt();
//               if (index >= 0 && index < barDataWarehouse.length) {
//                 return SideTitleWidget(
//                   axisSide: meta.axisSide,
//                   child: Text(
//                     barDataWarehouse[index].label,
//                     style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
//                   ),
//                 );
//               }
//               return const SizedBox();
//             },
//           ),
//         ),
//         // Sumbu Bawah: Angka Jumlah Truk (0, 1, 2, dst)
//         bottomTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 30,
//             interval: 2, // Munculkan angka setiap kelipatan 2
//             getTitlesWidget: (value, meta) {
//               return SideTitleWidget(
//                 axisSide: meta.axisSide,
//                 child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
//               );
//             },
//           ),
//         ),
//         topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//         rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//       ),
//       gridData: FlGridData(
//         show: true,
//         drawVerticalLine: true, // Garis bantu berdiri untuk melihat angka bawah
//         drawHorizontalLine: false,
//         getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
//       ),
//       borderData: FlBorderData(show: false),
//       barGroups: barDataWarehouse.asMap().entries.map((e) {
//         return BarChartGroupData(
//           x: e.key,
//           barRods: [
//             BarChartRodData(
//               toY: e.value.value, // Ini adalah panjang batang ke kanan
//               color: e.value.color,
//               width: 20, // Tebal batang
//               borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
//             )
//           ],
//           showingTooltipIndicators: [0],
//         );
//       }).toList(),
//     ),
//   );
// }
Widget _buildHorizontalBarChart() {
  if (barDataWarehouse.isEmpty) return const Center(child: Text("Tidak ada data chart"));

  double totalTruk = barDataWarehouse.fold(0, (sum, item) => sum + item.value);

  return AspectRatio(
    aspectRatio: 1,
    child: Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 50, // Membuat lubang di tengah (Donut Style)
              sections: barDataWarehouse.map((e) {
                final double percentage = totalTruk > 0 ? (e.value / totalTruk * 100) : 0;
                return PieChartSectionData(
                  color: e.color,
                  value: e.value,
                  title: e.value > 0 ? '${percentage.toStringAsFixed(0)}%' : '',
                  radius: 22,
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend Komponen di bagian bawah chart
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: barDataWarehouse.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: e.color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 6),
                Text(
                  "${e.label} (${e.value.toInt()} Truk)",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    ),
  );
}
// Helper untuk memberi warna berbeda tiap gudang (opsional)
Color _getWarehouseColor(int index) {
  List<Color> colors = [Colors.blue, Colors.orange, Colors.green, Colors.red, Colors.purple];
  return colors[index % colors.length];
}
// Buat fungsi induk untuk refresh
// Future<void> _refreshAllData() async {
//   print("DEBUG: Memulai pengambilan data dashboard..."); // Tambahkan log manual
//   await loadDashboardData();       // Ambil data tabel
//   await fetchWarehouseChartData(); // Ambil data chart
//   print("DEBUG: Selesai mengambil semua data.");
// }
Future<void> _refreshAllData() async {
  // Tampilkan loading bar
  setState(() => isLoading = true);
  
  try {
    // Menjalankan semua RPC secara paralel agar lebih cepat
    await Future.wait([
      loadDashboardData(),        // Data Tabel
      fetchWarehouseChartData(),  // Data Donut Chart
      fetchDivisionChartData(),   // Data Bar Chart Divisi
    ]);
  } catch (e) {
    debugPrint("Error refresh data: $e");
  } finally {
    // Matikan loading bar
    if (mounted) setState(() => isLoading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text("Dashboard Performance Checker")),
      body: Column(
        children: [
          _buildTopFilter(),
          if (isLoading) const LinearProgressIndicator(),
        Expanded(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
       Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Sisi Kiri: Grafik (Dibuat agak ramping)
    Expanded(
      flex: 2, 
      child: _buildChartCard("Kepadatan Aktivitas", _buildHorizontalBarChart()),
    ),
    const SizedBox(width: 25),
    // Sisi Kanan: Tabel (Diberi ruang lebih besar)
    Expanded(
      flex: 3, 
      child: _buildPerformanceSection(), // Fungsi pembungkus tabel
    ),
    //const SizedBox(width: 10),

                // 3. SISI KANAN: GRAFIK DIVISI (Analisis Baru)
                Expanded(
                  flex: 2,
                  child: _buildChartCard(
                    "Analisis per Divisi", 
                    _buildDivisionBarChart(),
                  ),
                ),
  ],
),
      ],
      ),
    ),
  ),
        ],
      ),
    );
    
  }
Widget _buildPerformanceSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Performance Detail", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        // Gunakan SingleChildScrollView horizontal agar tabel aman jika terlalu lebar
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              _buildDataTable(tableData, isTotal: false),
              _buildDataTable(grandTotalData, isTotal: true),
            ],
          ),
        ),
      ),
    ],
  );
}

// Widget _buildCheckerBarChart() {
//   // Ambil hanya data checker asli (bukan subtotal/empty)
//   final checkerData = tableData.where((e) => !e.isSubtotal && e.name.isNotEmpty).toList();
  
//   if (checkerData.isEmpty) return const Center(child: Text("No Data"));

//   return BarChart(
//     BarChartData(
//       alignment: BarChartAlignment.spaceAround,
//       maxY: checkerData.map((e) => e.truck).reduce((a, b) => a > b ? a : b) * 1.2,
//       barGroups: checkerData.asMap().entries.map((e) {
//         return BarChartGroupData(
//           x: e.key,
//           barRods: [
//             BarChartRodData(
//               toY: e.key.toDouble(), // Jumlah Truk
//               color: Colors.blueAccent,
//               width: 16,
//               borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
//             )
//           ],
//         );
//       }).toList(),
//       titlesData: FlTitlesData(
//         bottomTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             getTitlesWidget: (v, m) => Padding(
//               padding: const EdgeInsets.only(top: 8),
//               child: Transform.rotate(
//                 angle: -0.5,
//                 child: Text(checkerData[v.toInt()].name.split(' ')[0], style: const TextStyle(fontSize: 9)),
//               ),
//             ),
//           ),
//         ),
//         leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
//         topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//         rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//       ),
//     ),
//   );
// }

// Widget _buildCategoryPieChart() {
//   if (grandTotalData.isEmpty) return const SizedBox();
//   var total = grandTotalData.first;

//   List<PieChartSectionData> sections = [
//     PieChartSectionData(value: total.countA.toDouble(), title: 'A', color: Colors.green, radius: 50),
//     PieChartSectionData(value: total.countB.toDouble(), title: 'B', color: Colors.blue, radius: 50),
//     PieChartSectionData(value: total.countC.toDouble(), title: 'C', color: Colors.orange, radius: 50),
//     PieChartSectionData(value: total.countD.toDouble(), title: 'D', color: Colors.red, radius: 50),
//   ];

//   return PieChart(
//     PieChartData(
//       sections: sections,
//       centerSpaceRadius: 40,
//       sectionsSpace: 2,
//     ),
//   );
// }

  // Widget _buildTopFilter() {
  //   return Card(
  //     elevation: 2,
  //     margin: const EdgeInsets.all(12),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12.0),
  //       child: Column(
  //         children: [
  //           Row(
  //             children: [
  //               const Text("Mode: ", style: TextStyle(fontWeight: FontWeight.bold)),
  //               const SizedBox(width: 8),
  //               DropdownButton<bool>(
  //                 value: isRangeMode,
                 
  //                 onChanged: (v) => setState(() { isRangeMode = v!; _refreshAllData(); }),
  //                 items: const [
  //                   DropdownMenuItem(value: false, child: Text("Harian")),
  //                   DropdownMenuItem(value: true, child: Text("Rentang Waktu")),
  //                 ],
  //               ),
  //               const Spacer(),
  //               const Text("Lokasi: ", style: TextStyle(fontWeight: FontWeight.bold)),
  //               const SizedBox(width: 8),
  //               DropdownButton<String>(
  //                 value: selectedLokasi,
  //                 items: lokasiOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
  //                 onChanged: (v) {
  //                   setState(() => selectedLokasi = v!);
  //                   _refreshAllData();
  //                 },
  //               ),
  //             ],
  //           ),
  //           const Divider(),
  //           Row(
  //             children: [
  //               const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
  //               const SizedBox(width: 8),
  //               InkWell(
  //                 onTap: () async {
  //                   if (isRangeMode) {
  //                     final p = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime(2030));
  //                     if (p != null) { setState(() { startDate = p.start; endDate = p.end; }); _refreshAllData();}
  //                   } else {
  //                     final p = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2023), lastDate: DateTime(2030));
  //                     if (p != null) { setState(() { startDate = p; }); _refreshAllData(); }
  //                   }
  //                 },
  //                 child: Text(
  //                   isRangeMode 
  //                   ? "${DateFormat('dd/MM/yy').format(startDate)} - ${DateFormat('dd/MM/yy').format(endDate)}"
  //                   : DateFormat('dd MMMM yyyy').format(startDate),
  //                   style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
  //                 ),
  //               ),
  //               const Spacer(),
  //               IconButton(
  //     onPressed: exportToExcel, 
  //     icon: const Icon(Icons.file_download, color: Colors.green),
  //     tooltip: "Eksport ke Excel",
  //   ),
  //               IconButton(onPressed: _refreshAllData, icon: const Icon(Icons.refresh, color: Colors.blue)),
  //             ],
  //           ),
            
  //         ],
  //       ),
  //     ),
  //   );
  // }

Widget _buildTopFilter() {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // 1. FILTER MODE
          const Text("Mode: ", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          DropdownButton<bool>(
            value: isRangeMode,
            underline: const SizedBox(), // Menghilangkan garis bawah agar lebih clean
            onChanged: (v) => setState(() {
              isRangeMode = v!;
              _refreshAllData();
            }),
            items: const [
              DropdownMenuItem(value: false, child: Text("Harian")),
              DropdownMenuItem(value: true, child: Text("Rentang")),
            ],
          ),

          const SizedBox(width: 12), // Jarak antar grup filter

          // 2. PILIH TANGGAL
          const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              if (isRangeMode) {
                // final p = await showDateRangePicker(
                //     context: context,
                //     firstDate: DateTime(2023),
                //     lastDate: DateTime(2030));
                final DateTimeRange? p = await showDialog<DateTimeRange>(
        context: context,
        builder: (BuildContext context) {
          return Center(
            child: SizedBox(
              width: 400, // Atur lebar pop-up agar pas
              height: 500, // Atur tinggi pop-up
              child: DateRangePickerDialog(
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
                initialDateRange: DateTimeRange(start: startDate, end: endDate),
              ),
            ),
          );
        },
      );
                if (p != null) {
                  setState(() {
                    startDate = p.start;
                    endDate = p.end;
                  });
                  _refreshAllData();
                }
              } else {
                final p = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030));
                if (p != null) {
                  setState(() {
                    startDate = p;
                  });
                  _refreshAllData();
                }
              }
            },
            child: Text(
              isRangeMode
                  ? "${DateFormat('dd/MM/yy').format(startDate)} - ${DateFormat('dd/MM/yy').format(endDate)}"
                  : DateFormat('dd MMMM yyyy').format(startDate),
              style: const TextStyle(
                  fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 75),

          // 3. LOKASI GUDANG
          const Text("Lokasi: ", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: selectedLokasi,
            underline: const SizedBox(),
            items: lokasiOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              setState(() => selectedLokasi = v!);
              _refreshAllData();
            },
          ),

          const Spacer(),

          // 4. BUTTON ACTIONS
          IconButton(
            onPressed: exportToExcel,
            icon: const Icon(Icons.file_download, color: Colors.green),
            tooltip: "Eksport ke Excel",
          ),
          IconButton(
            onPressed: _refreshAllData,
            icon: const Icon(Icons.refresh, color: Colors.blue),
            tooltip: "Refresh Data",
          ),
        ],
      ),
    ),
  );
}
  // Widget _buildChartsSection() {
  //   return LayoutBuilder(builder: (context, constraints) {
  //     bool isMobile = constraints.maxWidth < 800;
  //     return Wrap(
  //       spacing: 16, runSpacing: 16,
  //       children: [
  //         _buildChartCard("Outbound per Divisi", _buildBarChart(), width: isMobile ? constraints.maxWidth : constraints.maxWidth * 0.58),
  //         _buildChartCard("Distribusi Shift", _buildPieChart(), width: isMobile ? constraints.maxWidth : constraints.maxWidth * 0.38),
  //       ],
  //     );
  //   });
  // }

//   Widget _buildChartsSection() {
//     return LayoutBuilder(builder: (context, constraints) {
//       return Container(
//         height: 300,
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text("Kepadatan Aktivitas per Gudang", style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 20),
//             //Expanded(child: _buildHorizontalBarChart()),
//             Container(
//   height: (barDataWarehouse.length * 50.0) + 100, // Tinggi dinamis sesuai jumlah gudang
//   padding: const EdgeInsets.only(right: 20),
//   child: _buildHorizontalBarChart(),
// )
//           ],
//         ),
//       );
//     });
//   }

Widget _buildChartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 24),
          chart,
        ],
      ),
    );
  }

  // Widget _buildBarChart() {
  //   if (barDataDivisi.isEmpty) return const Center(child: Text("No Data"));
  //   double maxVal = barDataDivisi.map((e) => e.value).fold(0, (prev, e) => e > prev ? e : prev);
    
  //   return BarChart(
  //     BarChartData(
  //       alignment: BarChartAlignment.spaceAround,
  //       maxY: maxVal * 1.2,
  //       barGroups: barDataDivisi.asMap().entries.map((e) {
  //         return BarChartGroupData(x: e.key, barRods: [
  //           BarChartRodData(toY: e.value.value, color: Colors.blueAccent, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))
  //         ], showingTooltipIndicators: [0]);
  //       }).toList(),
  //       titlesData: FlTitlesData(
  //         bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 10), child: Transform.rotate(angle: -0.5, child: Text(barDataDivisi[v.toInt()].label, style: const TextStyle(fontSize: 9)))))),
  //         leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  //         topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  //         rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  //       ),
  //       // barTouchData: BarTouchData(
  //       //   enabled: false,
  //       //   touchTooltipData: BarTouchTooltipData(
  //       //     getTooltip: (_) => Colors.transparent,
  //       //     tooltipPadding: EdgeInsets.zero,
  //       //     tooltipMargin: 8,
  //       //     getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(rod.toY.round().toString(), const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11))
  //       //   )
  //       // ),
  //        barTouchData: BarTouchData(
  //         enabled: false,
  // touchTooltipData: BarTouchTooltipData(
  //   tooltipPadding: EdgeInsets.zero,
  //   tooltipMargin: 8,
  //   getTooltipItem: (group, groupIndex, rod, rodIndex) {
  //     return BarTooltipItem(
  //       rod.toY.round().toString(),
  //       const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11),
  //         //color: Colors.white,
  //       );
  //   }
  //     ),
  //        ),
  //       gridData: const FlGridData(show: false),
  //       borderData: FlBorderData(show: false),
  //     ),
  //   );
  // }

  // Widget _buildPieChart() {
  //   if (pieDataShift.isEmpty) return const Center(child: Text("No Data"));
  //   double total = pieDataShift.fold(0, (sum, item) => sum + item.value);

  //   return Column(
  //     children: [
  //       Expanded(
  //         child: PieChart(
  //           PieChartData(
  //             sectionsSpace: 4, centerSpaceRadius: 40,
  //             sections: pieDataShift.map((e) {
  //               final perc = (e.value / total * 100).toStringAsFixed(1);
  //               return PieChartSectionData(color: e.color, value: e.value, title: '$perc%', radius: 60, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white));
  //             }).toList(),
  //           ),
  //         ),
  //       ),
  //       Wrap(
  //         spacing: 10,
  //         children: pieDataShift.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: e.color), const SizedBox(width: 4), Text("${e.label}: ${e.value.round()}", style: const TextStyle(fontSize: 10))])).toList(),
  //       )
  //     ],
  //   );
  // }

  // Widget _buildDataTable(List<InDashboardItem> data, String title, {bool isTotal = false}) {
  //   final fmt = NumberFormat('#,###');
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       if (!isTotal) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
  //       SingleChildScrollView(
  //         scrollDirection: Axis.horizontal,
  //         child: DataTable(
  //           headingRowHeight: isTotal ? 0 : 45,
  //           dataRowHeight: 40,
  // //           headingRowColor: WidgetStateProperty.all(Colors.blueGrey[50]),
  // //           columns: const [
  // //             DataColumn(label: Text('Checker')), DataColumn(label: Text('Truk')), DataColumn(label: Text('Qty')),
  // //             DataColumn(label: Text('Cat A')), DataColumn(label: Text('Cat B')), DataColumn(label: Text('Cat C')), DataColumn(label: Text('Cat D')),
  // //           ],
  // //           rows: data.map((item) => DataRow(
  // //             color: isTotal ? WidgetStateProperty.all(Colors.blueGrey[100]) : null,
  // //             cells: [
  // //               DataCell(Text(item.name, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal))),
  // //               DataCell(Text(item.truck.toString())), DataCell(Text(fmt.format(item.box))),
  // //               DataCell(Text(item.countA.toString())), DataCell(Text(item.countB.toString())),
  // //               DataCell(Text(item.countC.toString())), DataCell(Text(item.countD.toString())),
  // //             ],
  // //           )).toList(),
  // //         ),
  // //       ),
  // //     ],
  // //   );
  // // }
  // columnSpacing: 25,
  //           headingRowColor: WidgetStateProperty.all(Colors.blueGrey[50]),
  //           columns: const [
  //             DataColumn(label: Text('Nama Checker')),
  //             DataColumn(label: Text('Total Truk')),
  //             DataColumn(label: Text('Total Box')),
  //             DataColumn(label: Text('A')),
  //             DataColumn(label: Text('B')),
  //             DataColumn(label: Text('C')),
  //             DataColumn(label: Text('D')),
  //           ],
  //           rows: data.map((item) {
  //             // Styling khusus baris Subtotal & Grand Total
  //             final bool highlight = item.isSubtotal || isTotal;
  //             final TextStyle style = TextStyle(
  //               fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
  //               color: isTotal ? Colors.blue[900] : Colors.black,
  //             );

  //             return DataRow(
  //               color: item.isSubtotal 
  //                 ? WidgetStateProperty.all(Colors.blueGrey[50]) 
  //                 : (isTotal ? WidgetStateProperty.all(Colors.blue[50]) : null),
  //               cells: [
  //                 DataCell(Text(item.name, style: style)),
  //                 DataCell(Text(item.truck.toString(), style: style)),
  //                 DataCell(Text(fmt.format(item.box), style: style)),
  //                 DataCell(Text(item.countA.toString(), style: style)),
  //                 DataCell(Text(item.countB.toString(), style: style)),
  //                 DataCell(Text(item.countC.toString(), style: style)),
  //                 DataCell(Text(item.countD.toString(), style: style)),
  //               ],
  //             );
  //           }).toList(),
  //         ),
  //       ),
  //     ],
  //   );
  // }
  Widget _buildDataTable(List<InDashboardItem> data, {required bool isTotal}) {
  final fmt = NumberFormat('#,###');
  
  return DataTable(
    // Besarkan spasi antar kolom agar tabel melebar ke samping
    columnSpacing: 35, 
    headingRowHeight: isTotal ? 0 : 48, 
   dataRowMinHeight: 45,
    dataRowMaxHeight: 45,
    horizontalMargin: 20,
    headingRowColor: WidgetStateProperty.all(Colors.blueGrey[50]),
    columns: const [
      DataColumn(label: Text('Checker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      DataColumn(label: Text('Truk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      DataColumn(label: Text('A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      DataColumn(label: Text('B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      DataColumn(label: Text('C', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      DataColumn(label: Text('D', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
    ],
    rows: data.map((item) {
      final bool highlight = item.isSubtotal || isTotal;
      return DataRow(
        color: highlight ? WidgetStateProperty.all(isTotal ? Colors.blueGrey[100] : Colors.grey[100]) : null,
        cells: [
          DataCell(SizedBox(
            width: 180, // Besarkan lebar kolom nama
            child: Text(item.name, 
              style: TextStyle(fontSize: 12, fontWeight: highlight ? FontWeight.bold : FontWeight.normal))
          )),
          DataCell(Text(item.truck.toString(), style: const TextStyle(fontSize: 12))),
          DataCell(Text(fmt.format(item.box), style: const TextStyle(fontSize: 12))),
          DataCell(Text(item.countA.toString(), style: const TextStyle(fontSize: 12))),
          DataCell(Text(item.countB.toString(), style: const TextStyle(fontSize: 12))),
          DataCell(Text(item.countC.toString(), style: const TextStyle(fontSize: 12))),
          DataCell(Text(item.countD.toString(), style: const TextStyle(fontSize: 12))),
        ],
      );
    }).toList(),
  );
}

// Future<void> exportToExcel() async {
//   if (tableData.isEmpty) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Data kosong, tidak ada yang bisa diekspor")),
//     );
//     return;
//   }
//   setState(() => isLoading = true);

//   try {
//     var excel = Excel.createExcel();
//     Sheet sheetObject = excel['Performance_Checker'];
//     excel.delete('Sheet1'); // Hapus sheet default

//     // 1. Definisikan Style Header
//     CellStyle headerStyle = CellStyle(
//       bold: true,
//       italic: false,
//       fontFamily: getFontFamily(FontFamily.Calibri), // Abu-abu terang
//       horizontalAlign: HorizontalAlign.Center,
//     );

//     // 2. Buat Header
//     List<String> headers = ['Nama Checker', 'Truk', 'Qty', 'Kategori A', 'Kategori B', 'Kategori C', 'Kategori D'];
//     for (var i = 0; i < headers.length; i++) {
//       var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
//       cell.value = TextCellValue(headers[i]);
//       cell.cellStyle = headerStyle;
//     }

//     // 3. Masukkan Data dari tableData
//     int currentRow = 1;
//     for (var item in tableData) {
//       List<CellValue> rowData = [
//         TextCellValue(item.name),
//         IntCellValue(item.truck),
//         IntCellValue(item.box),
//         IntCellValue(item.countA),
//         IntCellValue(item.countB),
//         IntCellValue(item.countC),
//         IntCellValue(item.countD),
//       ];
      
//       sheetObject.appendRow(rowData);

//       // Jika ini adalah baris subtotal, beri warna atau bold
//       if (item.isSubtotal) {
//         for (var col = 0; col < headers.length; col++) {
//           sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow))
//             .cellStyle = CellStyle(bold: true);
//         }
//       }
//       currentRow++;
//     }

//     // 4. Masukkan Grand Total
//     if (grandTotalData.isNotEmpty) {
//       var gt = grandTotalData.first;
//       sheetObject.appendRow([
//         TextCellValue("GRAND TOTAL"),
//         IntCellValue(gt.truck),
//         IntCellValue(gt.box),
//         IntCellValue(gt.countA),
//         IntCellValue(gt.countB),
//         IntCellValue(gt.countC),
//         IntCellValue(gt.countD),
//       ]);
      
//       for (var col = 0; col < headers.length; col++) {
//           sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow))
//             .cellStyle = CellStyle(bold: true); // Biru muda
//       }
//     }

//     // 5. Simpan File (Logic untuk Web & Mobile)
//     var fileBytes = excel.save();
//     String fileName = "Performance_Report_${DateFormat('yyyyMMdd').format(startDate)}";

//     await FileSaver.instance.saveFile(
//       name: fileName,
//       bytes: fileBytes != null ? Uint8List.fromList(fileBytes) : Uint8List(0),
//       ext: 'xlsx',
//       mimeType: MimeType.microsoftExcel,
//     );

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Data berhasil diekspor ke Excel")),
//     );
//   } catch (e) {
//     debugPrint("Export Error: $e");
//   } finally {
//     setState(() => isLoading = false);
//   }
// }
Future<void> exportToExcel() async {
  // 1. Cegah eksekusi ganda jika tombol diklik sangat cepat
  if (isLoading) return;

  if (tableData.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Data kosong, tidak ada yang bisa diekspor")),
    );
    return;
  }

  setState(() => isLoading = true);

  try {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Performance_Checker'];
    excel.delete('Sheet1');

    CellStyle headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    List<String> headers = ['Nama Checker', 'Truk', 'Qty', 'Kategori A', 'Kategori B', 'Kategori C', 'Kategori D'];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    int currentRow = 1;
    for (var item in tableData) {
      sheetObject.appendRow([
        TextCellValue(item.name),
        IntCellValue(item.truck),
        IntCellValue(item.box),
        IntCellValue(item.countA),
        IntCellValue(item.countB),
        IntCellValue(item.countC),
        IntCellValue(item.countD),
      ]);

      if (item.isSubtotal) {
        for (var col = 0; col < headers.length; col++) {
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow))
            .cellStyle = CellStyle(bold: true);
        }
      }
      currentRow++;
    }

    if (grandTotalData.isNotEmpty) {
      var gt = grandTotalData.first;
      sheetObject.appendRow([
        TextCellValue("GRAND TOTAL"),
        IntCellValue(gt.truck),
        IntCellValue(gt.box),
        IntCellValue(gt.countA),
        IntCellValue(gt.countB),
        IntCellValue(gt.countC),
        IntCellValue(gt.countD),
      ]);
      
      for (var col = 0; col < headers.length; col++) {
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow))
            .cellStyle = CellStyle(bold: true);
      }
    }

    // --- SOLUSI DOWNLOAD GANDA ---
    // Gunakan excel.encode() untuk mengambil bytes tanpa memicu download otomatis dari library excel
    var fileBytes = excel.encode(); 
    
    if (fileBytes != null) {
      String fileName = "Performance_Report_${DateFormat('yyyyMMdd').format(startDate)}";

      // Eksekusi download HANYA melalui FileSaver
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data berhasil diekspor ke Excel"), backgroundColor: Colors.green),
      );
    }
  } catch (e) {
    debugPrint("Export Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
    );
  } finally {
    // Beri jeda sedikit sebelum tombol bisa diklik lagi
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => isLoading = false);
  }
}
}