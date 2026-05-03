
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleControlFormState extends StatefulWidget {
  final Map<String, dynamic> vehicleData; // Data dari tahap Transporter

  const VehicleControlFormState({super.key, required this.vehicleData});

  @override
  State<VehicleControlFormState> createState() => _VehicleControlFormState();
}

class _VehicleControlFormState extends State<VehicleControlFormState> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // State untuk Checklist Safety
  Map<String, bool> safetyChecklist = {
    "KTP": false,
    "SIM": false,
    "STNK": false,
    "Ganjal Roda": false,
    "Rompi Safety": false,
    "Sepatu Safety": false,
  };

  // State untuk Kondisi Unit
  String kondisiLantai = "Baik";
  String kondisiDinding = "Baik";
  String kondisiAtap = "Baik";
  
  // Keputusan Akhir
  String? decision; // LAYAK, LAYAK DENGAN TREATMENT, DITOLAK
  final _catatanController = TextEditingController();

  Future<void> _submitLogisticForm() async {
    if (decision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih Keputusan Kelayakan!"))
      );
      return;
    }

    try {
      await supabase.from('vehicle_checks').update({
        'safety_factors': safetyChecklist,
        'container_check_result': {
          'lantai': kondisiLantai,
          'dinding': kondisiDinding,
          'atap': kondisiAtap,
        },
        'decision_logistic': decision,
        'catatan_logistic': _catatanController.text,
        'current_step': 'gbj', // Lanjut ke bagian Gudang Barang Jadi
        'jam_masuk_logistik': DateTime.now().toIso8601String(),
      }).eq('id', widget.vehicleData['id']);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text("Pemeriksaan Logistik")),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Faktor Keselamatan (Safety)"),
              ...safetyChecklist.keys.map((key) {
                return CheckboxListTile(
                  title: Text(key),
                  value: safetyChecklist[key],
                  onChanged: (val) => setState(() => safetyChecklist[key] = val!),
                );
              }).toList(),

              const Divider(height: 30),
              _sectionTitle("Kondisi Kontainer / Bak"),
              _buildConditionPicker("Kondisi Lantai", (val) => kondisiLantai = val),
              _buildConditionPicker("Kondisi Dinding", (val) => kondisiDinding = val),
              _buildConditionPicker("Kondisi Atap (Bocor?)", (val) => kondisiAtap = val),

              const Divider(height: 30),
              _sectionTitle("Keputusan Logistik"),
              _buildDecisionRadio("LAYAK", Colors.green),
              _buildDecisionRadio("LAYAK DENGAN TREATMENT", Colors.orange),
              _buildDecisionRadio("DITOLAK", Colors.red),

              const SizedBox(height: 15),
              TextField(
                controller: _catatanController,
                decoration: const InputDecoration(
                  labelText: "Catatan Tambahan",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                  onPressed: _submitLogisticForm,
                  child: const Text("SIMPAN & TERUSKAN KE GBJ", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildConditionPicker(String label, Function(String) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Row(
          children: ["Baik", "Rusak/Kotor", "Tajam"].map((choice) {
            return Row(
              children: [
                Radio<String>(
                  value: choice,
                  groupValue: label == "Kondisi Lantai" ? kondisiLantai : (label == "Kondisi Dinding" ? kondisiDinding : kondisiAtap),
                  onChanged: (val) => setState(() {
                    if (label == "Kondisi Lantai") kondisiLantai = val!;
                    if (label == "Kondisi Dinding") kondisiDinding = val!;
                    if (label == "Kondisi Atap (Bocor?)") kondisiAtap = val!;
                  }),
                ),
                Text(choice),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDecisionRadio(String value, Color color) {
    return RadioListTile<String>(
      title: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      value: value,
      groupValue: decision,
      onChanged: (val) => setState(() => decision = val),
    );
  }
}