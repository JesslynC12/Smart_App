import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// --- MODELS ---

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

class BufferItem {
  final String asalProduk;
  final int totalProduk;
  final double totalRitase;

  BufferItem({
    required this.asalProduk,
    required this.totalProduk,
    required this.totalRitase,
  });
}

// --- MAIN WIDGET ---

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
  List<BufferItem> bufferDataList = [];

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  // --- LOGIC / CONTROLLER ---

  Future<void> loadAllData() async {
    setState(() => isLoading = true);
    try {
      // 1. Load Marsho & Cooking Oil Data
      final marsho = await _fetchWarehouseData(["MARSHO WAREHOUSE", "LINC - TAMBAK LANGON", "COOLROOM"]);
      final cookingOil = await _fetchWarehouseData(["GBJ CO CHIYODA"]);

      // 2. Load Buffer Data
      final buffer = await _fetchBufferData();

      setState(() {
        marshoDataList = marsho;
        cookingOilDataList = cookingOil;
        bufferDataList = buffer;
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

  Future<List<MasterReviewDailyItem>> _fetchWarehouseData(List<String> names) async {
    List<MasterReviewDailyItem> results = [];
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    for (var name in names) {
      // Get Warehouse Info
      final wh = await supabase.from('warehouse').select().eq('warehouse_name', name).maybeSingle();
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
          .maybeSingle();

      int hPagi = occ?['kapasitas_tersedia'] ?? 0;
      double hPagiPersen = kapasitas > 0 ? (hPagi / kapasitas) * 100 : 0;

      // Calculate Pallets logic (H-1 & H+1)
      int actOutbound = await _getPalletSum(whId, selectedDate.subtract(const Duration(days: 1)), isProduction: false);
      int prodHmin1 = await _getPalletSum(whId, selectedDate.subtract(const Duration(days: 1)), isProduction: true);
      int prodHplus1 = await _getPalletSum(whId, selectedDate.add(const Duration(days: 1)), isProduction: true);
      int delivHplus1 = await _getPalletSum(whId, selectedDate.add(const Duration(days: 1)), isProduction: false);

      // Rumus sesuai Java
      int predictOccupancy = (hPagi - prodHmin1) + actOutbound;
      int finalOccupancy = predictOccupancy - prodHplus1 + delivHplus1;
      int sisaKapasitas = maxUtilize - finalOccupancy;

      results.add(MasterReviewDailyItem(
        location: name,
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

  Future<List<BufferItem>> _fetchBufferData() async {
    String dateHmin1 = DateFormat('yyyy-MM-dd').format(selectedDate.subtract(const Duration(days: 1)));
    
    final res = await supabase
       .from('ppic_form_details')
      .select('''
        qty, 
        material!inner(box_per_pallet, division_description),
        ppic_forms!inner(tanggal)
      ''')
      .eq('material.division_description', 'Branded Export')
      .eq('ppic_forms.tanggal', dateHmin1);
    double pallets = 0;
    for (var row in (res as List)) {
      double bpp = double.tryParse(row['material']['box_per_pallet'].toString()) ?? 1.0;
      pallets += (row['qty'] ?? 0) / (bpp == 0 ? 1 : bpp);
    }

    int totalProduk = pallets.ceil();
    double totalRitase = (totalProduk / 28.0);
    if (totalRitase < 1 && totalProduk > 0) totalRitase = 1.0;

    return [BufferItem(asalProduk: "Produksi", totalProduk: totalProduk, totalRitase: totalRitase.ceilToDouble())];
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

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Master Review Daily")),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("MARSHO WAREHOUSE"),
                        _buildDataTable(marshoDataList),
                        const SizedBox(height: 20),
                        _buildSectionTitle("COOKING OIL"),
                        _buildDataTable(cookingOilDataList, hideHeader: true),
                        const SizedBox(height: 10),
                        _buildDataTable(totalDataList, hideHeader: true, isTotal: true),
                        const SizedBox(height: 30),
                        _buildBufferTable(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text("Tanggal: "),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
                loadAllData();
              }
            },
            child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: loadAllData,
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDataTable(List<MasterReviewDailyItem> data, {bool hideHeader = false, bool isTotal = false}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: hideHeader ? 0 : 56,
        columnSpacing: 20,
        headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
        dataRowHeight: 45,
        columns: _buildColumns(),
        rows: data.map((item) => _buildRow(item, isTotal)).toList(),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      const DataColumn(label: Text('Location')),
      const DataColumn(label: Text('Kapasitas')),
      const DataColumn(label: Text('Max Utilize')),
      const DataColumn(label: Text('H Pagi (PP)')),
      const DataColumn(label: Text('%')),
      const DataColumn(label: Text('Deliv (H-1)')),
      const DataColumn(label: Text('Prod (H-1)')),
      const DataColumn(label: Text('Predict Occ')),
      const DataColumn(label: Text('Prod (H+1)')),
      const DataColumn(label: Text('Deliv (H+1)')),
      const DataColumn(label: Text('Final Occ')),
      const DataColumn(label: Text('Sisa')),
    ];
  }

  DataRow _buildRow(MasterReviewDailyItem item, bool isTotal) {
    final fmt = NumberFormat('#,###');
    final style = isTotal ? const TextStyle(fontWeight: FontWeight.bold) : null;

    return DataRow(
      color: isTotal ? MaterialStateProperty.all(Colors.grey[200]) : null,
      cells: [
        DataCell(Text(item.location, style: style)),
        DataCell(Text(fmt.format(item.kapasitas), style: style)),
        DataCell(Text(fmt.format(item.maxUtilize), style: style)),
        DataCell(Text(fmt.format(item.hPagi), style: style?.copyWith(color: Colors.green) ?? const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        DataCell(Text("${item.hPagiPersen.toStringAsFixed(2)}%", style: style)),
        DataCell(Text(fmt.format(item.actOutbound), style: style)),
        DataCell(Text(fmt.format(item.productionPlanHmin1), style: style)),
        DataCell(Container(color: Colors.orange[50], child: Text(fmt.format(item.predictOccupancy), style: style))),
        DataCell(Text(fmt.format(item.productionPlanHplus1), style: style)),
        DataCell(Text(fmt.format(item.deliveryPlanHplus1), style: style)),
        DataCell(Text(fmt.format(item.finalOccupancy), style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        DataCell(Text(fmt.format(item.sisaKapasitas), style: style)),
      ],
    );
  }

  Widget _buildBufferTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("BUFFER REPORT"),
        DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.green[50]),
          columns: const [
            DataColumn(label: Text('Asal Produk')),
            DataColumn(label: Text('Total Produk (Pallet)')),
            DataColumn(label: Text('Total Ritase')),
          ],
          rows: bufferDataList.map((item) => DataRow(cells: [
            DataCell(Text(item.asalProduk)),
            DataCell(Text(item.totalProduk.toString())),
            DataCell(Text(item.totalRitase.toString())),
          ])).toList(),
        ),
      ],
    );
  }
}