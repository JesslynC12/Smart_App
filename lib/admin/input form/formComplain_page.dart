import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComplainPage extends StatefulWidget {
  const ComplainPage({super.key});

  @override
  State<ComplainPage> createState() => _ComplainPageState();
}

class _ComplainPageState extends State<ComplainPage> {
  final TextEditingController _doController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  bool _isDataLoaded = false;
  bool _isLoading = false;
  String? _selectedJenisKomplain;
  
  Map<String, dynamic>? _selectedMaterial;

  Map<String, dynamic> _headerData = {};
  List<Map<String, dynamic>> _materials = [];

Future<void> _searchDO() async {
  String input = _doController.text.trim();
  if (input.isEmpty) return;

  setState(() => _isLoading = true);

  try {
    final response = await Supabase.instance.client
        .from('delivery_order')
        .select('shipping_id')
        .eq('do_number', input);

    if ((response as List).isEmpty) {
      _showSnackBar("No DO tidak ditemukan!");
      setState(() => _isDataLoaded = false);
      return;
    }

    final int shippingId = (response as List)[0]['shipping_id'];

    final allDos = await Supabase.instance.client
        .from('delivery_order')
        .select('''
          *,
          customer(customer_name),
          shipping_request(stuffing_date, rdd, warehouse(warehouse_name)),
          do_details(
            details_id, qty,
            material(material_id, material_name, material_type, division_description)
          )
        ''')
        .eq('shipping_id', shippingId);

    final assignmentData = await Supabase.instance.client
        .from('shipping_assignments')
        .select('*, checker(checker_name), master_vendor(nik, vendor_name)')
        .eq('shipping_id', shippingId)
        .limit(1);

    final assignment = (assignmentData as List).isNotEmpty ? (assignmentData as List)[0] : null;

    if ((allDos as List).isEmpty) {
      _showSnackBar("Data detail tidak ditemukan!");
      return;
    }

    List<Map<String, dynamic>> allMaterials = [];
    List<String> customerList = [];

    for (var doItem in (allDos as List)) {
      customerList.add(doItem['customer']['customer_name']);
      
      final List details = doItem['do_details'];
      for (var item in details) {
        final mat = item['material'];
        allMaterials.add({
          "do_number": doItem['do_number'],
          "details_id": item['details_id'],
          "no_mat": mat['material_id'],
          "nama": mat['material_name'],
          "qty": item['qty'],
          "tipe": mat['material_type'],
          "divisi": mat['division_description']
        });
      }
    }

    setState(() {
      _isDataLoaded = true;
      _materials = allMaterials;
      _headerData = {
        "no_polisi": assignment?['no_polisi'] ?? "-",
        "tahun": assignment?['tahun_kendaraan'] ?? "-",
        "supir": assignment?['nama_supir'] ?? "-",
        "hp_supir": assignment?['no_hp_supir'] ?? "-",
        "vendor": assignment?['master_vendor'] != null 
            ? "${assignment['master_vendor']['nik']} - ${assignment['master_vendor']['vendor_name']}"
            : "-",
        "customer": customerList.toSet().join(", "),
        "stuffing": (allDos as List)[0]['shipping_request']?['stuffing_date'] ?? "-",
        "rdd": (allDos as List)[0]['shipping_request']?['rdd'] ?? "-",
        "gudang": (allDos as List)[0]['shipping_request']?['warehouse']?['warehouse_name'] ?? "-",
        "checker": assignment?['checker']?['checker_name'] ?? "-",
        "jam_in": assignment?['checkIn_at'] != null 
            ? DateFormat('HH:mm').format(DateTime.parse(assignment['checkIn_at'])) : "-",
        "jam_out": assignment?['keluar_at'] != null 
            ? DateFormat('HH:mm').format(DateTime.parse(assignment['keluar_at'])) : "-",
      };
    });
  } catch (e) {
    debugPrint("Error: $e");
    _showSnackBar("Error: ${e.toString()}");
  } finally {
    setState(() => _isLoading = false);
  }
}

// Future<void> _fetchMaterials(int doId) async {
//   final data = await Supabase.instance.client
//       .from('do_details')
//       .select('*, material(*)')
//       .eq('do_id', doId);
  
//   setState(() {
//     _materials = (data as List).asMap().entries.map((entry) {
//       var item = entry.value;
//       var mat = item['material'];
//       return {
//         "no": entry.key + 1,
//         "details_id": item['details_id'],
//         "no_mat": mat['material_id'],
//         "nama": mat['material_name'],
//         "qty": item['qty'],
//         "tipe": mat['material_type'],
//         "divisi": mat['division_description']
//       };
//     }).toList();
//   });
// }

