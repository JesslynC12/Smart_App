import 'dart:async';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MasterReviewDailyItem {
  final String location;
  final int kapasitas;
  final int maxUtilize;
  final int hPagi;
  final double hPagiPersen;
  final int actOutbound; // Delivery Plan (H-1)
  final int productionPlanHmin1;
  final int predictOccupancy;
  final int productionPlanHplus1;
  final int deliveryPlanHplus1;
  final int finalOccupancy;
  final int sisaKapasitas;

  MasterReviewDailyItem({
    required this.location,
    required this.kapasitas,
    required this.maxUtilize,
    required this.hPagi,
    required this.hPagiPersen,
    required this.actOutbound,
    required this.productionPlanHmin1,
    required this.predictOccupancy,
    required this.productionPlanHplus1,
    required this.deliveryPlanHplus1,
    required this.finalOccupancy,
    required this.sisaKapasitas,
  });
}

class MasterReviewDailyPage extends StatefulWidget {
  const MasterReviewDailyPage({super.key});

  @override
  State<MasterReviewDailyPage> createState() => _MasterReviewDailyPageState();
}

class _MasterReviewDailyPageState extends State<MasterReviewDailyPage> {
  final supabase = Supabase.instance.client;
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  List<MasterReviewDailyItem> marshoDataList = [];
  List<MasterReviewDailyItem> cookingOilDataList = [];
  List<MasterReviewDailyItem> totalDataList = [];

RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    loadAllData();
    _setupRealtimeListeners();
  }
