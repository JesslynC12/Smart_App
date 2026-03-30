import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AssignVendorPage extends StatefulWidget {
  final Map<String, dynamic> shippingData;

  const AssignVendorPage({super.key, required this.shippingData});

  @override
  State<AssignVendorPage> createState() => _AssignVendorPageState();
}

class _AssignVendorPageState extends State<AssignVendorPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _allVendors = [];
  Map<String, dynamic>? _selectedVendor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // 1. Hitung TNW dalam Ton
      double totalWeightKg = 0;
      final dos = widget.shippingData['delivery_order'] as List;
      for (var doItem in dos) {
        final details = doItem['do_details'] as List;
        for (var det in details) {
          double qty = double.tryParse(det['qty'].toString()) ?? 0;
          double nw = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
          totalWeightKg += (qty * nw);
        }
      }
      double tnwTon = totalWeightKg / 1000;

      // 2. Tentukan kriteria pencarian
      String requiredUnit = _determineUnitByWeight(tnwTon);
      String city = dos.isNotEmpty ? (dos[0]['customer']?['city'] ?? "") : "";
      final rawDetails = widget.shippingData['shipping_request_details'] as List;
      String warehouse = rawDetails.isNotEmpty ? rawDetails[0]['storage_location'] : "";

      // 3. Query Rekomendasi & Semua Vendor secara paralel
      final responses = await Future.wait([
        supabase.from('vendor_transportasi').select()
            .eq('city', city)
            .eq('type_unit', requiredUnit)
            .eq('lokasi_gudang', warehouse)
            .order('winner_rank', ascending: true).limit(3),
        supabase.from('vendor_transportasi').select().order('vendor_name', ascending: true)
      ]);

      setState(() {
        _recommendations = List<Map<String, dynamic>>.from(responses[0]);
        _allVendors = List<Map<String, dynamic>>.from(responses[1]);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  String _determineUnitByWeight(double ton) {
    if (ton <= 2.0) return "CDE";
    if (ton <= 4.0) return "CDD";
    if (ton <= 10.0) return "FUSO";
    return "TRONTON/WINGBOX";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Background putih polos agar document style menonjol
      appBar: AppBar(
        title: const Text("Assign Transport Vendor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HEADER RINGKASAN (DOCUMENT STYLE)
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
                  
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: _selectedVendor == null ? null : _processToDatabase,
                      child: const Text("KONFIRMASI & ASSIGN VENDOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // --- 1. TAMPILAN DOCUMENT STYLE (REPLACEMENT FOR CARD) ---
  Widget _buildDetailedSummary() {
    final data = widget.shippingData;
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
                      const SizedBox(width: 12),
                      Text("SO: $soNum", style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}",
                    style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  const SizedBox(height: 10),
                  
                  // Tabel Material Clean
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(4), 2: FlexColumnWidth(1)},
                      children: doDetails.map((det) => TableRow(
                        children: [
                          _tableCell(det['material']?['material_id']?.toString() ?? "-", isHeader: true),
                          _tableCell(det['material']?['material_name'] ?? "-"),
                          _tableCell(det['qty']?.toString() ?? "0", align: TextAlign.right, isBold: true),
                        ],
                      )).toList(),
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

  // --- HELPERS ---
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
      child: Text(text, textAlign: align,
        style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHeader ? Colors.black : Colors.black87)),
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
          boxShadow: isSelected ? [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 4)] : null,
        ),
        child: Row(children: [
          CircleAvatar(backgroundColor: Colors.orange.shade100, radius: 18, child: const Icon(Icons.stars, color: Colors.orange, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        fillColor: Colors.white,
        filled: true,
      ),
      hint: const Text("Pilih vendor lainnya secara manual...", style: TextStyle(fontSize: 12)),
      items: _allVendors.map((v) => DropdownMenuItem(value: v, 
        child: Text("${v['vendor_name']} (${v['type_unit']})", style: const TextStyle(fontSize: 12)))).toList(),
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

  Widget _emptyRecommendationBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
      child: const Center(child: Text("Tidak ada rekomendasi yang cocok dengan rute & unit ini.", 
        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  Future<void> _processToDatabase() async {
    // Logika simpan vendor ke database
    _showSnackBar("Vendor ${_selectedVendor!['vendor_name']} berhasil dipilih!", Colors.green);
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