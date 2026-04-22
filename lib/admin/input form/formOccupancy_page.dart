import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WarehouseOccupancyForm extends StatefulWidget {
  const WarehouseOccupancyForm({super.key});

  @override
  State<WarehouseOccupancyForm> createState() => _WarehouseOccupancyFormState();
}

class _WarehouseOccupancyFormState extends State<WarehouseOccupancyForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Variabel untuk Tanggal
  late DateTime _selectedDate;
  late TextEditingController _dateController;

  // Variabel Data
  List<Map<String, dynamic>> _warehouseList = []; // Data dari DB
  List<Map<String, dynamic>> _rows = []; // Baris input di UI
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // 1. Set Tanggal Otomatis Hari Ini
    _selectedDate = DateTime.now();
    _dateController = TextEditingController(
      text: "${_selectedDate.toLocal()}".split(' ')[0]
    );

    // 2. Load Data Warehouse dan Inisialisasi Baris Pertama
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    await _fetchWarehouses();
    _addRow(); // Tambah satu baris kosong di awal
  }

  // AMBIL DATA WAREHOUSE DARI DATABASE UNTUK DROPDOWN
  Future<void> _fetchWarehouses() async {
    try {
      final data = await Supabase.instance.client
          .from('warehouse')
          .select('warehouse_id, warehouse_name')
          .order('warehouse_name', ascending: true);

      setState(() {
        _warehouseList = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar("Gagal memuat data warehouse: $e", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // TAMBAH BARIS INPUT BARU
  void _addRow() {
    setState(() {
      _rows.add({
        "warehouse_id": null,
        "capacity_controller": TextEditingController(),
      });
    });
  }

  // HAPUS BARIS INPUT
  void _removeRow(int index) {
    if (_rows.length > 1) {
      setState(() {
        _rows[index]['capacity_controller'].dispose();
        _rows.removeAt(index);
      });
    } else {
      _showSnackBar("Minimal harus ada satu baris input", Colors.orange);
    }
  }

  // SIMPAN DATA KE SUPABASE
  // SIMPAN DATA KE SUPABASE
  Future<void> _saveData() async {
    // 1. Validasi form
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 2. Insert ke tabel MASTER (occupancy)
      // .select().single() digunakan agar kita mendapatkan return data id yang baru dibuat
      final masterResponse = await supabase
          .from('occupancy')
          .insert({
            'tanggal': _selectedDate.toIso8601String().split('T')[0], // Format YYYY-MM-DD
            'created_by': 'Admin', // Ganti sesuai user session jika ada
          })
          .select()
          .single();

      final int newOccupancyId = masterResponse['occupancy_id'];

      // 3. Mapping data untuk tabel DETAIL (occupancy_details)
      final List<Map<String, dynamic>> detailsPayload = _rows.map((row) {
        return {
          'warehouse_id': row['warehouse_id'],
          'kapasitas_tersedia': int.parse(row['capacity_controller'].text),
          'occupancy_id': newOccupancyId, // Gunakan ID dari langkah 2
        };
      }).toList();

      // 4. Eksekusi Insert ke DETAIL (Bulk Insert)
      await supabase.from('occupancy_details').insert(detailsPayload);

      _showSnackBar("Data berhasil disimpan ke database!", Colors.green);
      
      // 5. Reset Form
      _resetForm();
    } catch (e) {
      _showSnackBar("Gagal menyimpan data: $e", Colors.red);
      print("Error detail: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _resetForm() {
    setState(() {
      for (var row in _rows) {
        row['capacity_controller'].dispose();
      }
      _rows = [];
      _addRow();
      _selectedDate = DateTime.now();
      _dateController.text = "${_selectedDate.toLocal()}".split(' ')[0];
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Input Occupancy"),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: _isLoading && _warehouseList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- INPUT TANGGAL ---
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Tanggal Okupansi",
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _dateController.text = "${picked.toLocal()}".split(' ')[0];
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Detail Kapasitas Warehouse",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),

                    // --- LIST BARIS INPUT DINAMIS ---
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dropdown Pilih Warehouse
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: "Warehouse",
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _rows[index]['warehouse_id'],
                                  items: _warehouseList.map((wh) {
                                    return DropdownMenuItem<int>(
                                      value: wh['warehouse_id'],
                                      child: Text(
                                        wh['warehouse_name'],
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() => _rows[index]['warehouse_id'] = val);
                                  },
                                  validator: (v) => v == null ? "Pilih!" : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Input Kapasitas (Angka)
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _rows[index]['capacity_controller'],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Kapasitas",
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "Isi!";
                                    if (int.tryParse(v) == null) return "Angka!";
                                    return null;
                                  },
                                ),
                              ),
                              // Tombol Hapus Baris
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                onPressed: () => _removeRow(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Tombol Tambah Baris
                    TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Tambah Gudang Lain"),
                    ),

                    const SizedBox(height: 30),

                    // Tombol Simpan Ke Database
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isLoading ? null : _saveData,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "SIMPAN KE DATABASE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    // Bersihkan semua controller saat halaman ditutup
    _dateController.dispose();
    for (var row in _rows) {
      row['capacity_controller'].dispose();
    }
    super.dispose();
  }
}