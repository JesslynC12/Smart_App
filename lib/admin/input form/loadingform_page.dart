import 'package:flutter/material.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LoadingFormPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? lateReason;
  const LoadingFormPage({super.key, required this.item, this.lateReason});

  @override
  State<LoadingFormPage> createState() => _LoadingFormPageState();
}

class _LoadingFormPageState extends State<LoadingFormPage> {
  
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool _isSubmitting = false;
  Map<String, dynamic>? _shippingData;

String _currentUserName = 'admin';
  String? _rekomendasiLogistic; 
  //String? _lokasiStuffing;
  String? _ganjalBan;
  String? _selectedChecker; 
  List<Map<String, dynamic>> _checkerList = []; 
  final TextEditingController _noSegelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _getProfileName();
    _fetchCheckers();
  }

Future<void> _loadData() async {
  try {
    final assignmentId = widget.item['id_assignment'];
    
    final response = await supabase
        .from('shipping_assignments')
        .select('''
          *,
          vendor_transportasi:id_vendor_details(*),
          request:shipping_id (
            *,
            rdd,
            so,
            warehouse:warehouse_id(*),
            delivery_order(
              *,
              customer(*),
              do_details(
                qty,
                material:material_id(*)
              )
            )
          )
        ''')
        .eq('id_assignment', assignmentId)
        .single();

    if (mounted) {
      setState(() {
        _shippingData = response;
      });
    }
  } catch (e) {
    debugPrint("Error load data vendor: $e");
  }
}
Future<void> _getProfileName() async {
  try {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();
      
      if (mounted && data['name'] != null) {
        setState(() {
          _currentUserName = data['name'];
        });
      }
    }
  } catch (e) {
    debugPrint("Error ambil profil: $e");
  }
}

  @override
  void dispose() {
   _noSegelController.dispose();
    super.dispose();
  }

  // List<String> _mapToList(Map<String, bool> map) {
  //   return map.entries.where((e) => e.value).map((e) => e.key).toList();
  // }

