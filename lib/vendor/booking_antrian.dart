import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ScheduleSelectionPage extends StatefulWidget {
  final int assignmentId;
  final int shippingId;
  final VoidCallback onSuccess;

  const ScheduleSelectionPage({
    super.key,
    required this.assignmentId,
    required this.shippingId,
    required this.onSuccess,
  });

  @override
  State<ScheduleSelectionPage> createState() => _ScheduleSelectionPageState();
}

class _ScheduleSelectionPageState extends State<ScheduleSelectionPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _shippingData;
  String? _selectedTime;

  final List<String> _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', 
    '13:00', '14:00', '15:00', '16:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadData(); // Memuat detail SO/DO saat halaman dibuka
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      // Mengambil data lengkap shipping termasuk detail material (sama seperti AssignVendorPage)
      final response = await supabase
          .from('shipping_request')
          .select('''
            *,
            delivery_order(
              *,
              customer(*),
              do_details(
                qty,
                material:material_id (material_id, material_name, net_weight)
              )
            )
          ''')
          .eq('shipping_id', widget.shippingId)
          .single();

      setState(() {
        _shippingData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat detail: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmAndAccept() async {
    if (_selectedTime == null) return;
    setState(() => _isSaving = true);

    try {
      // 1. Update tabel penugasan vendor
      await supabase.from('shipping_assignments').update({
        'status_assignment': 'accepted',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id_assignment', widget.assignmentId);

      // 2. Update tabel request utama (Status & Jam Kedatangan)
      await supabase.from('shipping_request').update({
        'status': 'on process',
        'arrival_time': _selectedTime, 
      }).eq('shipping_id', widget.shippingId);

      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil! Jadwal telah disimpan."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Detail Order & Pilih Jadwal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailedSummary(), // Detail DO & SO di bagian atas
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text("⏰ PILIH JAM KEDATANGAN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                        ),
                        _buildTimePickerGrid(),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
    );
  }

  // REUSE: Widget Detailed Summary dari kode AssignVendorPage Anda
  Widget _buildDetailedSummary() {
    final data = _shippingData ?? {};
    final List dos = data['delivery_order'] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.red.shade700, width: 6)),
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
                    const Text("🚚 SHIPMENT DETAIL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, letterSpacing: 1.1, fontSize: 11)),
                    _buildBadge(data['storage_location']?.toString().toUpperCase() ?? "-", Colors.red.shade700),
                  ],
                ),
                const SizedBox(height: 8),
                Text("ID Shipping: ${data['shipping_id']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _infoBox("RDD", _formatDate(data['rdd'])),
                    _infoBox("Stuffing", _formatDate(data['stuffing_date'])),
                    _infoBox("SO", data['so']?.toString() ?? "-"),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: const Text("ITEM YANG AKAN DIKIRIM", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          ...dos.map((doItem) {
            final List doDetails = doItem['do_details'] ?? [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("👤 ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(3), 2: FlexColumnWidth(1)},
                      children: [
                        ...doDetails.map((det) {
                          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
                          Map<String, dynamic>? matData = det['material'];
                          return TableRow(
                            children: [
                              _tableCell(matData?['material_id']?.toString() ?? "-", align: TextAlign.center),
                              _tableCell(matData?['material_name']?.toString() ?? "-"),
                              _tableCell(qty.toInt().toString(), align: TextAlign.right, isBold: true),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimePickerGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _timeSlots.length,
        itemBuilder: (context, index) {
          final time = _timeSlots[index];
          final isSelected = _selectedTime == time;
          return InkWell(
            onTap: () => setState(() => _selectedTime = time),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.red.shade700 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(time, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))]),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _selectedTime == null || _isSaving ? null : _confirmAndAccept,
        child: _isSaving 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("KONFIRMASI JADWAL & TERIMA ORDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // REUSE: Helpers dari kode Anda
  Widget _infoBox(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))]));
  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left}) => Padding(padding: const EdgeInsets.all(8), child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
  Widget _buildBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 1)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  String _formatDate(String? s) => s == null || s.isEmpty ? "-" : DateFormat('dd/MM/yy').format(DateTime.parse(s));
}