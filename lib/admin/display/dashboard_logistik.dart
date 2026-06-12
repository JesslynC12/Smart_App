import 'dart:io' as io;

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:universal_html/html.dart' as html;

class LogisticDashboardPage extends StatefulWidget {
  const LogisticDashboardPage({super.key});

  @override
  State<LogisticDashboardPage> createState() => _LogisticDashboardPageState();
}

class _LogisticDashboardPageState extends State<LogisticDashboardPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  
  DateTimeRange? _selectedDateRange;
  //DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();

 @override
  void initState() {
    super.initState();
    // Inisialisasi range tanggal default (misal: hari ini)
    _selectedDateRange = DateTimeRange(
      start: DateTime.now(),
      end: DateTime.now(),
    );
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      if (_allRequests.isEmpty) {
        setState(() => _isLoading = true);
      }

      // Query multi-relation sesuai DDL Table terbaru Anda
      final response = await supabase
          .from('shipping_request')
          .select('''
            *,
            group_id,
            warehouse (warehouse_id, warehouse_name),
            delivery_order (
              do_number,
              customer (customer_id, customer_name, city, area),
              do_details (
                details_id, 
                qty, 
                material (material_id, material_name, material_type, net_weight, division_description)
              )
            ),
            shipping_assignments!inner (
              id_assignment,
              jam_booking,
              "checkIn_at",
              keluar_at,
              no_polisi,
              sj_kembali,
              no_segel_pelayaran,
              
              vendor_transportasi:id_vendor_details (
                vendor_name,
                type_unit,
                winner_rank
              ),
              loading!inner (
    id_loading,
    verifikasi_rekomendasi_logistic,
    checker_id,
    checker (
      checker_id,
      checker_name,
      shift
    )
)
            )
          ''')
          //.filter('shipping_assignments.status_assignment', 'not.in', '(rejected,"rejected unit","no response","cancel booking")')
          .not('shipping_assignments.status_assignment', 'in', '("rejected","rejected unit","no response","cancel booking")',)
          .eq('shipping_assignments.loading.verifikasi_rekomendasi_logistic', 'OKE',)
         .order('shipping_id', ascending: false);
          

      List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
      
      if (mounted) {
        setState(() {
          _allRequests = data;
          _runFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch Dashboard: $e");
      setState(() => _isLoading = false);
    }
  }

  void _runFilter() {
    String query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredRequests = _allRequests.where((req) {
       // 1. Filter Date Range (Stuffing Date)
        bool matchDate = true;
        if (_selectedDateRange != null) {
          DateTime? stuffingDate = req['stuffing_date'] != null 
              ? DateTime.tryParse(req['stuffing_date'].toString()) 
              : null;
          if (stuffingDate != null) {
            final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
            final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
            final check = DateTime(stuffingDate.year, stuffingDate.month, stuffingDate.day);
            matchDate = (check.isAtSameMomentAs(start) || check.isAtSameMomentAs(end)) || 
                        (check.isAfter(start) && check.isBefore(end));
          } else {
            matchDate = false;
          }
        }

        // 2. Filter Search (No DO, SO, Customer, Material)
        bool matchSearch = false;
        if (query.isEmpty) {
          matchSearch = true;
        } else {
          final soNum = (req['so'] ?? "").toString().toLowerCase();
          final List dos = req['delivery_order'] ?? [];

          bool matchInDO = dos.any((doItem) {
            final doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
            final custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
            final custId = (doItem['customer']?['customer_id'] ?? "").toString().toLowerCase();
            final List details = doItem['do_details'] ?? [];

            bool matchMat = details.any((det) {
              final matName = (det['material']?['material_name'] ?? "").toString().toLowerCase();
              final matId = (det['material']?['material_id'] ?? "").toString().toLowerCase();
              return matName.contains(query) || matId.contains(query);
            });

            return doNum.contains(query) || custName.contains(query) || custId.contains(query) || matchMat;
          });

          matchSearch = soNum.contains(query) || matchInDO;
        }

        return matchDate && matchSearch;
      }).toList();
    });
  }

  // --- LOGIKA GROUPING DO & SINGLE DO SUPORT ---
  List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
    Map<int, Map<String, dynamic>> groupedMap = {};
    List<Map<String, dynamic>> finalResult = [];

    for (var req in source) {
      if (req['group_id'] == null) {
        finalResult.add(Map<String, dynamic>.from(req));
      } else {
        int gId = req['group_id'];
        if (!groupedMap.containsKey(gId)) {
          groupedMap[gId] = Map<String, dynamic>.from(req);
          groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
          groupedMap[gId]!['all_rdds'] = [req['rdd']];
        } else {
          groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
          
          List<String?> rdds = List<String?>.from(groupedMap[gId]!['all_rdds']);
          // if (!rdds.contains(req['rdd'])) {
          if (!rdds.contains(req['rdd'])) rdds.add(req['rdd']);
          //   rdds.add(req['rdd']);
          // }
          groupedMap[gId]!['all_rdds'] = rdds;
          
          List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
          List newDos = req['delivery_order'] ?? [];
          
          for (var ndo in newDos) {
            ndo['parent_so'] = req['so'];
            currentDos.add(ndo);
          }
          groupedMap[gId]!['delivery_order'] = currentDos;
        }
      }
    }
    
    finalResult.addAll(groupedMap.values);
    finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
    return finalResult;
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     // appBar: AppBar(
  //     //   title: const Text("Logistic Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  //     //   backgroundColor: Colors.blue.shade900,
  //     //   foregroundColor: Colors.white,
  //     // ),
  //     body: Column(
  //       children: [
  //         _buildFilterBar(),
  //         Expanded(
  //           child: _isLoading
  //               ? const Center(child: CircularProgressIndicator())
  //               : _buildTableArea(),
  //         ),
  //       ],
  //     ),
  //   );
  // }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                :
              _buildTableArea(),
          ),
        ],
      ),
    );
  }
  // Widget _buildFilterBar() {
  //   return Padding(
  //     padding: const EdgeInsets.all(12.0),
  //     child: Row(
  //       children: [
  //         // Filter Stuffing Date (Now Default)
  //         InkWell(
  //           onTap: () async {
  //             DateTime? picked = await showDatePicker(
  //               context: context,
  //               initialDate: _selectedDateR,
  //               firstDate: DateTime(2024),
  //               lastDate: DateTime(2030),
  //             );
  //             if (picked != null) {
  //               setState(() => _selectedDate = picked);
  //               _runFilter();
  //             }
  //           },
  //           child: Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //             decoration: BoxDecoration(
  //               color: Colors.blue.shade50,
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(color: Colors.blue.shade200)
  //             ),
  //             child: Row(
  //               children: [
  //                 Icon(Icons.calendar_month, size: 16, color: Colors.blue.shade900),
  //                 const SizedBox(width: 8),
  //                 Text(
  //                   DateFormat('dd/MM/yyyy').format(_selectedDate),
  //                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //         const SizedBox(width: 12),
  //         // Search Field
  //         Expanded(
  //           child: TextField(
  //             controller: _searchController,
  //             onChanged: (_) => _runFilter(),
  //             decoration: InputDecoration(
  //               hintText: "Cari No DO, SO, Customer, Material...",
  //               prefixIcon: const Icon(Icons.search, size: 20),
  //               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  //               isDense: true,
  //               contentPadding: const EdgeInsets.symmetric(vertical: 10),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