@override
  void dispose() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtimeListeners() {
    _realtimeChannel = supabase
        .channel('public:master_review_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'occupancy_details',
          callback: (payload) => loadAllData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ppic_form_details',
          callback: (payload) => loadAllData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'do_details',
          callback: (payload) => loadAllData(),
        );
    _realtimeChannel!.subscribe();
  }

  Future<void> loadAllData() async {
    setState(() => isLoading = true);
    try {
      final marsho = await _fetchWarehouseData([12, 13, 6]);
      final cookingOil = await _fetchWarehouseData([1]);
      setState(() {
        marshoDataList = marsho;
        cookingOilDataList = cookingOil;
        //bufferDataList = buffer;
        _calculateGrandTotal();
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<List<MasterReviewDailyItem>> _fetchWarehouseData(List<int> ids) async {
    List<MasterReviewDailyItem> results = [];
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    for (var id in ids) {
      // Get Warehouse Info
      final wh = await supabase.from('warehouse').select().eq('warehouse_id', id).maybeSingle();
      if (wh == null) continue;

      int whId = wh['warehouse_id'];
      int kapasitas = wh['kapasitas'] ?? 0;
      int maxUtilize = wh['max_utilize'] ?? 0;

      // Get H Pagi (Occupancy)
      final occ = await supabase
          .from('occupancy_details')
          .select('kapasitas_tersedia, occupancy!inner(tanggal)')
          .eq('warehouse_id', whId)
          .eq('occupancy.tanggal', formattedDate)
          .order('occupancy_id', ascending: false) 
    .limit(1)                    
    .maybeSingle();

      int hPagi = occ?['kapasitas_tersedia'] ?? 0;
      double hPagiPersen = kapasitas > 0 ? (hPagi / kapasitas) * 100 : 0;

      // Calculate Pallets logic (H-1 & H+1)
      int actOutbound = await _getPalletSum(whId, selectedDate.subtract(const Duration(days: 1)), isProduction: false);
      int prodHmin1 = await _getPalletSum(whId, selectedDate.subtract(const Duration(days: 1)), isProduction: true);
      int prodHplus1 = await _getPalletSum(whId, selectedDate.add(const Duration(days: 1)), isProduction: true);
      int delivHplus1 = await _getPalletSum(whId, selectedDate.add(const Duration(days: 1)), isProduction: false);

      int predictOccupancy = (hPagi - prodHmin1) + actOutbound;
      int finalOccupancy = predictOccupancy - prodHplus1 + delivHplus1;
      int sisaKapasitas = maxUtilize - finalOccupancy;

      results.add(MasterReviewDailyItem(
        location: wh['warehouse_name'],
        kapasitas: kapasitas,
        maxUtilize: maxUtilize,
        hPagi: hPagi,
        hPagiPersen: hPagiPersen,
        actOutbound: actOutbound,
        productionPlanHmin1: prodHmin1,
        predictOccupancy: predictOccupancy,
        productionPlanHplus1: prodHplus1,
        deliveryPlanHplus1: delivHplus1,
        finalOccupancy: finalOccupancy,
        sisaKapasitas: sisaKapasitas,
      ));
    }
    return results;
  }

  Future<int> _getPalletSum(int whId, DateTime date, {required bool isProduction}) async {
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    double totalPallet = 0;

    if (isProduction) {
      final res = await supabase
          .from('ppic_form_details')
          .select('''
            qty, 
            material!inner(box_per_pallet, warehouse_id), 
            ppic_forms!inner(tanggal)
          ''')
          .eq('material.warehouse_id', whId)
          .eq('ppic_forms.tanggal', dateStr);
      
      for (var row in (res as List)) {
        double bpp = double.tryParse(row['material']['box_per_pallet'].toString()) ?? 1.0;
        totalPallet += (row['qty'] ?? 0) / (bpp == 0 ? 1 : bpp);
      }
    } else {
      final res = await supabase
          .from('do_details')
          .select('qty, material!inner(box_per_pallet, warehouse_id), delivery_order!inner(shipping_request!inner(stuffing_date))')
          .eq('material.warehouse_id', whId)
          .eq('delivery_order.shipping_request.stuffing_date', dateStr);

      for (var row in (res as List)) {
        double bpp = double.tryParse(row['material']['box_per_pallet'].toString()) ?? 1.0;
        totalPallet += (row['qty'] ?? 0) / (bpp == 0 ? 1 : bpp);
      }
    }
    return totalPallet.ceil();
  }

Future<void> _exportToExcel() async {
    // Cegah eksekusi ganda jika tombol diklik berulang kali
    if (isLoading) return;

    if (marshoDataList.isEmpty && cookingOilDataList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data kosong, tidak ada yang bisa diekspor"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Daily_Review_Report'];
      excel.delete('Sheet1'); // Hapus sheet bawaan kosong

      // 1. Definisikan Style
      CellStyle headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        // backgroundColorHex: '#ECEFF1', // Warna BlueGrey[50]
      );

      CellStyle grandTotalStyle = CellStyle(
        bold: true,
        // backgroundColorHex: '#E0E0E0', // Warna Grey[300]
      );

      // 2. Buat Header Kolom
      List<String> columns = [
        'Location', 'Kapasitas', 'Max Utilize', 'H Pagi (PP)', 'H Pagi (%)',
        'Deliv Plan (H-1)', 'Prod Plan (H-1)', 'Predict Occ', 'Prod Plan (H+1)',
        'Deliv Plan (H+1)', 'Final Occ', 'Sisa Kapasitas'
      ];

      for (var i = 0; i < columns.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(columns[i]);
        cell.cellStyle = headerStyle;
      }

      int currentRow = 1;

      // Fungsi pembantu untuk mengisi baris data ke sheet excel
      void appendDataRows(List<MasterReviewDailyItem> items, {bool isTotal = false}) {
        for (var item in items) {
          sheetObject.appendRow([
            TextCellValue(item.location),
            IntCellValue(item.kapasitas),
            IntCellValue(item.maxUtilize),
            IntCellValue(item.hPagi),
            DoubleCellValue(double.parse(item.hPagiPersen.toStringAsFixed(2))),
            IntCellValue(item.actOutbound),
            IntCellValue(item.productionPlanHmin1),
            IntCellValue(item.predictOccupancy),
            IntCellValue(item.productionPlanHplus1),
            IntCellValue(item.deliveryPlanHplus1),
            IntCellValue(item.finalOccupancy),
            IntCellValue(item.sisaKapasitas),
          ]);

          if (isTotal) {
            for (var col = 0; col < columns.length; col++) {
              sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow)).cellStyle = grandTotalStyle;
            }
          }
          currentRow++;
        }
      }

      // 3. Masukkan Data MARSHO
      appendDataRows(marshoDataList);

      // 4. Masukkan Data COOKING OIL
      appendDataRows(cookingOilDataList);

      // 5. Masukkan Data GRAND TOTAL
      appendDataRows(totalDataList, isTotal: true);

      // 4. Proses Encoding & Download menggunakan FileSaver (Aman untuk Web & Mobile)
      var fileBytes = excel.encode();
      if (fileBytes != null) {
        String formattedDate = DateFormat('yyyyMMdd').format(selectedDate);
        String fileName = "Master_Review_Daily_$formattedDate";

        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(fileBytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data berhasil diekspor ke Excel"), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint("Export Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan saat eksport: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateGrandTotal() {
    List<MasterReviewDailyItem> combined = [...marshoDataList, ...cookingOilDataList];
    if (combined.isEmpty) return;

    totalDataList = [
      MasterReviewDailyItem(
        location: "GRAND TOTAL",
        kapasitas: combined.fold(0, (sum, item) => sum + item.kapasitas),
        maxUtilize: combined.fold(0, (sum, item) => sum + item.maxUtilize),
        hPagi: combined.fold(0, (sum, item) => sum + item.hPagi),
        hPagiPersen: combined.fold(0.0, (sum, item) => sum + item.hPagiPersen) / combined.length,
        actOutbound: combined.fold(0, (sum, item) => sum + item.actOutbound),
        productionPlanHmin1: combined.fold(0, (sum, item) => sum + item.productionPlanHmin1),
        predictOccupancy: combined.fold(0, (sum, item) => sum + item.predictOccupancy),
        productionPlanHplus1: combined.fold(0, (sum, item) => sum + item.productionPlanHplus1),
        deliveryPlanHplus1: combined.fold(0, (sum, item) => sum + item.deliveryPlanHplus1),
        finalOccupancy: combined.fold(0, (sum, item) => sum + item.finalOccupancy),
        sisaKapasitas: combined.fold(0, (sum, item) => sum + item.sisaKapasitas),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     // appBar: AppBar(title: const Text("Master Review Daily")),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildUnifiedTable(),
                  ),
          ),
        ],
      ),
    );
  }
Widget _buildUnifiedTable() {
  List<DataRow> allRows = [];

  allRows.addAll(marshoDataList.map((item) => _buildRow(item, false)));

  // 2. Spasi antar tabel (Opsional)
  //allRows.add(const DataRow(cells: [DataCell(SizedBox(height: 10)), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox())]));

  // 3. Bagian COOKING OIL
  //allRows.add(_buildHeaderRow("COOKING OIL")); // Baris Judul
  allRows.addAll(cookingOilDataList.map((item) => _buildRow(item, false)));

  // 4. Bagian GRAND TOTAL
  allRows.addAll(totalDataList.map((item) => _buildRow(item, true)));

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columnSpacing: 20, 
      headingRowColor: WidgetStateProperty.all(Colors.blueGrey[50]),
      dataRowMinHeight: 45,
      dataRowMaxHeight: 45,
      columns: _buildColumns(),
      rows: allRows,
    ),
  );
}