Future<void> _fetchCheckers() async {
    try {
      final data = await supabase
          .from('checker')
          .select('checker_id, checker_name')
          .eq('status', 'active') // Hanya yang aktif
          .order('checker_name', ascending: true);
      
      if (mounted) {
        setState(() {
          _checkerList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Error ambil checker: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Form(
    key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailedSummary(),
                  const SizedBox(height: 10),
                  // --- HASIL INSPEKSI SEBELUMNYA ---
                    _buildSectionTitle("HASIL INSPEKSI UNIT (CHECK-IN)"),
                    _buildInspectionResultSummary(),
                    
                    const SizedBox(height: 12),
                    _buildSectionTitle("LOADING GBJ"),
                    const SizedBox(height: 12),
                 _buildRekomendasiLogistic(),

          const Divider(),
                    if (_rekomendasiLogistic == 'OKE') ...[
                      _buildSectionTitle("DATA TEKNIS LOADING"),
                      _buildLoadingChecklist(), 
                    ] else if (_rekomendasiLogistic != null) ...[
                      _buildLockedInfo(),
                        
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

Widget _buildInspectionResultSummary() {
    final item = widget.item;
  String formatList(dynamic data) {
    if (data == null) return "-";
    if (data is List) {
      return data.isEmpty ? "-" : data.join(", ").toUpperCase();
    }
    return data.toString().toUpperCase();
  }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _resultRow("Sisi Kanan", item['sisi_kanan']),
          _resultRow("Sisi Kiri", item['sisi_kiri']),
          _resultRow("Sisi Depan", item['sisi_depan']),
          _resultRow("Sisi Belakang", item['sisi_pintu_belakang']),
          _resultRow("Sisi Atap", item['sisi_atap']),
          _resultRow("Sisi Lantai", item['sisi_lantai']),
          const Divider(),
          Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child:
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Kondisi Tidak Layak Lainnya:  ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
             Expanded(
                child: Text(
                  formatList(item['kondisi_tidak_standar_lainnya']),
                  style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text("Rekomendasi Treatment: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                
                child: Text(
                  formatList(item['rekomendasi_treatment']?? '-').toString().toUpperCase(),
                  style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          //_resultText("Treatment", item['rekomendasi_treatment']?? "-"),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text("Decision: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item['decision_for_unit'] == 'LAYAK' ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (item['decision_for_unit'] ?? '-').toString().toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, dynamic data) {
    List<String> list = data != null ? List<String>.from(data) : [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text("$label:", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(child: Text(list.isEmpty ? "OK / Standar" : list.join(", "), style: TextStyle(fontSize: 11, color: list.isEmpty ? Colors.green : Colors.red))),
        ],
      ),
    );
  }

  
Widget _buildRekomendasiLogistic() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          _buildLabelField("Verifikasi Rekomendasi Logistic"),
           const SizedBox(height: 12),
          _buildModernRadioGroup(
            ['OKE', 'Tidak Sempurna', 'Belum Dilakukan'], 
            _rekomendasiLogistic, 
           (val) {
            setState(() {
              _rekomendasiLogistic = val;
              if (val != 'OKE') {
                _ganjalBan = null;
                _selectedChecker = null;
                _noSegelController.clear();
              }
         });
          },
        ),
      ],
    ),
  );
}

Future<void> _submitLoadingData() async {
  if (_rekomendasiLogistic == null) {
    _showSnackBar("Harap pilih Verifikasi Rekomendasi Logistic!", Colors.orange);
    return;
  }

  if (_rekomendasiLogistic == 'OKE') {
  bool isFormValid = _formKey.currentState!.validate();
    bool isGanjalValid = _ganjalBan != null;

    if (!isFormValid || !isGanjalValid) {
      _showSnackBar("Mohon lengkapi Checker, No Segel, dan Ganjal Ban!", Colors.orange);
      return;
    }
  }
  setState(() => _isSubmitting = true);
  try {
    final List<int> assignmentIds = List<int>.from(widget.item['grouped_assignment_ids'] ?? [widget.item['id_assignment']]);
    final List<int> shipIds = List<int>.from(widget.item['grouped_shipping_ids'] ?? [widget.item['shipping_id']]);
    final List<Map<String, dynamic>> loadingEntries = assignmentIds.map((id) {
      return {
        'id_assignment': id,
        'loading_by': _currentUserName,
        'verifikasi_rekomendasi_logistic': _rekomendasiLogistic,
        'checker_id': _rekomendasiLogistic == 'OKE' ? int.parse(_selectedChecker!) : null,
        'ganjal_ban': _rekomendasiLogistic == 'OKE' ? _ganjalBan : null,
        'no_segel_smart': (_rekomendasiLogistic == 'OKE' && _noSegelController.text.isNotEmpty) 
            ? _noSegelController.text.trim() 
            : null,
        'loading_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    await supabase.from('loading').insert(loadingEntries);

    if (_rekomendasiLogistic == 'OKE') {
      await supabase.from('shipping_assignments').update({
        'status_assignment': 'loading', 
      }).inFilter('id_assignment', assignmentIds);

      await supabase.from('shipping_request').update({
        'status': 'loading',
      }).inFilter('shipping_id', shipIds);
    }

    if (mounted) {
      String msg = _rekomendasiLogistic == 'OKE' 
          ? "Berhasil! Seluruh grup DO diproses ke Loading." 
          : "Riwayat penolakan grup berhasil dicatat.";
      _showSnackBar(msg, _rekomendasiLogistic == 'OKE' ? Colors.green : Colors.blue);
      
      DynamicTabPage.of(context)?.closeCurrentTab();
    }
  } catch (e) {
    debugPrint("Error Submit Loading: $e");
    _showSnackBar("Gagal Simpan: $e", Colors.red);
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

  Widget _buildLoadingChecklist() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabelField("Ganjal Ban"),
          if (_ganjalBan == null && _rekomendasiLogistic == 'OKE')
              const Text(" *Wajib", style: TextStyle(color: Colors.red, fontSize: 10)),
          _buildModernRadioGroup(
            ['Terpasang', 'Tidak Terpasang'], 
            _ganjalBan, 
            (val) => setState(() => _ganjalBan = val)
          ),
          const SizedBox(height: 25),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedChecker,
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  decoration: _inputDecoration("Checker", Icons.person_pin_rounded),
                  items: _checkerList.map((c) => DropdownMenuItem(
                    value: c['checker_id'].toString(),
                    child: Text(c['checker_name'])
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedChecker = val),
                  validator: (v) => v == null ? "Wajib" : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _noSegelController,
                  style: const TextStyle(fontSize: 12),
                  decoration: _inputDecoration("No Segel SMART", Icons.qr_code_scanner_rounded),
                  // VALIDATOR TEXT FIELD
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Isi No Segel";
                  }
                  return null;
                },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.red.shade700),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }
  
  Widget _buildLabelField(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
    );
  }

  Widget _buildLockedInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)
      ),
      child: const Column(
        children: [
          Icon(Icons.lock_clock_outlined, color: Colors.grey, size: 40),
          SizedBox(height: 10),
          Text("Field Lainnya dikunci.\nSelesaikan treatment unit terlebih dahulu sampai OKE.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade200,
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
    );
  }

  Widget _buildModernRadioGroup(List<String> options, String? groupVal, Function(String?) onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        bool isSelected = groupVal == opt;
        return InkWell(
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.red.shade700 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Colors.red.shade700 : Colors.grey.shade300),
            ),
            child: Text(opt, style: TextStyle(
              fontSize: 12, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black87
            )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailedSummary() {
    final data = _shippingData?? widget.item;
    final request = data['request'] ?? {};
    final String rddGlobal = _formatDate(request['rdd']);
    final String soGlobal = request['so']?.toString() ?? "-";
    final bool isGroup = request['group_id'] != null;
    final List dos = request['delivery_order'] ?? [];
    final warehouse = request['warehouse'];
    String warehouseDisplay = warehouse != null 
        ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 
        : "-";
    Map<String, dynamic>? vendorDetails;
    if (data['vendor_transportasi'] != null) {
      vendorDetails = data['vendor_transportasi'];
    } 
    else if (request['shipping_assignments'] != null && (request['shipping_assignments'] as List).isNotEmpty) {
    
      var firstAssign = request['shipping_assignments'][0];
      vendorDetails = firstAssign['vendor_transportasi'];
    }
    else if (request['vendor_transportasi'] != null) {
      vendorDetails = request['vendor_transportasi'];
    }

    final String vVendorName = vendorDetails?['vendor_name'] ?? '-';
    final String vCity = vendorDetails?['city'] ?? '-';
    final String vArea = vendorDetails?['area'] ?? '-';
    final String vUnit = vendorDetails?['type_unit'] ?? '-';
    final String vendorNikDisplay = data['nik'] ?? request['nik'] ?? vendorDetails?['nik'] ?? '-';
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
                    Text(isGroup ? "📦 GROUP SHIPMENT" : "🚚 SINGLE SHIPMENT", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isGroup ? Colors.blue.shade900 : Colors.red.shade900, letterSpacing: 1.1, fontSize: 11)),
_buildBadge(warehouseDisplay.toUpperCase(), Colors.red.shade700),
                  ],
                ),
                const SizedBox(height: 8),
                Text(isGroup ? "ID Grup: ${request['group_id']}" : "ID Shipping: ${request['shipping_id']}", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
 Text(
                 "$vendorNikDisplay - $vVendorName",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, color: Color(0xFFE0E0E0)),
                ),
                Row(
                  children: [
                    _infoBox("Stuffing Date", _formatDate(request['stuffing_date'])),
                     _infoBox("Type Unit", vUnit),
                    _infoBox("City", vCity),
                    _infoBox("Area", vArea),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: const Text("DETAIL ITEM & CUSTOMER", 
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          ...dos.map((doItem) {
            final List doDetails = doItem['do_details'] ?? [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 6),
                      Text("RDD: $rddGlobal",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 20),
                      Text("SO: $soGlobal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", 
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(3), 2: FlexColumnWidth(0.8), 3: FlexColumnWidth(1.3)},
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
                          final matData = det['material'] ?? {};
                          double unitWeight = double.tryParse(matData['net_weight']?.toString() ?? "0") ?? 0;
                          return TableRow(
                            children: [
                              _tableCell(matData['material_id']?.toString() ?? "-"),
                              _tableCell(matData['material_name']?.toString() ?? "-"),
                              _tableCell(qty.toInt().toString(), align: TextAlign.right, isBold: true),
                              _tableCell((qty * unitWeight).toStringAsFixed(2), align: TextAlign.right),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildBottomAction() {
  bool canSubmit = _rekomendasiLogistic != null;
  bool isOke = _rekomendasiLogistic == 'OKE';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
         onPressed: (_isSubmitting || !canSubmit) ? null : _submitLoadingData,
          style: ElevatedButton.styleFrom(
          // ),
          backgroundColor: _rekomendasiLogistic == 'OKE' ? Colors.green.shade700 : Colors.blue.shade700,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
        ),
  //         child: _isSubmitting 
  //           ? const CircularProgressIndicator(color: Colors.white) 
  //           : const Text("SIMPAN DATA LOADING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  //       ),
  //     ),
  //   );
  // }
  child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
//                 _rekomendasiLogistic == 'OKE' ? "SIMPAN DATA LOADING" : "CATAT RIWAYAT (BELUM OKE)",
//                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
//               ),
//       ),
//     ),
//   );
// }
isOke ? "KONFIRMASI SELESAI (OKE)" : "CATAT RIWAYAT (BELUM OKE)",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ),
  );
}

 Widget _infoBox(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))]));
 
  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) => Padding(padding: const EdgeInsets.all(8), child: Text(text, textAlign: align, style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
  Widget _buildBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)), child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)));
  
   void _showSnackBar(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  String _formatDate(String? s) => s == null || s.isEmpty ? "-" : DateFormat('dd/MM/yy').format(DateTime.parse(s));
}