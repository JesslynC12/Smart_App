import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AssignVendorPage extends StatefulWidget {
  final int shippingId;
 


  const AssignVendorPage({super.key, required this.shippingId});

  @override
  State<AssignVendorPage> createState() => _AssignVendorPageState();
}

class _AssignVendorPageState extends State<AssignVendorPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _allVendors = [];
  Map<String, dynamic>? _selectedVendor;
   Map<String, dynamic>? _shippingData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
Future<void> _loadData() async {
  try {
    setState(() => _isLoading = true);

    // 🔥 1. Ambil dulu group_id
    final header = await supabase
        .from('shipping_request')
        .select('group_id')
        .eq('shipping_id', widget.shippingId)
        .single();

    final groupId = header['group_id'];

    dynamic rawData;

    // 🔥 2. Ambil data berdasarkan kondisi (GROUP / SINGLE)
    if (groupId != null) {
      rawData = await supabase
          .from('shipping_request')
          .select('''
            *,
            shipping_request_details(*),
            delivery_order(
              *,
              customer(*),
              do_details(
                qty,
                material:material_id (
                  material_id,
                  material_name,
                  net_weight
                )
              )
            )
          ''')
          .eq('group_id', groupId)
          .order('shipping_id');
    } else {
      rawData = await supabase
          .from('shipping_request')
          .select('''
            *,
            shipping_request_details(*),
            delivery_order(
              *,
              customer(*),
              do_details(
                qty,
                material:material_id (
                  material_id,
                  material_name,
                  net_weight
                )
              )
            )
          ''')
          .eq('shipping_id', widget.shippingId)
          .single();
    }

    // 🔥 3. Samakan jadi List
    List<Map<String, dynamic>> shippingList =
        groupId != null
            ? List<Map<String, dynamic>>.from(rawData)
            : [rawData];

    // 🔥 4. Gabungkan semua DO dari semua shipping
    List allDOs = [];
    for (var ship in shippingList) {
      final dos = ship['delivery_order'] ?? [];
      allDOs.addAll(dos);
    }

    // 🔥 5. Simpan ke state (INI PENTING)
    setState(() {
      _shippingData = {
        'group_id': groupId,
        'delivery_order': allDOs,
        'shipping_request_details':
            shippingList.first['shipping_request_details'],
        'rdd': shippingList.first['rdd'],
        'stuffing_date': shippingList.first['stuffing_date'],
        'shipping_id': widget.shippingId,
      };
    });

    // 🔥 DEBUG (WAJIB SEKALI CEK INI)
    print("==== SHIPPING DATA ====");
    print(_shippingData);

    // 🔥 6. Hitung TNW
    final totals = _calculateTotals();
    double tnwTon = totals['tnw'] ?? 0;

    // 🔥 7. Tentukan unit kendaraan
    String requiredUnit = _determineUnitByWeight(tnwTon);

    // 🔥 8. Ambil city dari DO pertama
    final dos = _shippingData!['delivery_order'] as List? ?? [];
    String city = "";
    if (dos.isNotEmpty && dos[0]['customer'] != null) {
      city = dos[0]['customer']['city'] ?? "";
    }

    // 🔥 9. Ambil warehouse
    final rawDetails =
        _shippingData!['shipping_request_details'] as List? ?? [];
    String warehouse = rawDetails.isNotEmpty
        ? (rawDetails[0]['storage_location'] ?? "")
        : "";

    // 🔥 10. Ambil vendor
    final responses = await Future.wait([
      supabase
          .from('vendor_transportasi')
          .select()
          .eq('city', city)
          .eq('type_unit', requiredUnit)
          .eq('lokasi_gudang', warehouse)
          .order('winner_rank', ascending: true)
          .limit(3),
      supabase
          .from('vendor_transportasi')
          .select()
          .order('vendor_name', ascending: true)
    ]);

    setState(() {
      _recommendations = List<Map<String, dynamic>>.from(responses[0]);
      _allVendors = List<Map<String, dynamic>>.from(responses[1]);
      _isLoading = false;
    });

  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Error loading data: $e", Colors.red);
  }
}

  String _determineUnitByWeight(double ton) {
    if (ton <= 2.0) return "CDE";
    if (ton <= 4.0) return "CDD";
    if (ton <= 10.0) return "FUSO";
    return "TRONTON/WINGBOX";
  }

 Map<String, double> _calculateTotals() {
  double totalQty = 0;
  double sumAllNW = 0;
if (_shippingData == null) {
  return {'qty': 0, 'total_nw': 0, 'tnw': 0};
}
  final dos = _shippingData!['delivery_order'] as List? ?? [];

  for (var doItem in dos) {
    final details = doItem['do_details'] as List? ?? [];

    for (var det in details) {
      double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;

      // 🔥 HANDLE MATERIAL (ANTI ERROR SEMUA KONDISI)
      dynamic matSource = det['material'];
      Map<String, dynamic>? materialMap;

      if (matSource is List && matSource.isNotEmpty) {
        materialMap = matSource.first as Map<String, dynamic>;
      } else if (matSource is Map<String, dynamic>) {
        materialMap = matSource;
      }

      // 🔥 AMBIL NET WEIGHT DENGAN AMAN
      double unitWeight = 0;
      if (materialMap != null) {
        var nw = materialMap['net_weight'];

        if (nw is num) {
          unitWeight = nw.toDouble();
        } else if (nw is String) {
          unitWeight = double.tryParse(nw) ?? 0;
        }
      }
print("QTY: $qty | NW: $unitWeight");
      // 🔥 HITUNG PER MATERIAL
      double rowNW = qty * unitWeight;

      sumAllNW += rowNW;
      totalQty += qty;
    }
  }

  return {
    'qty': totalQty,
    'total_nw': sumAllNW,
    'tnw': sumAllNW / 1000, // ✅ TON
  };
} 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Assign Transport Vendor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailedSummary(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text("🏆 REKOMENDASI VENDOR (SISTEM)",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ..._recommendations.map((v) => _buildVendorTile(v)),
                        if (_recommendations.isEmpty) _emptyRecommendationBox(),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text("🔍 PILIH MANUAL VENDOR LAIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildManualDropdown(),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCalculationFooter(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _selectedVendor == null ? null : _processToDatabase,
                      child: const Text("KONFIRMASI & ASSIGN VENDOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailedSummary() {
    final data = _shippingData ?? {};
    final bool isGroup = data['group_id'] != null;
    final List dos = data['delivery_order'] ?? [];
    final List rawDetails = data['shipping_request_details'] ?? [];
    final Map<String, dynamic> details = rawDetails.isNotEmpty ? rawDetails[0] : {};

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: isGroup ? Colors.blue.shade700 : Colors.red.shade700, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isGroup ? "📦 GROUP SHIPMENT" : "🚚 SINGLE SHIPMENT",
                      style: TextStyle(fontWeight: FontWeight.bold, color: isGroup ? Colors.blue.shade900 : Colors.red.shade900, letterSpacing: 1.1, fontSize: 11),
                    ),
                    _buildBadge(details['storage_location']?.toString().toUpperCase() ?? "-", Colors.red.shade700),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGroup ? "ID Grup: ${data['group_id']}" : "ID Shipping: ${data['shipping_id']}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _infoBox("RDD", _formatDate(data['rdd'])),
                    _infoBox("Stuffing", _formatDate(data['stuffing_date'])),
                    _infoBox("Dedicated", (details['is_dedicated'] ?? "-").toString().toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: const Text("DETAIL ITEM & CUSTOMER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          ...dos.map((doItem) {
            final List doDetails = doItem['do_details'] ?? [];
            final String soNum = doItem['parent_so']?.toString() ?? data['so']?.toString() ?? "-";

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 20),
                      Text("SO: $soNum",  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(0.8),
                        3: FlexColumnWidth(1.3)
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: [
                            _tableCell("ID Mat", isBold: true, isHeader: true),
                            _tableCell("Name", isBold: true, isHeader: true),
                            _tableCell("Qty", isBold: true, align: TextAlign.right, isHeader: true),
                            _tableCell("NW (Kg)", isBold: true, align: TextAlign.right, isHeader: true),
                          ],
                        ),
                        ...doDetails.map((det) {
                          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
                          
                          var matSource = det['material'];
                          Map<String, dynamic>? matData;
                          if (matSource is List && matSource.isNotEmpty) {
                            matData = matSource[0] as Map<String, dynamic>?;
                          } else if (matSource is Map) {
                            matData = matSource as Map<String, dynamic>?;
                          }

                          double unitWeight = double.tryParse(matData?['net_weight']?.toString() ?? "0") ?? 0;
                          double rowNw = qty * unitWeight;

                          return TableRow(
                            children: [
                              _tableCell(matData?['material_id']?.toString() ?? "-"),
                              _tableCell(matData?['material_name']?.toString() ?? "-"),
                              _tableCell(qty.toInt().toString(), align: TextAlign.right, isBold: true),
                              _tableCell(rowNw.toStringAsFixed(2), align: TextAlign.right),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCalculationFooter() {
    final totals = _calculateTotals();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFooterItem("TOTAL QTY", totals['qty']!.toInt().toString(), Icons.inventory_2_outlined),
          _buildVerticalDivider(),
          _buildFooterItem("TOTAL NW", "${totals['total_nw']!.toStringAsFixed(2)} KG", Icons.scale_outlined),
          _buildVerticalDivider(),
          _buildFooterItem("TOTAL TNW", "${totals['tnw']!.toStringAsFixed(3)} TON", Icons.local_shipping_outlined, isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildFooterItem(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Column(
      children: [
        Row(children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isHighlight ? Colors.red.shade700 : Colors.black87)),
      ],
    );
  }

  Widget _infoBox(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHeader ? Colors.black : Colors.black87)),
    );
  }

  Widget _buildVendorTile(Map<String, dynamic> vendor) {
    bool isSelected = _selectedVendor?['id'] == vendor['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedVendor = vendor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade50 : Colors.white,
          border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CircleAvatar(backgroundColor: Colors.orange.shade100, radius: 18, child: const Icon(Icons.stars, color: Colors.orange, size: 20)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vendor['vendor_name'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text("Unit: ${vendor['type_unit']}  |  Winner Rank: ${vendor['winner_rank']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ])),
          if (isSelected) Icon(Icons.check_circle, color: Colors.red.shade700),
        ]),
      ),
    );
  }

  Widget _buildManualDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      isExpanded: true,
      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), fillColor: Colors.white, filled: true),
      hint: const Text("Pilih vendor lainnya manual...", style: TextStyle(fontSize: 12)),
      items: _allVendors.map((v) => DropdownMenuItem<Map<String, dynamic>>(
        value: v, 
        child: Text("${v['vendor_name']} (${v['type_unit']})", style: const TextStyle(fontSize: 12))
      )).toList(),
      onChanged: (val) => setState(() => _selectedVendor = val),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 1)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVerticalDivider() => Container(height: 25, width: 1, color: Colors.grey.shade300);

  Widget _emptyRecommendationBox() => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: const Center(child: Text("Tidak ada rekomendasi cocok.", style: TextStyle(fontSize: 11, color: Colors.grey))));

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  Future<void> _processToDatabase() async {
    if (_selectedVendor == null) return;
    _showSnackBar("Vendor ${_selectedVendor!['vendor_name']} dipilih!", Colors.green);
    // Tambahkan logika update database di sini
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd/MM/yy').format(DateTime.parse(dateStr));
    } catch (e) {
      return "-";
    }
  }
}