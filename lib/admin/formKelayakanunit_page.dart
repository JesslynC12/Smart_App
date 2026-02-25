import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const VehicleControlForm(),
    );
  }
}

class VehicleControlForm extends StatefulWidget {
  const VehicleControlForm({super.key});

  @override
  _VehicleControlFormState createState() => _VehicleControlFormState();
}

class _VehicleControlFormState extends State<VehicleControlForm> {
  // Contoh state untuk checkbox
  bool isGudangRungkut = true;
  bool isCde = false;
  bool isWingbox = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Control Form')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            _buildSectionTransporter(),
            const SizedBox(height: 10),
            _buildSectionLogistic(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {}, 
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('SIMPAN FORM'),
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildHeader() {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Text("VEHICLE CONTROL FORM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(color: Colors.black),
          Row(
            children: [
              Expanded(child: _buildTextField("TANGGAL", "03/10/25")),
              Expanded(
                child: Column(
                  children: [
                    _buildCheckboxTile("GUDANG RUNGKUT", isGudangRungkut),
                    _buildCheckboxTile("LOCAL (SMART)", false),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionTransporter() {
    return _sectionWrapper(
      title: "1. DIISI OLEH TRANSPORTER",
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField("NAMA TRANSPORTER", "TEKUN JAYA")),
              Expanded(child: _buildTextField("NAMA SUPIR", "ABUS")),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildTextField("NO POLISI", "B 9763 POU")),
              Expanded(child: _buildTextField("NO HP SUPIR", "081326403681")),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("JENIS KENDARAAN:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Wrap(
            spacing: 10,
            children: [
              _buildCheckboxTile("CDE", false),
              _buildCheckboxTile("CDD", false),
              _buildCheckboxTile("WINGBOX", true),
              _buildCheckboxTile("CONTAINER", false),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionLogistic() {
    return _sectionWrapper(
      title: "2. DIISI OLEH LOGISTIC SMART",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField("JAM MASUK", "15:08 WIB"),
          const Divider(),
          const Text("PENGECEKAN KELAYAKAN CONTAINER", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // Menggunakan Table untuk layout checklist yang rapi seperti di gambar
          Table(
            border: TableBorder.all(color: Colors.grey),
            children: [
              TableRow(children: [

                _tableHeader("Sisi Kanan"),
                _tableHeader("Sisi Kiri"),
                _tableHeader("Sisi Lantai"),
                
              ]),
              TableRow(children: [
                _checkListColumn(["Berkarat", "Kotor", "Basah"]),
                _checkListColumn(["Berkarat", "Kotor", "Basah"]),
                _checkListColumn(["Kotor", "Berlubang", "Bergelombang"]),
              ]),
            ],
          )
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _sectionWrapper({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.blueGrey[900],
            padding: const EdgeInsets.all(4),
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Padding(padding: const EdgeInsets.all(8.0), child: child),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: TextField(
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  Widget _buildCheckboxTile(String label, bool value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: (v) {}, visualDensity: VisualDensity.compact),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  static Widget _tableHeader(String text) {
    return Container(
      padding: const EdgeInsets.all(4),
      color: Colors.grey[200],
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _checkListColumn(List<String> items) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => _buildCheckboxTile(item, false)).toList(),
      ),
    );
  }
}