import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PPICFormPage extends StatefulWidget {
  const PPICFormPage({super.key});

  @override
  State<PPICFormPage> createState() => _PPICFormPageState();
}

class _PPICFormPageState extends State<PPICFormPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Header State
  DateTime _selectedDate = DateTime.now();
  late TextEditingController _dateController;
  String? _selectedProductionType;

  // Data Master dari DB
  List<Map<String, dynamic>> _mesinList = [];
  List<Map<String, dynamic>> _materialList = [];
  String? _currentUserName; // Untuk menampung nama dari tabel profiles
  // Baris Input Dinamis
  List<Map<String, dynamic>> _rows = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: "${_selectedDate.toLocal()}".split(' ')[0]);
    _initializeData();
    _fetchUserProfile();
  }

  Future<void> _initializeData() async {
    try {
      final results = await Future.wait([
        supabase.from('mesin').select('mesin_id, nama_mesin').order('nama_mesin'),
        supabase.from('material').select('material_id, material_name').order('material_name'),
      ]);

      setState(() {
        // PERBAIKAN 1: Paksa konversi ID ke int secara eksplisit
        // Seringkali data dari database dianggap dynamic, yang membuat Dropdown error
        _mesinList = (results[0] as List).map((e) => {
          'mesin_id': int.parse(e['mesin_id'].toString()), 
          'nama_mesin': e['nama_mesin']
        }).toList();

        _materialList = (results[1] as List).map((e) => {
          'material_id': int.parse(e['material_id'].toString()), 
          'material_name': e['material_name']
        }).toList();

        _isLoading = false;
      });
      _addRow(); 
    } catch (e) {
      _showSnackBar("Gagal memuat data master: $e", Colors.red);
      setState(() => _isLoading = false);
    }
  }

Future<void> _fetchUserProfile() async {
  try {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();

      setState(() {
        _currentUserName = data['name'];
      });
    }
  } catch (e) {
    debugPrint("Gagal mengambil profil: $e");
    setState(() {
      _currentUserName = "Unknown User";
    });
  }
}



  void _addRow() {
    setState(() {
      _rows.add({
        "shift": null,
        "mesin_id": null,
        "material_id": null,
        "qty_controller": TextEditingController(),
      });
    });
  }

  void _removeRow(int index) {
    if (_rows.length > 1) {
      setState(() {
        _rows[index]['qty_controller'].dispose();
        _rows.removeAt(index);
      });
    } else {
      _showSnackBar("Minimal harus ada satu baris", Colors.orange);
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductionType == null) {
      _showSnackBar("Pilih Production Type!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headerRes = await supabase.from('ppic_forms').insert({
        'tanggal': _dateController.text,
        'production_type': _selectedProductionType,
        'created_by': _currentUserName ?? 'admin',
      }).select().single();

      final int newPpicId = headerRes['ppic_id'];

      final List<Map<String, dynamic>> detailsPayload = _rows.map((row) {
        return {
          'ppic_id': newPpicId,
          'shift': row['shift'],
          'mesin_id': row['mesin_id'],
          'material_id': row['material_id'],
          'qty': int.tryParse(row['qty_controller'].text) ?? 0,
        };
      }).toList();

      await supabase.from('ppic_form_details').insert(detailsPayload);

      _showSnackBar("Data PPIC berhasil disimpan!", Colors.green);
      _resetForm();
    } catch (e) {
      _showSnackBar("Gagal menyimpan data: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      for (var row in _rows) row['qty_controller'].dispose();
      _rows = [];
      _addRow();
      _selectedProductionType = null;
      _selectedDate = DateTime.now();
      _dateController.text = "${_selectedDate.toLocal()}".split(' ')[0];
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Input PPIC Form"),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: _isLoading && _mesinList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 25),
                    const Text("Detail Produksi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) => _buildRowInput(index),
                    ),

                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_circle),
                      label: const Text("Tambah Item Produksi"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _saveData,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SIMPAN KE DATABASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        TextFormField(
          controller: _dateController,
          readOnly: true,
          decoration: const InputDecoration(labelText: "Tanggal", prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2100));
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                _dateController.text = "${picked.toLocal()}".split(' ')[0];
              });
            }
          },
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: _selectedProductionType,
          decoration: const InputDecoration(labelText: "Production Type", border: OutlineInputBorder()),
          items: ['marsho', 'filling'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
          onChanged: (val) => setState(() => _selectedProductionType = val),
          validator: (v) => v == null ? "Wajib pilih type" : null,
        ),
      ],
    );
  }

  Widget _buildRowInput(int index) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(backgroundColor: Colors.red.shade700, radius: 12, child: Text("${index + 1}", style: const TextStyle(fontSize: 12, color: Colors.white))),
                if (_rows.length > 1) IconButton(onPressed: () => _removeRow(index), icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Shift", border: OutlineInputBorder()),
                    value: _rows[index]['shift'],
                    items: ['I', 'II', 'III'].map((s) => DropdownMenuItem(value: s, child: Text("Shift $s"))).toList(),
                    onChanged: (val) => setState(() => _rows[index]['shift'] = val),
                    validator: (v) => v == null ? "!" : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Mesin", border: OutlineInputBorder()),
                    value: _rows[index]['mesin_id'],
                    // PERBAIKAN 2: Pastikan mapping item menggunakan casting 'as int'
                    items: _mesinList.map((m) => DropdownMenuItem<int>(
                      value: m['mesin_id'] as int, 
                      child: Text("${m['mesin_id']} - ${m['nama_mesin']}", overflow: TextOverflow.ellipsis)
                    )).toList(),
                    onChanged: (val) => setState(() => _rows[index]['mesin_id'] = val),
                    validator: (v) => v == null ? "!" : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Material", border: OutlineInputBorder()),
                    value: _rows[index]['material_id'],
                    // PERBAIKAN 3: Pastikan mapping item menggunakan casting 'as int'
                    items: _materialList.map((m) => DropdownMenuItem<int>(
                      value: m['material_id'] as int, 
                      child: Text("${m['material_id']} - ${m['material_name']}", overflow: TextOverflow.ellipsis)
                    )).toList(),
                    onChanged: (val) => setState(() => _rows[index]['material_id'] = val),
                    validator: (v) => v == null ? "!" : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _rows[index]['qty_controller'],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Qty", border: OutlineInputBorder()),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "!";
                      if (int.tryParse(v) == null) return "No!";
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    for (var row in _rows) row['qty_controller'].dispose();
    super.dispose();
  }
}