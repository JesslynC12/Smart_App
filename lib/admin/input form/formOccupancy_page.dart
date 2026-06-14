import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WarehouseOccupancyForm extends StatefulWidget {
  const WarehouseOccupancyForm({super.key});

  @override
  State<WarehouseOccupancyForm> createState() => _WarehouseOccupancyFormState();
}

class _WarehouseOccupancyFormState extends State<WarehouseOccupancyForm> {
  final _formKey = GlobalKey<FormState>();
  
  late DateTime _selectedDate;
  late TextEditingController _dateController;

  List<Map<String, dynamic>> _warehouseList = []; 
  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    _selectedDate = DateTime.now();
    _dateController = TextEditingController(
      text: "${_selectedDate.toLocal()}".split(' ')[0]
    );

    _initializeForm();
  }

  Future<void> _initializeForm() async {
    await _fetchWarehouses();
    _addRow();
  }

  Future<void> _fetchWarehouses() async {
    try {
      final List<int> allowedIds = [12, 13, 6, 1];
      final data = await Supabase.instance.client
          .from('warehouse')
          .select('warehouse_id, warehouse_name')
          .inFilter('warehouse_id', allowedIds)
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

  void _addRow() {
    setState(() {
      _rows.add({
        "warehouse_id": null,
        "capacity_controller": TextEditingController(),
      });
    });
  }

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
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final masterResponse = await supabase
          .from('occupancy')
          .insert({
            'tanggal': _selectedDate.toIso8601String().split('T')[0],
            'created_by': 'Admin', 
          })
          .select()
          .single();

      final int newOccupancyId = masterResponse['occupancy_id'];

      final List<Map<String, dynamic>> detailsPayload = _rows.map((row) {
        return {
          'warehouse_id': row['warehouse_id'],
          'kapasitas_tersedia': int.parse(row['capacity_controller'].text),
          'occupancy_id': newOccupancyId,
        };
      }).toList();

      await supabase.from('occupancy_details').insert(detailsPayload);

      _showSnackBar("Data berhasil disimpan ke database!", Colors.green);
      
      _resetForm();
    } catch (e) {
      _showSnackBar("Gagal menyimpan data: $e", Colors.red);
      //print("Error detail: $e");
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
      body: _isLoading && _warehouseList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: "Warehouse",
                                    border: OutlineInputBorder(),
                                  ),
                                  initialValue: _rows[index]['warehouse_id'],
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

                    TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Tambah Gudang Lain"),
                    ),

                    const SizedBox(height: 30),
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
    _dateController.dispose();
    for (var row in _rows) {
      row['capacity_controller'].dispose();
    }
    super.dispose();
  }
}