// DataRow _buildHeaderRow(String title) {
//   return DataRow(
//     color: MaterialStateProperty.all(Colors.grey[100]),
//     cells: [
//       DataCell(Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
//       ...List.generate(11, (index) => const DataCell(SizedBox())), // Isi sel sisa dengan kosong
//     ],
//   );
// }
  Widget _buildHeader() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text("Tanggal: "),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(now.year + 100),
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
                loadAllData();
              }
            },
            //child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
             icon: const Icon(Icons.calendar_today),
            label: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
          ),
         const Spacer(), // Dorong tombol ke sisi paling kanan row
         _buildActionButton(
          icon: Icons.file_download,
          color: Colors.green,
          tooltip: "Export Excel",
          onPressed: _exportToExcel,
         ),
        ],
      ),
    );
  }

Widget _buildActionButton({
  required IconData icon, 
  required Color color, 
  required String tooltip, 
  required VoidCallback onPressed
}) {
  return Container(
    height: 55,
    decoration: BoxDecoration(
      // 🔥 Menggunakan .withValues() sesuai standar Flutter terbaru agar bebas warning
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 26),
      tooltip: tooltip,
    ),
  );
}
  // Widget _buildSectionTitle(String title) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 8.0),
  //     child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //   );
  // }

  // Widget _buildDataTable(List<MasterReviewDailyItem> data, {bool hideHeader = false, bool isTotal = false}) {
  //   return SingleChildScrollView(
  //     scrollDirection: Axis.horizontal,
  //     child: DataTable(
  //       headingRowHeight: hideHeader ? 0 : 56,
  //       columnSpacing: 20,
  //       headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
  //       dataRowHeight: 45,
  //       columns: _buildColumns(),
  //       rows: data.map((item) => _buildRow(item, isTotal)).toList(),
  //     ),
  //   );
  // }

  List<DataColumn> _buildColumns() {
    return [
      const DataColumn(label: Text('Location')),
      const DataColumn(label: Text('Kapasitas')),
      const DataColumn(label: Text('Max Utilize')),
      const DataColumn(label: Text('H Pagi (PP)')),
      const DataColumn(label: Text('H Pagi (%)')),
      const DataColumn(label: Text('Deliv Plan (H-1)')),
      const DataColumn(label: Text('Prod Plan (H-1)')),
      const DataColumn(label: Text('Predict Occ')),
      const DataColumn(label: Text('Prod Plan(H+1)')),
      const DataColumn(label: Text('Deliv Plan (H+1)')),
      const DataColumn(label: Text('Final Occ')),
      const DataColumn(label: Text('Sisa Kapasitas')),
    ];
  }

  // DataRow _buildRow(MasterReviewDailyItem item, bool isTotal) {
  //   final fmt = NumberFormat('#,###');
  //   final style = isTotal ? const TextStyle(fontWeight: FontWeight.bold) : null;

  //   return DataRow(
  //     color: isTotal ? MaterialStateProperty.all(Colors.grey[200]) : null,
  //     cells: [
  //       DataCell(Text(item.location, style: style)),
  //       DataCell(Text(fmt.format(item.kapasitas), style: style)),
  //       DataCell(Text(fmt.format(item.maxUtilize), style: style)),
  //       DataCell(Text(fmt.format(item.hPagi), style: style?.copyWith(color: Colors.green) ?? const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
  //       DataCell(Text("${item.hPagiPersen.toStringAsFixed(2)}%", style: style?.copyWith(color: Colors.green) ?? const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
  //       DataCell(Text(fmt.format(item.actOutbound), style: style)),
  //       DataCell(Text(fmt.format(item.productionPlanHmin1), style: style)),
  //       DataCell( Text(fmt.format(item.predictOccupancy), style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
  //       DataCell(Text(fmt.format(item.productionPlanHplus1), style: style)),
  //       DataCell(Text(fmt.format(item.deliveryPlanHplus1), style: style)),
  //       DataCell(Text(fmt.format(item.finalOccupancy), style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
  //       DataCell(Text(fmt.format(item.sisaKapasitas), style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
  //     ],
  //   );
  // }

