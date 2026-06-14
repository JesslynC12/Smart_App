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

    var availableShifts = rawData.map((e) => e.shift).toSet().toList();
    availableShifts.sort(); // Urutkan A ke Z

    for (var shiftLabel in availableShifts) {
      var checkersInShift = rawData.where((e) => e.shift == shiftLabel).toList();
      
      int subTruck = 0, subBox = 0, subA = 0, subB = 0, subC = 0, subD = 0;

      for (var checker in checkersInShift) {
        processedList.add(checker); 
        
        subTruck += checker.truck;
        subBox += checker.box;
        subA += checker.countA;
        subB += checker.countB;
        subC += checker.countC;
        subD += checker.countD;
      }

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
Widget _buildDivisionBarChart() {
  if (barDataDivisi.isEmpty) return const SizedBox(height: 250, child: Center(child: Text("No Data")));
  
  double maxVal = barDataDivisi.map((e) => e.value).fold(0, (p, e) => e > p ? e : p);
  double computedMaxY =maxVal + (maxVal * 0.2);

  return SizedBox(
    height: 250, 
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: computedMaxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 8, 
            tooltipBgColor: Colors.transparent,
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
                      angle: -0.3, 
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
              interval: maxVal > 50 ? 10 : (maxVal > 20 ? 5 : 2),
              getTitlesWidget: (v, m) {
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
                color: const Color(0xFF536DFE), 
                width: 32,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
            showingTooltipIndicators: [0],
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
              centerSpaceRadius: 50,
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
Color _getWarehouseColor(int index) {
  List<Color> colors = [Colors.blue, Colors.orange, Colors.green, Colors.red, Colors.purple];
  return colors[index % colors.length];
}

Future<void> _refreshAllData() async {
  setState(() => isLoading = true);
  
  try {
    await Future.wait([
      loadDashboardData(),        
      fetchWarehouseChartData(),  
      fetchDivisionChartData(),   
    ]);
  } catch (e) {
    debugPrint("Error refresh data: $e");
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
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
    Expanded(
      flex: 2, 
      child: _buildChartCard("Kepadatan Aktivitas", _buildHorizontalBarChart()),
    ),
    const SizedBox(width: 25),
    Expanded(
      flex: 3, 
      child: _buildPerformanceSection(), 
    ),
    
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

Widget _buildTopFilter() {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Text("Mode: ", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          DropdownButton<bool>(
            value: isRangeMode,
            underline: const SizedBox(), 
            onChanged: (v) => setState(() {
              isRangeMode = v!;
              _refreshAllData();
            }),
            items: const [
              DropdownMenuItem(value: false, child: Text("Harian")),
              DropdownMenuItem(value: true, child: Text("Rentang")),
            ],
          ),

          const SizedBox(width: 12),
          const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              if (isRangeMode) {
              
                final DateTimeRange? p = await showDialog<DateTimeRange>(
        context: context,
        builder: (BuildContext context) {
          return Center(
            child: SizedBox(
              width: 400, 
              height: 500, 
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

  Widget _buildDataTable(List<InDashboardItem> data, {required bool isTotal}) {
  final fmt = NumberFormat('#,###');
  
  return DataTable(
    
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
            width: 180, 
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

Future<void> exportToExcel() async {
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
    var fileBytes = excel.encode(); 
    
    if (fileBytes != null) {
      String fileName = "Performance_Report_${DateFormat('yyyyMMdd').format(startDate)}";

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
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => isLoading = false);
  }
}
}