  Future<void> _sendComplaint() async {
    if (_selectedMaterial == null || _selectedJenisKomplain == null || _qtyController.text.isEmpty) {
      _showSnackBar("Mohon lengkapi semua data!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('complain').insert({
        'complain_type': _selectedJenisKomplain,
        'details_id': _selectedMaterial!['details_id'],
        'qty': int.parse(_qtyController.text),
        'complain_note': _catatanController.text,
        'complain_status': 'PENDING',
        'created_by': 'Admin', 
      });

      _showSnackBar("Berhasil mengirim laporan komplain!", isError: false);
      
      if (_materials.length > 1) {
       
        _qtyController.clear();
        _catatanController.clear();
        setState(() {
          _selectedMaterial = null;
          _selectedJenisKomplain = null;
        });
      } else {
        _resetForm();
      }

    } catch (e) {
      _showSnackBar("Gagal simpan: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }
void _resetForm() {
  setState(() {
    _doController.clear();      
    _qtyController.clear();     
    _catatanController.clear(); 
    _selectedMaterial = null;  
    _selectedJenisKomplain = null;
    _isDataLoaded = false;    
    _headerData = {};          
    _materials = [];          
  });
}
  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
    
      body: _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _doController,
                  decoration: InputDecoration(
                    hintText: "Cari No DO...",
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.blueGrey),
                      onPressed: _searchDO,
                    ),
                  ),
                  onSubmitted: (_) => _searchDO(),
                ),
              ),
            ),

            if (_isDataLoaded) ...[
              const SizedBox(height: 12),
              _buildRekapInfoCard(),
              const SizedBox(height: 12),
              const Text("Pilih material di bawah untuk dikomplain:", 
                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildModernMaterialTable(),
              const SizedBox(height: 12),
              _buildComplaintInputForm(),
              const SizedBox(height: 20),
            ] else 
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Text("Cari No DO untuk menampilkan rekap data", style: TextStyle(color: Colors.grey)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildRekapInfoCard() {
    return Card(
      elevation: 2,
      color: Colors.white, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("REKAP PENGIRIMAN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                Text(_headerData['tanggal'] ?? "", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Divider(),
            Table(
              columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(0.2), 2: FlexColumnWidth(2)},
              children: [
                _buildTableRow("Driver / HP", "${_headerData['supir']} (${_headerData['hp_supir']})"),
              _buildTableRow("No. Polisi / Thn", "${_headerData['no_polisi']} / ${_headerData['tahun']}"),
              _buildTableRow("Vendor / Transporter", _headerData['vendor']),
              _buildTableRow("Stuffing / RDD", "${_headerData['stuffing']} / ${_headerData['rdd']}"),
              // Row Customer akan otomatis memanjang ke bawah jika banyak (Multi-Customer)
              _buildTableRow("Customer Tujuan", _headerData['customer']), 
              _buildTableRow("Jam In / Out", "${_headerData['jam_in']} - ${_headerData['jam_out']}"),
              _buildTableRow("Gudang", _headerData['gudang']),
              _buildTableRow("Checker", _headerData['checker']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, dynamic value) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text(":", style: TextStyle(fontSize: 13))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(value?.toString() ?? "-", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _buildModernMaterialTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 211, 47, 47),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text("No", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("No Mat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 4, child: Text("Nama Material", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("Tipe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("Divisi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 1, child: Text("Qty", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _materials.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _materials[index];
              bool isSelected = _selectedMaterial?['details_id'] == item['details_id'];

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedMaterial = item;
                  });
                },
                child: Container(
                  color: isSelected ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text(item['do_number'].toString(), style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                      Expanded(flex: 2, child: Text(item['no_mat'].toString(), style: const TextStyle(fontSize: 11))),
                      Expanded(flex: 4, child: Text(item['nama'].toString(), style: const TextStyle(fontSize: 11))),
                      Expanded(flex: 2, child: Text(item['tipe'].toString(), style: const TextStyle(fontSize: 11))),
                      Expanded(flex: 2, child: Text(item['divisi'].toString(), style: const TextStyle(fontSize: 11))),
                      Expanded(flex: 1, child: Text(item['qty'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintInputForm() {
    return Card(
      elevation: 2,
       color: Colors.white, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("FORM KOMPLAIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const Divider(),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Material Terpilih:", style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(_selectedMaterial != null 
                          ? "[${_selectedMaterial!['no_mat']}] - ${_selectedMaterial!['nama']}"
                          : "Belum ada material dipilih. Klik pada tabel di atas.",
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.bold,
                            color: _selectedMaterial != null ? Colors.black : Colors.red.shade300
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedMaterial != null) 
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedMaterial = null;
                          _qtyController.clear();
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: "Batalkan pilihan",
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _buildFieldLabel("Jenis Masalah"),
            DropdownButtonFormField<String>(
            initialValue: _selectedJenisKomplain,
              items: ["Penolakan", "Kekurangan", "Kelebihan"].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _selectedJenisKomplain = v),
              decoration: _inputDecoration("Pilih Jenis"),
            ),
            const SizedBox(height: 10),
            _buildFieldLabel("Jumlah (Qty)"),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("Contoh: 5"),
            ),
            const SizedBox(height: 10),
            _buildFieldLabel("Keterangan Tambahan"),
            TextField(
              controller: _catatanController,
              maxLines: 2,
              decoration: _inputDecoration("Tulis detail di sini..."),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedMaterial == null ? null : _sendComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, 
                  foregroundColor: Colors.white, 
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                ),
                child: const Text("KIRIM LAPORAN"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }
}