// --- UI Filter & Export Bar ---
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
        
          // Search Field
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _runFilter(),
              decoration: InputDecoration(
                hintText: "Cari No DO, Customer...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
            // Date Range Picker Button
          InkWell(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDateRange == null 
                      ? "Pilih Tanggal" 
                      : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Export Button
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.file_download, color: Colors.green),
            tooltip: "Export Excel",
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(now.year + 100),
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
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 550,
              ),
              child: child!,
            ),
          ),
        );
      },
    );

   if (picked != null) {
      // 1. Set tanggal baru dan aktifkan loading secara instan 
      //    (Pop-up otomatis tertutup karena showDateRangePicker selesai beroperasi)
      setState(() {
        _selectedDateRange = picked;
        _isLoading = true; 
      });

      // 2. Berikan sedikit delay/jeda (misal 500ms) agar pop-up benar-benar menutup sempurna
      //    dan user bisa melihat animasi CircularProgressIndicator terlebih dahulu.
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Jalankan filter atau ambil data baru dari database
      // Jika Anda ingin mengambil data BARU dari Supabase berdasarkan range tanggal, 
      // gunakan panggilan ini:
      // await _fetchDashboardData(); 
      
      // Namun, jika Anda hanya ingin memfilter data lokal yang SUDAH ADA di HP:
      _runFilter();

      // 4. Matikan loading setelah data selesai diproses
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  Widget _buildTableArea() {
    final displayData = _getGroupedDisplayData(_filteredRequests);
    if (displayData.isEmpty) {
      return const Center(child: Text("Tidak ada data logistik hari ini"));
    }
//const double totalTableWidth = 2400.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              //width: totalTableWidth,
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
                    headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    columnSpacing: 12,
                    horizontalMargin: 10,
                    columns: _buildColumns(),
                    rows: const [], 
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 0,
                        dataRowMaxHeight: double.infinity,
                        dataRowMinHeight: 50,
                        columnSpacing: 12,
                        horizontalMargin: 10,
                        columns: _buildColumns(),
                        rows: displayData.map((req) => _buildDataRow(req)).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _buildColumns() {
    return const [
      DataColumn(label: SizedBox(width: 70, child: Text('Ship ID'))),
      DataColumn(label: SizedBox(width: 80, child: Text('Stuffing Date'))),
      DataColumn(label: SizedBox(width: 80, child: Text('RDD'))),
      DataColumn(label: SizedBox(width: 80, child: Text('No DO'))),
      DataColumn(label: SizedBox(width: 90, child: Text('SO Number'))),
      DataColumn(label: SizedBox(width: 80, child: Text('No Cust'))),
      DataColumn(label: SizedBox(width: 190, child: Text('Customer Tujuan'))),
      DataColumn(label: SizedBox(width: 110, child: Text('City'))),
    DataColumn(label: SizedBox(width: 120, child: Text('Area'))),
      DataColumn(label: SizedBox(width: 70, child: Text('No Mat'))),
      DataColumn(label: SizedBox(width: 218, child: Text('Nama Mat'))),
      DataColumn(label: SizedBox(width: 80, child: Text('Mat Type'))),
    DataColumn(label: SizedBox(width: 130, child: Text('Division Desc'))),
      DataColumn(label: SizedBox(width: 50, child: Text('Qty'))),
      DataColumn(label: SizedBox(width: 60, child: Text('NW'))),
      DataColumn(label: SizedBox(width: 30, child: Text('TNW'))),
      //DataColumn(label: SizedBox(width: 100, child: Text('Division'))),
      DataColumn(label: SizedBox(width: 155, child: Text('Lokasi Loading'))),
      DataColumn(label: SizedBox(width: 125, child: Text('Vendor Transportasi'))),
      DataColumn(label: SizedBox(width: 80, child: Text('Type Unit'))),
      DataColumn(label: SizedBox(width: 50, child: Text('Rank'))),
      DataColumn(label: SizedBox(width: 100, child: Text('Jam Booking'))),
      DataColumn(label: SizedBox(width: 70, child: Text('Check In'))),
      DataColumn(label: SizedBox(width: 60, child: Text('Keluar'))),
      //DataColumn(label: SizedBox(width: 70, child: Text('Lead Time'))),
      DataColumn(label: SizedBox(width: 90, child: Text('No Polisi'))),
      DataColumn(label: SizedBox(width: 130, child: Text('No Segel Pelayaran'))),
      DataColumn(label: SizedBox(width: 130, child: Text('Checker'))),
      DataColumn(label: SizedBox(width: 50, child: Text('Shift'))),
      DataColumn(label: SizedBox(width: 80, child: Text('SJ Kembali'))),
    ];
  }

  DataRow _buildDataRow(Map<String, dynamic> req) {
    final isGroupRow = req['group_id'] != null;
    final List<int> idsInRow = isGroupRow ? List<int>.from(req['grouped_ids']) : [req['shipping_id'] as int];
    final List dos = req['delivery_order'] ?? [];

    // Extract Data Assignment (Ambil assignment pertama dari list assignment jika ada)
    final List assignmentsList = req['shipping_assignments'] ?? [];
    Map<String, dynamic>? assignment = assignmentsList.isNotEmpty ? assignmentsList.first : null;

    // Extract Vendor Transportasi & Warehouse
    String warehouseName = req['warehouse']?['warehouse_name'] ?? "-";
    String vendorName = assignment?['vendor_transportasi']?['vendor_name'] ?? "-";
    String typeUnit = assignment?['vendor_transportasi']?['type_unit'] ?? "-";
    String winnerRank = (assignment?['vendor_transportasi']?['winner_rank'] ?? "-").toString();

    // Timings & Unit Info
    String jamBooking = assignment?['jam_booking'] ?? "-";
    String checkInAt = _formatDateTime(assignment?['checkIn_at']);
    String keluarAt = _formatDateTime(assignment?['keluar_at']);
    //String leadTimeStr = _calculateLeadTime(assignment?['checkIn_at'], assignment?['keluar_at']);
    String noPolisi = assignment?['no_polisi'] ?? "-";
    String sjKembali = _formatDateOnly(assignment?['sj_kembali']);
    String noSegelPelayaran = assignment?['no_segel_pelayaran'] ?? "-";

    // Extract Loading -> Checker & Shift
    final List loadingList = assignment?['loading'] ?? [];
    Map<String, dynamic>? loadingInfo = loadingList.isNotEmpty ? loadingList.first : null;
    String checkerName = loadingInfo?['checker']?['checker_name'] ?? "-";
    String shift = loadingInfo?['checker']?['shift'] ?? "-";

    List<Widget> doNumW = [], soW = [], custIdW = [], custW = [],cityW = [], areaW = [], matIdW = [], matW = [], matTypeW = [],divDescW = [], qtyW = [], nwW = [];

double totalNetWeight = 0;
    for (var d in dos) {
      String currentSo = d['parent_so']?.toString() ?? req['so']?.toString() ?? "-";
      String custId = d['customer']?['customer_id']?.toString() ?? "-";
      String custName = d['customer']?['customer_name']?.toString() ?? "-";
      String city = d['customer']?['city']?.toString() ?? "-";
      String area = d['customer']?['area']?.toString() ?? "-";

      // for (var det in d['do_details']) {
      final List details = d['do_details'] ?? [];
      for (int i = 0; i < details.length; i++) {
        var det = details[i];
        
        double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
        double nwValue = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
        //double calculatedTnw = (qty * nwValue) / 1000; // Ton
totalNetWeight += (qty * nwValue);
        soW.add(_buildCellText(currentSo, width: 90));
        doNumW.add(_buildCellText(d['do_number'] ?? "-", isBold: true, width: 80));
        if (i == 0) {
          custIdW.add(_buildCellText(custId, width: 70));
          custW.add(_buildCellText(custName, width: 180));
          cityW.add(_buildCellText(city, width: 110));
          areaW.add(_buildCellText(area, width: 120));
        } else {
          custIdW.add(_buildCellText("", width: 70));
          custW.add(_buildCellText("", width: 180));
          cityW.add(_buildCellText("", width: 110));
          areaW.add(_buildCellText("", width: 120));
        }
        // custIdW.add(_buildCellText(custId, width: 70));
        // custW.add(_buildCellText(d['customer']?['customer_name'] ?? "-", width: 190));
        // cityW.add(_buildCellText(city, width: 110));
        // areaW.add(_buildCellText(area, width: 120));
        matIdW.add(_buildCellText(det['material']?['material_id']?.toString() ?? "-", width: 70));
        matW.add(_buildCellText(det['material']?['material_name'] ?? "-", width: 210));
        matTypeW.add(_buildCellText(det['material']?['material_type'] ?? "-", width: 80));
        divDescW.add(_buildCellText(det['material']?['division_description'] ?? "-", width: 130));
        qtyW.add(_buildCellText(_formatSmart(qty), isBold: true, width: 50));
        nwW.add(_buildCellText(_formatSmart(nwValue), width: 60));
        //tnwW.add(_buildCellText(calculatedTnw.toStringAsFixed(2), isBold: true, width: 60));
      }
    }
double totalTnwTon = totalNetWeight / 1000;
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) => isGroupRow ? Colors.blue.shade50.withOpacity(0.3) : null),
      cells: [
        // Ship ID
        // DataCell(Column(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     // Text(isGroupRow ? "GROUP ID: ${req['group_id']}\n(${idsInRow.join(',')})" : req['shipping_id'].toString(),
        //     //     style: TextStyle(fontWeight: isGroupRow ? FontWeight.bold : FontWeight.normal, fontSize: 11)),
        //     Text(idsInRow.join(", "), style: const TextStyle(fontSize: 11)),
        DataCell(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...idsInRow.map((id) => Text(
                    id.toString(),
                    style: TextStyle(
                      fontSize: 11,
                    ),
                  )),
            if (isGroupRow) 
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text("GROUP ID: ${req['group_id']}",
                  style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
        
          ],
    ),
        )),
        // 2. STUFFING DATE
        DataCell(Text(_formatDateOnly(req['stuffing_date']), style: const TextStyle(fontSize: 11))),
        // 3. RDD (Multi-tanggal jika Group)
        DataCell(Builder(builder: (context) {
          if (isGroupRow && req['all_rdds'] != null) {
            List<String?> rdds = List<String?>.from(req['all_rdds']);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rdds.map((r) => Text(_formatDateOnly(r), style: const TextStyle(fontSize: 11))).toList(),
            );
          }
          return Text(_formatDateOnly(req['rdd']), style: const TextStyle(fontSize: 11));
        })),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: doNumW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: soW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: custIdW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: custW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: cityW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: areaW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: matIdW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: matW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: matTypeW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: divDescW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: qtyW)),
        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: nwW)),
        //DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, children: tnwW)),
        DataCell(
        Center(
          child: Text(
            totalTnwTon.toStringAsFixed(2), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
          ),
        )
      ),
        // RDD Handling for Groups
        // DataCell(Builder(builder: (context) {
        //   if (req['all_rdds'] != null) {
        //     List<String?> rdds = List<String?>.from(req['all_rdds']);
        //     return Column(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: rdds.map((r) => Text(_formatDateOnly(r), style: const TextStyle(fontSize: 11))).toList(),
        //     );
        //   }
        //   return Text(_formatDateOnly(req['rdd']));
        // })),
        //DataCell(Text(req['material']?[0]?['division_description'] ?? "-", style: const TextStyle(fontSize: 11))),
        DataCell(Text(warehouseName)),
        // DataCell(Text(vendorName,)),
        // Contoh geser ke KIRI (Alignment.centerLeft)
