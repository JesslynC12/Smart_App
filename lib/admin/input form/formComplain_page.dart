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
  
  // Variabel untuk menyimpan material yang dipilih
  Map<String, dynamic>? _selectedMaterial;

  Map<String, dynamic> _headerData = {};
  List<Map<String, dynamic>> _materials = [];

  // --- FUNGSI SEARCH KE SUPABASE ---
  Future<void> _searchDO() async {
    String input = _doController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('delivery_order')
          .select('''
            *,
            customer (customer_name),
            shipping_request (stuffing_date),
            do_details (
              details_id,
              qty,
              material (material_id, material_name, material_type, division_description)
            )
          ''')
          .eq('do_number', input)
          .maybeSingle();

      if (data == null) {
        _showSnackBar("No DO tidak ditemukan!");
        setState(() => _isDataLoaded = false);
      } else {
        setState(() {
          _isDataLoaded = true;
          _selectedMaterial = null;
          
          // Mapping Header (Sesuaikan dengan kolom yang tersedia di DB Anda)
          _headerData = {
            "do_id": data['do_id'],
            "do_number": data['do_number'],
            "customer": data['customer']?['customer_name'] ?? "-",
          // "tanggal": data['shipping_request']?['shipping_date'] != null 
          "tanggal": (data['shipping_request'] != null && data['shipping_request']['stuffing_date'] != null)
    ? DateFormat('dd MMM yyyy').format(DateTime.parse(data['shipping_request']['stuffing_date'])) 
    : "Tanggal tidak ditemukan",
            "no_kendaraan": "-", 
            "jam_in": "-",
            "jam_out": "-",
            "rsby": "-",
            "emkl": "-",
            "gudang": "-",
            "checker": "-",
            "divisi": "-",
            "type": "-",
          };

          // Mapping List Material
          final List details = data['do_details'] as List;
          _materials = details.asMap().entries.map((entry) {
            int idx = entry.key;
            var item = entry.value;
            final mat = item['material'];
            return {
              "no": idx + 1,
              "details_id": item['details_id'],
              "no_mat": mat['material_id'].toString(), 
              "nama": mat['material_name'] ?? "-",
              "qty": item['qty'],
              "tipe": mat['material_type'] ?? "-",
              "divisi": mat['division_description'] ?? "-"
            };
          }).toList();
        });
      }
    } catch (e) {
      _showSnackBar("Terjadi kesalahan: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI KIRIM KOMPLAIN ---
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
      
      _qtyController.clear();
      _catatanController.clear();
      setState(() {
        _selectedMaterial = null;
        _selectedJenisKomplain = null;
      });

    } catch (e) {
      _showSnackBar("Gagal simpan: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
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
      appBar: AppBar(
        title: const Text("Detail & Komplain DO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
                _buildTableRow("No. Kendaraan", _headerData['no_kendaraan']),
                _buildTableRow("Jam In / Out", "${_headerData['jam_in']} - ${_headerData['jam_out']}"),
                _buildTableRow("Customer", _headerData['customer']),
                _buildTableRow("RSBY / EMKL", "${_headerData['rsby']} / ${_headerData['emkl']}"),
                _buildTableRow("Gudang", _headerData['gudang']),
                _buildTableRow("Checker", _headerData['checker']),
                _buildTableRow("Divisi / Type", "${_headerData['divisi']} / ${_headerData['type']}"),
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
                  color: isSelected ? Colors.red.withOpacity(0.1) : Colors.transparent,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text(item['no'].toString(), style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
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
              value: _selectedJenisKomplain,
              items: ["Penolakan", "Kekurangan", "Kelebihan"].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _selectedJenisKomplain = v),
              decoration: _inputDecoration("Pilih Jenis"),
            ),
            const SizedBox(height: 10),
            _buildFieldLabel("Jumlah (Qty) Komplain"),
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