DataRow _buildRow(MasterReviewDailyItem item, bool isTotal) {
  final fmt = NumberFormat('#,###');
  final style = isTotal ? const TextStyle(fontWeight: FontWeight.bold) : null;
  //DataCell _cCell(String text, Color color, {TextStyle? tStyle}) {
    //return DataCell(
  //     Container(
  //       color: color,
  //       alignment: Alignment.center,
  //       width: double.infinity,
  //       height: double.infinity,
  //       child: Text(text, style: tStyle ?? style),
  //     ),
  //   );
  // }

  return DataRow(
    color: isTotal ? WidgetStateProperty.all(Colors.grey[300]) : null,
    cells: [
    //   DataCell(Text(item.location, style: style)),
    //   DataCell(Text(fmt.format(item.kapasitas), style: style)),
    //   DataCell(Text(fmt.format(item.maxUtilize), style: style)),
      
    //   // HPagi & % (Tosca)
    //   _cCell(fmt.format(item.hPagi), colorTosca, tStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
    //   _cCell("${item.hPagiPersen.toStringAsFixed(2)}%", colorTosca),
      
    //   // Deliv & Prod H-1 (Biru)
    //   _cCell(fmt.format(item.actOutbound), colorBlue),
    //   _cCell(fmt.format(item.productionPlanHmin1), colorBlue),
      
    //   // Predict (Orange)
    //   _cCell(fmt.format(item.predictOccupancy), colorOrange, tStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      
    //   // Prod & Deliv H+1 (Ungu)
    //   _cCell(fmt.format(item.productionPlanHplus1), colorPurple),
    //   _cCell(fmt.format(item.deliveryPlanHplus1), colorPurple),
      
    //   // Final & Sisa (Orange)
    //   _cCell(fmt.format(item.finalOccupancy), colorOrange, tStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    //   _cCell(fmt.format(item.sisaKapasitas), colorOrange),
    // ],
     DataCell(Text(item.location, style: style)),
        DataCell(Text(fmt.format(item.kapasitas), style: style)),
        DataCell(Text(fmt.format(item.maxUtilize), style: style)),
        DataCell(Text(fmt.format(item.hPagi), style: style?.copyWith(color: Colors.green) ?? const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        DataCell(Text("${item.hPagiPersen.toStringAsFixed(2)}%", style: style?.copyWith(color: Colors.green) ?? const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        DataCell(Text(fmt.format(item.actOutbound), style: style)),
        DataCell(Text(fmt.format(item.productionPlanHmin1), style: style)),
        DataCell( Text(fmt.format(item.predictOccupancy), style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        DataCell(Text(fmt.format(item.productionPlanHplus1), style: style)),
        DataCell(Text(fmt.format(item.deliveryPlanHplus1), style: style)),
        DataCell(Text(fmt.format(item.finalOccupancy), style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        DataCell(Text(fmt.format(item.sisaKapasitas), style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
      ],
  );
}
  // Widget _buildBufferTable() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _buildSectionTitle("BUFFER REPORT"),
  //       DataTable(
  //         headingRowColor: MaterialStateProperty.all(Colors.green[50]),
  //         columns: const [
  //           DataColumn(label: Text('Asal Produk')),
  //           DataColumn(label: Text('Total Produk (Pallet)')),
  //           DataColumn(label: Text('Total Ritase')),
  //         ],
  //         rows: bufferDataList.map((item) => DataRow(cells: [
  //           DataCell(Text(item.asalProduk)),
  //           DataCell(Text(item.totalProduk.toString())),
  //           DataCell(Text(item.totalRitase.toString())),
  //         ])).toList(),
  //       ),
  //     ],
  //   );
  // }
}