DataCell(
  Padding(
    padding: const EdgeInsets.only(left: 30.0), // Geser sedikit ke kanan sebesar 10 pixel
    child: Text(vendorName, style: const TextStyle(fontSize: 14)),
  ),
),
        DataCell(Text(typeUnit)),
        DataCell(Text(winnerRank)),
        DataCell(Text(jamBooking)),
        DataCell(Text(checkInAt)),
        DataCell(Text(keluarAt)),
        //DataCell(Text(leadTimeStr, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(noPolisi)),
        DataCell(Text(noSegelPelayaran, style: const TextStyle(fontSize: 12))),
        DataCell(Text(checkerName)),
        DataCell(Text(shift)),
        DataCell(Text(sjKembali)),
      ],
    );
  }
// --- EXCEL EXPORT LOGIC ---
  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Dashboard_Logistik'];
      excel.delete('Sheet1');

      // Header
      sheet.appendRow([
        TextCellValue('Ship ID'), 
        TextCellValue('No DO'), 
        TextCellValue('Customer'), 
        TextCellValue('Stuffing Date')
      ]);

      for (var req in _filteredRequests) {
        sheet.appendRow([
          TextCellValue(req['shipping_id'].toString()),
          TextCellValue(req['delivery_order']?[0]?['do_number'] ?? "-"),
          TextCellValue(req['delivery_order']?[0]?['customer']?['customer_name'] ?? "-"),
          TextCellValue(req['stuffing_date'] ?? "-"),
        ]);
      }

      final fileBytes = excel.encode();
      if (fileBytes == null) return;

      final fileName = "Logistik_Export_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx";

      if (kIsWeb) {
        final content = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(content);
        html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = io.File('${dir.path}/$fileName');
        await file.writeAsBytes(fileBytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }
  Widget _buildCellText(String text, {bool isBold = false, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  // --- PARSING & UTILITY FUNCTIONS ---
  String _formatSmart(dynamic value) {
    if (value == null) return "0";
    double n = double.tryParse(value.toString()) ?? 0.0;
    num rounded = num.parse(n.toStringAsFixed(3));
    return rounded.toString();
  }

  String _formatDateOnly(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return "-";
    try {
      return DateFormat('dd/MM/yy').format(DateTime.parse(dateStr.toString()));
    } catch (_) {
      return "-";
    }
  }

  String _formatDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.toString().isEmpty) return "-";
    try {
      return DateFormat('HH:mm').format(DateTime.parse(dateTimeStr.toString()));
    } catch (_) {
      return "-";
    }
  }

  String _calculateLeadTime(dynamic checkInStr, dynamic keluarStr) {
    if (checkInStr == null || keluarStr == null) return "-";
    try {
      DateTime checkIn = DateTime.parse(checkInStr.toString());
      DateTime keluar = DateTime.parse(keluarStr.toString());
      Duration diff = keluar.difference(checkIn);
      
      // Mengembalikan selisih dalam format total jam bulat (hour) sesuai permintaan
      return "${diff.inHours} Jam";
    } catch (_) {
      return "-";
    }
  }
}