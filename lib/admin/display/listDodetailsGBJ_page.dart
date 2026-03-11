import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DetailsDOGbjPage extends StatefulWidget {
  const DetailsDOGbjPage({super.key});

  @override
  State<DetailsDOGbjPage> createState() => _DetailsDOGbjPageState();
}

class _DetailsDOGbjPageState extends State<DetailsDOGbjPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _dataList = [];

  // Variabel untuk melacak baris mana yang sedang dibuka (berdasarkan shipping_id)
  int? _expandedId;

  // State input sementara
  String? _selectedSLoc;
  String? _selectedDedicated;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await supabase.from('shipping_request').select('''
            *,
            shipping_request_details!inner(*), 
            delivery_order(
              do_number, 
              customer(customer_name),
              do_details(qty, material_id, material(material_name))
            )
          ''').order('shipping_id', ascending: false);

      setState(() {
        _dataList = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Gagal ambil data: $e", Colors.red);
      }
    }
  }

  Future<void> _simpanDanPindahkan(int sid) async {
    if (_selectedSLoc == null || _selectedDedicated == null) {
      _showSnackBar("Harap isi Lokasi dan Status Dedicated", Colors.orange);
      return;
    }

    try {
      setState(() => _isLoading = true);

      // 1. Update Detail (Simpan input user)
      await supabase.from('shipping_request_details').update({
        'storage_location': _selectedSLoc,
        'is_dedicated': _selectedDedicated,
      }).eq('shipping_id', sid);

      // 2. Tandai agar masuk ke List Vendor (Kita asumsikan dengan kolom status atau flag baru)
      // Misal kita update status di shipping_request menjadi 'to_vendor'
      await supabase.from('shipping_request').update({
        'status': 'waiting vendor delivery request', 
      }).eq('shipping_id', sid);

      _showSnackBar("Berhasil! Data dipindahkan ke List Vendor", Colors.green);
      
      // Reset state & Refresh list (item akan otomatis hilang dari query !inner jika status berubah)
      _expandedId = null;
      _selectedSLoc = null;
      _selectedDedicated = null;
      await _fetchData();
      
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal menyimpan: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("DO Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _dataList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _dataList.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _dataList.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final item = _dataList[index];
                    final sid = item['shipping_id'];
                    final bool isExpanded = _expandedId == sid;

                    return _buildExpandableCard(item, sid, isExpanded);
                  },
                ),
    );
  }Widget _buildExpandableCard(Map<String, dynamic> item, int sid, bool isExpanded) {
  final List dos = item['delivery_order'] ?? [];

  return Card(
    elevation: isExpanded ? 4 : 1,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Column(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ListTile(
            onTap: () {
              setState(() {
                _expandedId = isExpanded ? null : sid;
                _selectedSLoc = null;
                _selectedDedicated = null;
              });
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: isExpanded ? Colors.red.shade700 : Colors.blueGrey[400],
              child: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
            ),
            title: Text(
              "SO: ${item['so'] ?? '-'}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    Text("📅 RDD: ${_formatDate(item['rdd'])}", style: const TextStyle(fontSize: 11)),
                    Text("🚛 Stuffing: ${_formatDate(item['stuffing_date'])}", style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1),
                ),
                const Text("📦 DETAIL BARANG", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),

                // --- TABEL DETAIL MATERIAL ---
                ...dos.map((doItem) {
                  final List details = doItem['do_details'] ?? [];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Box DO
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("DO: ${doItem['do_number']}", 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                              Text(doItem['customer']?['customer_name'] ?? "-", 
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        // Tabel Material
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1), // ID
                            1: FlexColumnWidth(3), // Nama
                            2: FlexColumnWidth(1), // Qty
                          },
                          border: TableBorder(
                            horizontalInside: BorderSide(color: Colors.grey[100]!, width: 1),
                          ),
                          children: [
                            // Header Tabel
                            
                            // Baris Data Material
                            ...details.map((det) {
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(8), child: Text(det['material_id']?.toString() ?? "-", style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(det['material']?['material_name'] ?? "-", style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(det['qty']?.toString() ?? "0", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
            trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
          ),
        ),

        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                const Text("🛠️ INPUT LOGISTIK", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 16),
                
                _buildLabel("Storage Location"),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Pilih Lokasi"),
                  value: _selectedSLoc,
                  items: const [
                    DropdownMenuItem(value: "rungkut", child: Text("Rungkut")),
                    DropdownMenuItem(value: "tambak langon", child: Text("Tambak Langon")),
                  ],
                  onChanged: (val) => setState(() => _selectedSLoc = val),
                ),
                const SizedBox(height: 16),
                _buildLabel("Dedicated Status"),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Pilih Status"),
                  value: _selectedDedicated,
                  items: const [
                    DropdownMenuItem(value: "dedicated", child: Text("Dedicated")),
                    DropdownMenuItem(value: "non-dedicated", child: Text("Non-Dedicated")),
                  ],
                  onChanged: (val) => setState(() => _selectedDedicated = val),
                ),
                // Cari bagian ini di dalam Column di bawah _buildLabel("Dedicated Status")
const SizedBox(height: 24),
Row(
  children: [
    // Tombol Cancel (Outlined agar tidak terlalu dominan dibanding tombol utama)
    Expanded(
      flex: 1,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => _cancelRequest(sid),
        icon: const Icon(Icons.close),
        label: const Text("CANCEL"),
      ),
    ),
    const SizedBox(width: 12),
    // Tombol Simpan (Utama)
    Expanded(
      flex: 2,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => _simpanDanPindahkan(sid),
        icon: const Icon(Icons.local_shipping),
        label: const Text("SIMPAN & TERUSKAN"),
      
                  ),
                ),
              ],
            ),
              ],
          ),
          ),
      ],
    ),
  );
}
Future<void> _cancelRequest(int sid) async {
  final TextEditingController reasonController = TextEditingController();

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Konfirmasi Pembatalan", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Berikan alasan mengapa permintaan ini dibatalkan:"),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: "Masukkkan alasan...",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("KEMBALI")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            if (reasonController.text.trim().isEmpty) {
              _showSnackBar("Alasan wajib diisi!", Colors.orange);
            } else {
              Navigator.pop(context, true);
            }
          },
          child: const Text("BATALKAN SEKARANG", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    setState(() => _isLoading = true);

    // Update 3 kolom sekaligus: status, alasan, dan waktu
    await supabase.from('shipping_request').update({
      'status': 'cancel',
      'cancel_reason': reasonController.text.trim(),
      'cancelled_at': DateTime.now().toIso8601String(), // Mengirimkan waktu saat ini
    }).eq('shipping_id', sid);

    _showSnackBar("Permintaan Berhasil Dibatalkan", Colors.grey.shade800);
    
    // Reset state & refresh list
    setState(() {
       _expandedId = null;
    });
    await _fetchData();
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal membatalkan: $e", Colors.red);
  }
}

  // --- HELPER WIDGETS ---
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      hintText: hint,
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Semua permintaan sudah diproses", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return "-";
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}