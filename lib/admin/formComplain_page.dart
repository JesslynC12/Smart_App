import 'package:flutter/material.dart';

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
  String? _selectedJenisKomplain;
  
  // Variabel untuk menyimpan material yang dipilih
  Map<String, dynamic>? _selectedMaterial;

  Map<String, dynamic> _headerData = {};
  List<Map<String, dynamic>> _materials = [];

  void _searchDO() {
    String input = _doController.text.trim();
    if (input.toUpperCase() == "DO123") {
      setState(() {
        _isDataLoaded = true;
        _selectedMaterial = null; // Reset pilihan saat cari DO baru
        _headerData = {
          "tanggal": "25-02-2026",
          "rsby": "Surabaya North",
          "emkl": "Logistik Maju Jaya",
          "customer": "Toko Bangunan Sejahtera",
          "gudang": "Gudang Pusat A1",
          "checker": "Andi Hermawan",
          "divisi": "Semen & Mortar",
          "type": "Retail Distribution",
          "no_kendaraan": "L 9832 AB",
          "jam_in": "08:30",
          "jam_out": "10:15",
        };
        _materials = [
          {"no": 1, "no_mat": "MAT001", "nama": "Semen Portland 50kg", "qty": 100, "tipe": "Utama", "divisi": "Semen"},
          {"no": 2, "no_mat": "MAT042", "nama": "Besi 12mm", "qty": 50, "tipe": "Logam", "divisi": "Besi"},
          {"no": 3, "no_mat": "MAT099", "nama": "Paku Kayu 5cm", "qty": 10, "tipe": "Tools", "divisi": "Umum"},
        ];
      });
    } else {
      setState(() => _isDataLoaded = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data No DO tidak ditemukan!")),
      );
    }
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
      body: SingleChildScrollView(
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 255, 90, 79),
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
              bool isSelected = _selectedMaterial?['no_mat'] == item['no_mat'];

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("FORM KOMPLAIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const Divider(),
            
            // Tampilan Material yang dipilih
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400)
              ),
              child: Row( // Gunakan Row untuk menempatkan tombol di sebelah kanan
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
              _selectedMaterial = null; // Menghapus pilihan
              _qtyController.clear();    // Opsional: bersihkan input qty saat cancel
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
                onPressed: _selectedMaterial == null ? null : () {
                  // Aksi kirim laporan
                },
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