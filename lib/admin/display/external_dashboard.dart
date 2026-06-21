import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class OutboundDashboardPage extends StatefulWidget {
  const OutboundDashboardPage({Key? key}) : super(key: key);

  @override
  State<OutboundDashboardPage> createState() => _OutboundDashboardPageState();
}

class _OutboundDashboardPageState extends State<OutboundDashboardPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  String selectedLocationLabel = "Rungkut";
  List<int> selectedWarehouseIds = [1, 2, 3];

  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  int totalOutboundCount = 0;
  double totalTonnage = 0.0;
  double totalPallet = 0.0;

  int trendCount = 0;
  int trendTonnage = 0;
  int trendPallet = 0;

  List<BarChartGroupData> barGroups = [];
  List<PieChartSectionData> pieSections = [];
  List<Map<String, dynamic>> materialTableData = [];

  final List<String> romawiLabels = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
  ];

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    setState(() => isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final prevDateStr = DateFormat(
      'yyyy-MM-dd',
    ).format(selectedDate.subtract(const Duration(days: 1)));

    try {
      final responseToday =
          await supabase.rpc(
                'get_outbound_dashboard_data',
                params: {
                  'p_date': dateStr,
                  'p_warehouse_ids': selectedWarehouseIds,
                },
              )
              as List<dynamic>;

      final responsePrev =
          await supabase.rpc(
                'get_outbound_dashboard_data',
                params: {
                  'p_date': prevDateStr,
                  'p_warehouse_ids': selectedWarehouseIds,
                },
              )
              as List<dynamic>;
      debugPrint("raw data outboud hari ini: $responseToday");
      debugPrint("jumlah baris data outbound: ${responseToday.length}");
      debugPrint("filter tanggal kemaren(H-1): $prevDateStr");
      debugPrint("RAW DATA OUTBOUND KEMARIN: $responsePrev");
      List<dynamic> combinedSlots = [];
      for (int id in selectedWarehouseIds) {
        final res =
            await supabase.rpc(
                  'get_booked_slots',
                  params: {'target_date': dateStr, 'target_warehouse_id': id},
                )
                as List<dynamic>;
        debugPrint("DEBUG SLOT BOOKING UNTUK WAREHOUSE ID [$id]: $res");
        combinedSlots.addAll(res);
      }
      debugPrint("TOTAL GABUNGAN RAW DATA SLOTS (BAR CHART): $combinedSlots");
      debugPrint(
        "JUMLAH DATA SLOT YANG AKAN DI-LOOPING: ${combinedSlots.length}",
      );
      double todayTon = 0;
      double todayPallet = 0;
      Set<int> uniqueShipments = {};
      Map<String, Map<String, dynamic>> matSummary = {};

      for (var row in responseToday) {
        uniqueShipments.add(row['shipping_id']);
        double ton = (row['qty'] * row['net_weight']) / 1000.0;

        int bpp = row['box_per_pallet'] ?? 1;
        double pal = (row['qty'] as num) / (bpp == 0 ? 1 : bpp);

        todayTon += ton;
        todayPallet += pal;

        String matType = row['material_type'] ?? 'UNKNOWN';
        if (!matSummary.containsKey(matType)) {
          matSummary[matType] = {'ton': 0.0, 'pallet': 0.0, 'type': matType};
        }
        matSummary[matType]!['ton'] += ton;
        matSummary[matType]!['pallet'] += pal;
      }

      double prevTon = 0;
      double prevPallet = 0;
      Set<int> prevUniqueShipments = {};
      for (var row in responsePrev) {
        prevUniqueShipments.add(row['shipping_id']);
        int bpp = row['box_per_pallet'] ?? 1;
        prevTon += (row['qty'] * row['net_weight']) / 1000.0;
        prevPallet += (row['qty'] as num) / (bpp == 0 ? 1 : bpp);
      }

      Map<int, int> shiftCounts = {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
        6: 0,
        7: 0,
        8: 0,
      };
      for (var row in combinedSlots) {
        String slotTime = row['slot_time'] ?? '';
        int totalBooked = (row['total_booked'] as num?)?.toInt() ?? 0;

        int shiftIndex = mapJamBookingToShift(slotTime);
        if (shiftIndex != -1) {
          shiftCounts[shiftIndex] =
              (shiftCounts[shiftIndex] ?? 0) + totalBooked;
        }
      }

      setState(() {
        totalOutboundCount = uniqueShipments.length;
        totalTonnage = todayTon;
        totalPallet = todayPallet;

        trendCount = totalOutboundCount.compareTo(prevUniqueShipments.length);
        trendTonnage = totalTonnage.compareTo(prevTon);
        trendPallet = totalPallet.compareTo(prevPallet);

        barGroups = shiftCounts.entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.toDouble(),
                color: Colors.blueAccent,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList();
        int colorIdx = 0;
        final colors = [
          Colors.redAccent,
          Colors.orangeAccent,
          Colors.greenAccent,
          Colors.purpleAccent,
          Colors.teal,
        ];
        pieSections = matSummary.values.map((v) {
          final section = PieChartSectionData(
            value: v['ton'],
            title: "${v['type']}\n${(v['ton'] as double).toStringAsFixed(1)} T",
            color: colors[colorIdx % colors.length],
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
          colorIdx++;
          return section;
        }).toList();

        materialTableData = matSummary.values.toList();
      });
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  int mapJamBookingToShift(String? jamBooking) {
    if (jamBooking == null || jamBooking.isEmpty) return -1;
    try {
      int hour = int.parse(jamBooking.split(':')[0].trim());
      if (selectedLocationLabel == "Rungkut") {
        if (hour >= 7 && hour < 9) return 1;
        if (hour >= 9 && hour < 11) return 2;
        if (hour >= 11 && hour < 13) return 3;
        if (hour >= 13 && hour < 15) return 4;
        if (hour >= 15 && hour < 17) return 5;
        if (hour >= 17 && hour < 19) return 6;
        if (hour >= 19 && hour < 21) return 7;
        if (hour >= 21 && hour < 23) return 8;
      } else {
        if (hour >= 8 && hour < 10) return 1;
        if (hour >= 10 && hour < 12) return 2;
        if (hour >= 12 && hour < 14) return 3;
        if (hour >= 14 && hour < 16) return 4;
        if (hour >= 16 && hour < 18) return 5;
        if (hour >= 18 && hour < 20) return 6;
        if (hour >= 20 && hour < 22) return 7;
        if (hour >= 22 && hour <= 24) return 8;
      }
    } catch (_) {}
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(),
                  const SizedBox(height: 20),
                  _buildMetricsGrid(),
                  const SizedBox(height: 24),
                  _buildChartsLayout(),
                  const SizedBox(height: 24),
                  _buildMaterialTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            DropdownButton<String>(
              value: selectedLocationLabel,
              underline: const SizedBox(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 16,
              ),
              items: const [
                DropdownMenuItem(
                  value: "Rungkut",
                  child: Text("Gudang Rungkut"),
                ),
                DropdownMenuItem(
                  value: "Tambak Langon",
                  child: Text("Gudang Tambak Langon"),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedLocationLabel = val;
                    selectedWarehouseIds = (val == "Rungkut") ? [1, 2, 3] : [6];
                  });
                  fetchDashboardData();
                }
              },
            ),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                  fetchDashboardData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth =
            (constraints.maxWidth - 32) / (constraints.maxWidth > 800 ? 3 : 1);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildMetricCard(
              "Total Outbound Count (Ritase)",
              totalOutboundCount.toString(),
              trendCount,
              cardWidth,
            ),
            _buildMetricCard(
              "Total Tonnage",
              "${totalTonnage.toStringAsFixed(3)} Tons",
              trendTonnage,
              cardWidth,
            ),
            _buildMetricCard(
              "Total Pallet",
              totalPallet.toStringAsFixed(2),
              trendPallet,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, int trend, double width) {
    Color trendColor = trend > 0
        ? Colors.green
        : (trend < 0 ? Colors.red : Colors.grey);
    IconData trendIcon = trend > 0
        ? Icons.arrow_upward
        : (trend < 0 ? Icons.arrow_downward : Icons.remove);

    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: RepublicStyle.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(trendIcon, color: trendColor, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsLayout() {
    bool isWideScreen = MediaQuery.of(context).size.width > 900;
    if (isWideScreen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _buildBarChartCard()),
          const SizedBox(width: 16),
          Expanded(flex: 1, child: _buildPieChartCard()),
        ],
      );
    }
    return Column(
      children: [
        _buildBarChartCard(),
        const SizedBox(height: 16),
        _buildPieChartCard(),
      ],
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: RepublicStyle.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Peak Hours - Ritase Ter-booking Per Shift",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: barGroups.isEmpty
                ? const Center(child: Text("Tidak ada data booking slot"))
                : BarChart(
                    BarChartData(
                      barGroups: barGroups,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            getTitlesWidget: (val, meta) {
                              int idx = val.toInt() - 1;
                              if (idx >= 0 && idx < romawiLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    romawiLabels[idx], 
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard() {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: RepublicStyle.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Komposisi Tipe Material",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: pieSections.isEmpty
                ? const Center(child: Text("Tidak ada data pengiriman"))
                : PieChart(
                    PieChartData(
                      sections: pieSections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialTable() {
    return Container(
      width: double.infinity,
      decoration: RepublicStyle.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Summary Kategori Material (Keluar)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          materialTableData.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Text("Tidak ada data material untuk ditampilkan"),
                  ),
                )
              : DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8FAFC),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Tipe Material',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tonase (T)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Kapasitas Pallet',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: materialTableData.map((data) {
                    return DataRow(
                      cells: [
                        DataCell(Text(data['type'].toString())),
                        DataCell(
                          Text((data['ton'] as double).toStringAsFixed(3)),
                        ),
                        DataCell(
                          Text((data['pallet'] as double).toStringAsFixed(2)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

class RepublicStyle {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
