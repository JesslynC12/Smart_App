import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CheckInFormPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? lateReason;
//final VoidCallback onBack;
  const CheckInFormPage({super.key, required this.item, this.lateReason});

  @override
  State<CheckInFormPage> createState() => _CheckInFormPageState();
}

class _CheckInFormPageState extends State<CheckInFormPage> {
  
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool _isSubmitting = false;
  Map<String, dynamic>? _shippingData;

  // Controllers
  final TextEditingController _noPolisiController = TextEditingController();
  final TextEditingController _tahunKendaraanController = TextEditingController();
  final TextEditingController _namaSupirController = TextEditingController();
  final TextEditingController _noHpSupirController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  final TextEditingController _kondisiLainManualController = TextEditingController();
  final TextEditingController _treatmentLainManualController = TextEditingController();

  // Checkbox Per Sisi
  final Map<String, bool> _sisiKanan = {'Berkarat': false, 'Bagian Tajam': false, 'Kotor': false, 'Basah': false, 'Berlubang': false, 'Push In/Out': false};
  final Map<String, bool> _sisiKiri = {'Berkarat': false, 'Bagian Tajam': false, 'Kotor': false, 'Basah': false, 'Berlubang': false, 'Push In/Out': false};
  final Map<String, bool> _sisiDepan = {'Berkarat': false, 'Bagian Tajam': false, 'Kotor': false, 'Basah': false, 'Berlubang': false, 'Push In/Out': false};
  final Map<String, bool> _sisiPintu = {'Berkarat': false, 'Bagian Tajam': false, 'Kotor': false, 'Basah': false, 'Berlubang': false, 'Push In/Out': false};
  final Map<String, bool> _sisiAtap = {'Berkarat': false, 'Bagian Tajam': false, 'Kotor': false, 'Basah': false, 'Berlubang': false, 'Push In/Out': false};
  final Map<String, bool> _sisiLantai = {'Berkarat': false, 'Bagian Tajam': false, 'Kotor': false, 'Basah': false, 'Berlubang': false, 'Bergelombang': false};

  // Lain-lain
  final Map<String, bool> _kondisiLain = {'Kontainer Berbau': false, 'Karet Seal Pintu Lepas/Rusak': false, 'Lock Container < 4': false, 'Terkontaminasi Serangga': false};
  final Map<String, bool> _dokumen = {'KTP': false, 'SIM': false, 'STNK': false, 'Buku KUER': false};
  final Map<String, bool> _apd = {'Helm': false, 'Sepatu': false, 'Seragam/Rompi': false};
  final Map<String, bool> _treatment = {'Cleaning': false, 'Las': false, 'Gerinda Sisi Tajam': false, 'Treatment Bau': false, 'Semprot Alkohol': false, 'Silicon Sealent': false, 'Bodem/dongkrak': false, 'Washing': false, 'Pelapisan Dinding': false};

  String? _ganjalRoda;
  String? _remHandRem;
  String? _decision;
bool _isKondisiLainLainChecked = false; 
bool _isTreatmentLainLainChecked = false;
String _currentUserName = 'admin';

  @override
  void initState() {
    super.initState();
    //_shippingData = widget.item;
    _loadData();
    _getProfileName();
  }

// Cari di dalam class _CheckInFormPageState
Future<void> _loadData() async {
  try {
    final assignmentId = widget.item['id_assignment'];
    
    // Kita ambil data ulang dari view/table penugasan lengkap dengan vendornya
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
    _noPolisiController.dispose();
    _tahunKendaraanController.dispose();
    _namaSupirController.dispose();
    _noHpSupirController.dispose();
    _catatanController.dispose();
    _kondisiLainManualController.dispose();
    _treatmentLainManualController.dispose();
    super.dispose();
  }

  List<String> _mapToList(Map<String, bool> map) {
    return map.entries.where((e) => e.value).map((e) => e.key).toList();
  }


// --- FUNGSI VALIDASI SEBELUM SAVE ---
  bool _isValidationSuccess() {
    // 1. Cek Safety Factor
    bool isDocChecked = _dokumen.values.contains(true);
    bool isApdChecked = _apd.values.contains(true);

    // 1. Validasi Form Identitas (No Polisi, Nama Supir, dll)
  // Ini akan memicu pesan error merah di bawah TextField masing-masing
  // if (_noPolisiController.text.trim().isEmpty ||
  //     _tahunKendaraanController.text.trim().isEmpty ||
  //     _namaSupirController.text.trim().isEmpty ||
  //     _noHpSupirController.text.trim().isEmpty) {
  //   _showSnackBar("Harap lengkapi Identitas Kendaraan & Supir!", Colors.orange);
  //   return false;
  // }
  if (!_formKey.currentState!.validate()) {
    _showSnackBar("Harap lengkapi Identitas Kendaraan & Supir!", Colors.orange);
    return false;
  }

    if (!isDocChecked || _ganjalRoda == null || _remHandRem == null) {
      _showSnackBar("Safety Factor (Dokumen, Ganjal, Rem, APD) wajib diisi!", Colors.orange);
      return false;
    }

    // // 2. Cek Rekomendasi Treatment
    // bool isTreatmentChecked = _treatment.values.contains(true) || _isTreatmentLainLainChecked;
    // if (!isTreatmentChecked) {
    //   _showSnackBar("Rekomendasi Treatment wajib diisi minimal satu!", Colors.orange);
    //   return false;
    // }


    // 3. Cek Decision
    if (_decision == null) {
      _showSnackBar("Decision for Unit wajib dipilih!", Colors.orange);
      return false;
    }

    return true;
  }

  Future<void> _submitCheckIn() async {
    //if (!_formKey.currentState!.validate()) return;
   if (!_isValidationSuccess()) {
      //_showSnackBar("Pilih Keputusan Kelayakan Unit!", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);
// Proses List Akhir dengan "Lainnya"
    List<String> kondisiLainFinal = _mapToList(_kondisiLain);
    if (_isKondisiLainLainChecked && _kondisiLainManualController.text.isNotEmpty) {
      kondisiLainFinal.add("Lainnya: ${_kondisiLainManualController.text.trim()}");
    }

    List<String> treatmentFinal = _mapToList(_treatment);
    if (_isTreatmentLainLainChecked && _treatmentLainManualController.text.isNotEmpty) {
      treatmentFinal.add("Lainnya: ${_treatmentLainManualController.text.trim()}");
    }
    try {
      final item = widget.item;
      final List<int> assignmentIds = List<int>.from(item['grouped_assignment_ids'] ?? [item['id_assignment']]);
      final List<int> shipIds = List<int>.from(item['grouped_shipping_ids'] ?? [item['shipping_id']]);
// --- PENYESUAIAN LOGIKA STATUS ---
      // Jika DITOLAK, status assignment menjadi 'Rejected unit'
      // Namun status request kembali ke 'waiting assign vendor delivery' agar muncul di list Admin
      String targetStatusAssignment = (_decision == 'DITOLAK') 
          ? 'rejected unit' 
          : 'kelayakan unit';
          
      String targetStatusRequest = (_decision == 'DITOLAK') 
          ? 'waiting assign vendor delivery' 
          : 'kelayakan unit';

      await supabase.from('shipping_assignments').update({
        'status_assignment': targetStatusAssignment, // Tambahkan baris ini
        'kelayakan_at': DateTime.now().toIso8601String(),
        'kelayakan_by': _currentUserName,
        'no_polisi': _noPolisiController.text.toUpperCase(),
        'tahun_kendaraan': _tahunKendaraanController.text,
        'nama_supir': _namaSupirController.text,
        'no_hp_supir': _noHpSupirController.text,
        'sisi_kanan': _mapToList(_sisiKanan),
        'sisi_kiri': _mapToList(_sisiKiri),
        'sisi_depan': _mapToList(_sisiDepan),
        'sisi_pintu_belakang': _mapToList(_sisiPintu),
        'sisi_atap': _mapToList(_sisiAtap),
        'sisi_lantai': _mapToList(_sisiLantai),
        'kondisi_tidak_standar_lainnya': kondisiLainFinal,
        'dokumen_pendukung': _mapToList(_dokumen),
        'ganjal_roda': _ganjalRoda,
        'rem_handrem': _remHandRem,
        'apd_supir': _mapToList(_apd),
        'rekomendasi_treatment': treatmentFinal,
        'decision_for_unit': _decision,
        'catatan': _catatanController.text, // Pastikan nama kolom di DB sesuai
        'latecheckIn_reason': widget.lateReason,
      }).inFilter('id_assignment', assignmentIds);

      await supabase.from('shipping_request').update({
        'status': targetStatusRequest,
      }).inFilter('shipping_id', shipIds);

      // if (mounted) {
      //   _showSnackBar("Check-in Berhasil!", Colors.green);
      //   //Navigator.pop(context);
      //   DynamicTabPage.of(context)?.closeCurrentTab();
      // }
      if (mounted) {
        _showSnackBar(
          _decision == 'DITOLAK' ? "Unit Ditolak. Status kembali ke Waiting Assign Vendor." : "Check-in Berhasil!", 
          _decision == 'DITOLAK' ? Colors.orange : Colors.green
        );
        DynamicTabPage.of(context)?.closeCurrentTab();
      }
    } catch (e) {
      _showSnackBar("Gagal Simpan: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // appBar: AppBar(
      //   title: const Text("Form Check-In Unit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      //   elevation: 0,
      //   // leading: IconButton(
      //   //   icon: const Icon(Icons.arrow_back),
      //   //   onPressed: widget.onBack,
      //   // ),
      // ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailedSummary(),
                  const SizedBox(height: 25),
                  _buildSectionTitle("1. IDENTITAS KENDARAAN & SUPIR"),
                  _buildDriverForm(),
                  //const Divider(),
                  _buildSectionTitle("2. KONDISI CONTAINER (SISI)"),
                  _buildContainerGrid(),
                  _buildSectionTitle("3. KONDISI TIDAK STANDAR LAINNYA"),
                  // _buildCheckboxGroup(_kondisiLain),
                  _buildCheckboxGroup(_kondisiLain, isKondisiLain: true),
                  //const Divider(),
                  _buildSectionTitle("4. SAFETY FACTOR"),
                  _buildSafetyFactor(),
                  //const Divider(),
                  _buildSectionTitle("5. REKOMENDASI TREATMENT"),
                  _buildTreatmentCheckboxGroup(_treatment),
                  //const Divider(),
                  _buildSectionTitle("6. DECISION FOR UNIT"),
                  _buildDecisionSection(),
                  //Text("Catatan Logistic", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.bold, color: Colors.blueGrey)),
                  // _buildCatatanField(),
                  // const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("Catatan Logistic", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  ),
                  _buildCatatanField(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
    );
  }

  Widget _buildDriverForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child:_buildTextField(
  _noPolisiController, 
  'No Polisi *', 
  isUpperCase: true, 
  maxLength: 12
),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(
  _tahunKendaraanController, 
  'Tahun', 
  isNumber: true
)),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
  _namaSupirController, 
  'Nama Supir *', 
),
            const SizedBox(height: 10),
            _buildTextField(
  _noHpSupirController, 
  'No HP Supir *', 
  isNumber: true
),
        
            if (widget.lateReason != null) ...[
              const SizedBox(height: 10),
              _buildLateWarning(),
            ],
        
          ],
          
        ),
        
      ),
      
    );
  }

  // Widget _buildContainerGrid() {
  //   return Padding(
  //     padding: const EdgeInsets.all(8.0),
  //     child: GridView.count(
  //       shrinkWrap: true,
  //       physics: const NeverScrollableScrollPhysics(),
  //       crossAxisCount: 6,
  //       childAspectRatio: 0.8,
  //       children: [
  //         _buildSideChecklist("SISI KANAN", _sisiKanan),
  //         _buildSideChecklist("SISI KIRI", _sisiKiri),
  //         _buildSideChecklist("SISI DEPAN", _sisiDepan),
  //         _buildSideChecklist("SISI BELAKANG", _sisiPintu),
  //         _buildSideChecklist("SISI ATAP", _sisiAtap),
  //         _buildSideChecklist("SISI LANTAI", _sisiLantai),
  //       ],
  //     ),
  //   );
  // }

Widget _buildContainerGrid() {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Jika layar kecil (HP), tampilkan 2 kolom (3 baris)
        // Jika layar lebar (Laptop), tampilkan 6 kolom (1 baris)
        int columns = constraints.maxWidth < 600 ? 2 : 6;
        
        // Atur rasio tinggi kotak: HP perlu lebih tinggi (0.6) agar checkbox tidak sesak
        double ratio = constraints.maxWidth < 600 ? 0.65 : 0.8;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          childAspectRatio: ratio,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _buildSideChecklist("SISI KANAN", _sisiKanan),
            _buildSideChecklist("SISI KIRI", _sisiKiri),
            _buildSideChecklist("SISI DEPAN", _sisiDepan),
            _buildSideChecklist("SISI BELAKANG", _sisiPintu),
            _buildSideChecklist("SISI ATAP", _sisiAtap),
            _buildSideChecklist("SISI LANTAI", _sisiLantai),
          ],
        );
      },
    ),
  );
}

  // Widget _buildSideChecklist(String title, Map<String, bool> sideMap) {
  //   return Card(
  //     elevation: 0,
  //     shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
  //     margin: const EdgeInsets.all(4),
  //     child: Column(
  //       children: [
  //         Container(
  //           width: double.infinity,
  //           padding: const EdgeInsets.all(6),
  //           decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
  //           child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
  //         ),
  //         ...sideMap.keys.map((key) {
  //           return CheckboxListTile(
  //             title: Text(key, style: const TextStyle(fontSize: 10)),
  //             value: sideMap[key],
  //             dense: true,
  //             visualDensity: VisualDensity.compact,
  //             onChanged: (val) => setState(() => sideMap[key] = val!),
  //           );
  //         }),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildSideChecklist(String title, Map<String, bool> sideMap) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Colors.grey.shade300), 
      borderRadius: BorderRadius.circular(8)
    ),
    margin: EdgeInsets.zero, // Gunakan spacing dari GridView saja
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.shade50, 
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8))
          ),
          child: Text(
            title, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)
          ),
        ),
        // Gunakan Expanded agar list checkbox bisa menyesuaikan sisa ruang Card
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: sideMap.keys.map((key) {
              return Theme(
                // Mengecilkan ukuran checkbox agar tidak makan tempat
                data: ThemeData(unselectedWidgetColor: Colors.grey.shade400),
                child: CheckboxListTile(
                  title: Text(
                    key, 
                    style: const TextStyle(fontSize: 10, height: 1.0)
                  ),
                  value: sideMap[key],
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  activeColor: Colors.red.shade700,
                  onChanged: (val) => setState(() => sideMap[key] = val!),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

  // Widget _buildCheckboxGroup(Map<String, bool> map) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 8),
  //     child: Wrap(
  //       children: map.keys.map((key) {
  //         return SizedBox(
  //           width: MediaQuery.of(context).size.width * 0.5 - 12,
  //           child: CheckboxListTile(
  //             title: Text(key, style: const TextStyle(fontSize: 11)),
  //             value: map[key],
  //             dense: true,
  //             controlAffinity: ListTileControlAffinity.leading,
  //             onChanged: (val) => setState(() => map[key] = val!),
  //           ),
  //         );
  //       }).toList(),
        
  //     ),
  //   );
  // }

//   Widget _buildCheckboxGroup(Map<String, bool> map) {
//   return Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 8),
//     child: Column(
//       children: [
//         Wrap(
//           children: [
//             ...map.keys.map((key) {
//               return SizedBox(
//                 width: MediaQuery.of(context).size.width * 0.5 - 12,
//                 child: CheckboxListTile(
//                   title: Text(key, style: const TextStyle(fontSize: 11)),
//                   value: map[key],
//                   dense: true,
//                   controlAffinity: ListTileControlAffinity.leading,
//                   onChanged: (val) => setState(() => map[key] = val!),
//                 ),
//               );
//             }).toList(),
            
//             // Tambahkan Checkbox "Lainnya" secara manual khusus untuk grup ini
//             if (map == _kondisiLain)
//               SizedBox(
//                 width: MediaQuery.of(context).size.width * 0.5 - 12,
//                 child: CheckboxListTile(
//                   title: const Text("Lainnya", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
//                   value: _isKondisiLainLainChecked,
//                   dense: true,
//                   controlAffinity: ListTileControlAffinity.leading,
//                   onChanged: (val) => setState(() => _isKondisiLainLainChecked = val!),
//                 ),
//               ),
//           ],
//         ),
        
//         // Tampilkan TextField jika "Lainnya" dicentang
//         if (map == _kondisiLain && _isKondisiLainLainChecked)
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
//             child: TextField(
//               controller: _kondisiLainManualController,
//               decoration: const InputDecoration(
//                 labelText: "Sebutkan kondisi lainnya...",
//                 labelStyle: TextStyle(fontSize: 12),
//                 border: OutlineInputBorder(),
//                 isDense: true,
//                 hintText: "Misal: Ban gundul, Kaca retak, dll"
//               ),
//               style: const TextStyle(fontSize: 13),
//             ),
//           ),
//       ],
//     ),
//   );
// }

Widget _buildCheckboxGroup(Map<String, bool> map, {bool isKondisiLain = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        Wrap(
          children: [
            ...map.keys.map((key) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.5 - 12,
                child: CheckboxListTile(
                  title: Text(key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  value: map[key],
                  dense: true,
                  activeColor: Colors.red.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) => setState(() => map[key] = val!),
                ),
              );
            }).toList(),
            
            if (map == _kondisiLain)
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.5 - 12,
                child: CheckboxListTile(
                  title: const Text("Lainnya", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  value: _isKondisiLainLainChecked,
                  dense: true,
                  activeColor: Colors.red.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) => setState(() => _isKondisiLainLainChecked = val!),
                ),
              ),
          ],
        ),
        
        if (map == _kondisiLain && _isKondisiLainLainChecked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _kondisiLainManualController,
              decoration: InputDecoration(
                labelText: "Sebutkan kondisi lainnya...",
                labelStyle: const TextStyle(fontSize: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    ),
  );
}
// Widget _buildCheckboxGroup(Map<String, bool> map, {bool isKondisiLain = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       child: Column(
//         children: [
//           Wrap(
//             children: [
//               ...map.keys.map((key) => SizedBox(
//                 width: MediaQuery.of(context).size.width * 0.5 - 12,
//                 child: CheckboxListTile(
//                   title: Text(key, style: const TextStyle(fontSize: 11)),
//                   value: map[key], dense: true, controlAffinity: ListTileControlAffinity.leading,
//                   onChanged: (val) => setState(() => map[key] = val!),
//                 ),
//               )),
//               if (isKondisiLain) SizedBox(
//                 width: MediaQuery.of(context).size.width * 0.5 - 12,
//                 child: CheckboxListTile(
//                   title: const Text("Lainnya", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
//                   value: _isKondisiLainLainChecked, dense: true,
//                   onChanged: (val) => setState(() => _isKondisiLainLainChecked = val!),
//                 ),
//               ),
//             ],
//           ),
//           if (isKondisiLain && _isKondisiLainLainChecked) Padding(
//             padding: const EdgeInsets.all(16),
//             child: TextField(controller: _kondisiLainManualController, decoration: const InputDecoration(labelText: "Kondisi lainnya...", border: OutlineInputBorder(), isDense: true)),
//           ),
//         ],
//       ),
//     );
//   }
Widget _buildTreatmentCheckboxGroup(Map<String, bool> map) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        // Menggunakan Wrap agar checkbox otomatis turun ke baris baru jika tidak cukup
        Wrap(
          children: [
            ...map.keys.map((key) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.5 - 32, // Membagi 2 kolom
                child: CheckboxListTile(
                  title: Text(key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  value: map[key],
                  dense: true,
                  activeColor: Colors.red.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) => setState(() => map[key] = val!),
                ),
              );
            }).toList(),
            
            // Tombol Checkbox "Lainnya" khusus untuk Treatment
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.5 - 32,
              child: CheckboxListTile(
                title: const Text("Lainnya", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                value: _isTreatmentLainLainChecked,
                dense: true,
                activeColor: Colors.red.shade700,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) => setState(() => _isTreatmentLainLainChecked = val!),
              ),
            ),
          ],
        ),
        
//         // Munculkan TextField jika "Lainnya" dicentang
//         if (_isTreatmentLainLainChecked)
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//             child: TextField(
//               controller: _treatmentLainManualController,
//               decoration: InputDecoration(
//                 labelText: "Sebutkan treatment lainnya...",
//                 labelStyle: const TextStyle(fontSize: 12),
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//                 border: const OutlineInputBorder(),
//                 isDense: true,
//                 hintText: "Contoh: Pengecekan ulang sensor, dll"
//               ),
//               style: const TextStyle(fontSize: 13),
//             ),
//           ),
//       ],
//     ),
//   );
// }
if (_isTreatmentLainLainChecked) Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(controller: _treatmentLainManualController, decoration: const InputDecoration(labelText: "Treatment lainnya...", border: OutlineInputBorder(), isDense: true)),
          ),
        ],
      ),
    );
  }

// Widget _buildCheckboxGroup(Map<String, bool> map) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       child: Column(
//         children: [
//           Wrap(
//             children: [
//               ...map.keys.map((key) {
//                 return SizedBox(
//                   width: MediaQuery.of(context).size.width * 0.5 - 32, // Penyesuaian lebar dalam card
//                   child: CheckboxListTile(
//                     title: Text(key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
//                     value: map[key],
//                     dense: true,
//                     activeColor: Colors.red.shade700,
//                     controlAffinity: ListTileControlAffinity.leading,
//                     onChanged: (val) => setState(() => map[key] = val!),
//                   ),
//                 );
//               }).toList(),
              
//               // Logika khusus untuk checkbox "Lainnya" di bagian Kondisi Tidak Standar
//               if (map == _kondisiLain)
//                 SizedBox(
//                   width: MediaQuery.of(context).size.width * 0.5 - 32,
//                   child: CheckboxListTile(
//                     title: const Text("Lainnya", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
//                     value: _isKondisiLainLainChecked,
//                     dense: true,
//                     activeColor: Colors.red.shade700,
//                     controlAffinity: ListTileControlAffinity.leading,
//                     onChanged: (val) => setState(() => _isKondisiLainLainChecked = val!),
//                   ),
//                 ),
//             ],
//           ),
          
//           if (map == _kondisiLain && _isKondisiLainLainChecked)
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//               child: TextField(
//                 controller: _kondisiLainManualController,
//                 decoration: InputDecoration(
//                   labelText: "Sebutkan kondisi lainnya...",
//                   labelStyle: const TextStyle(fontSize: 12),
//                   filled: true,
//                   fillColor: Colors.grey.shade50,
//                   border: const OutlineInputBorder(),
//                   isDense: true,
//                 ),
//                 style: const TextStyle(fontSize: 13),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

  // Widget _buildSafetyFactor() {
  //   return Padding(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text("Dokumen Pendukung:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  //         _buildCheckboxGroup(_dokumen),
  //         const SizedBox(height: 15),
  //         const Text("Ganjal Roda:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  //         _buildRadioGroup(['Standard', 'Tidak Standard', 'Tidak Ada'], _ganjalRoda, (v) => setState(() => _ganjalRoda = v)),
  //         const SizedBox(height: 15),
  //         const Text("Rem / Hand Rem:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  //         _buildRadioGroup(['Hand Rem OK', 'Tidak Ada/Rusak'], _remHandRem, (v) => setState(() => _remHandRem = v)),
  //         const SizedBox(height: 15),
  //         const Text("APD Supir:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  //         _buildCheckboxGroup(_apd),
  //       ],
  //     ),
  //   );
  // }
Widget _buildSafetyFactor() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kategori Dokumen
        _buildSafetyItemCard(
          title: "DOKUMEN PENDUKUNG",
          icon: Icons.assignment_turned_in_outlined,
          content: _buildCheckboxGroup(_dokumen),
        ),
        const SizedBox(height: 12),
        
        // Kategori Ganjal Roda
        _buildSafetyItemCard(
          title: "GANJAL RODA",
          icon: Icons.stop_circle_outlined,
          content: _buildModernRadioGroup(
            ['1 Standard','2 Standard', '1 Tidak Standard', '2 Tidak Standard','Tidak Ada'], 
            _ganjalRoda, 
            (v) => setState(() => _ganjalRoda = v)
          ),
        ),
        const SizedBox(height: 12),

        // Kategori Rem
        _buildSafetyItemCard(
          title: "REM / HAND REM",
          icon: Icons.pan_tool_alt_outlined,
          content: _buildModernRadioGroup(
            ['Hand Rem', 'Tidak Ada/Tidak Standard'], 
            _remHandRem, 
            (v) => setState(() => _remHandRem = v)
          ),
        ),
        const SizedBox(height: 12),

        // Kategori APD
        _buildSafetyItemCard(
          title: "APD SUPIR",
          icon: Icons.shield_outlined,
          content: _buildCheckboxGroup(_apd),
        ),
      ],
    ),
  );
}

// Widget _buildSafetyItemCard({required String title, required IconData icon, required Widget content}) {
//   return Container(
//     width: double.infinity,
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(10),
//       border: Border.all(color: Colors.grey.shade300, width: 1),
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Header Kecil
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             color: Colors.grey.shade50,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
//             border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
//           ),
//           child: Row(
//             children: [
//               Icon(icon, size: 16, color: Colors.blueGrey.shade700),
//               const SizedBox(width: 8),
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.blueGrey.shade800,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // Konten (Checkbox/Radio)
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8),
//           child: content,
//         ),
//       ],
//     ),
//   );
// }
Widget _buildSafetyItemCard({required String title, required IconData icon, required Widget content}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.blueGrey.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: content,
          ),
        ],
      ),
    );
  }
Widget _buildModernRadioGroup(List<String> options, String? groupVal, Function(String?) onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        bool isSelected = groupVal == opt;
        Color activeColor = opt.contains('Tidak') || opt.contains('Rusak') 
            ? Colors.red.shade700 
            : Colors.green.shade700;

        return InkWell(
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? activeColor : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: isSelected ? activeColor : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  opt,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? activeColor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
}
  Widget _buildRadioGroup(List<String> options, String? groupVal, Function(String?) onChanged) {
    return Wrap(
      spacing: 5,
      children: options.map((opt) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(value: opt, groupValue: groupVal, onChanged: onChanged, visualDensity: VisualDensity.compact),
            Text(opt, style: const TextStyle(fontSize: 11)),
          ],
        );
      }).toList(),
    );
  }

  // Widget _buildDecisionSection() {
  //   return Column(
  //     children: [
  //       _buildDecisionTile('LAYAK SESUAI STANDAR', 'LAYAK', Colors.green),
  //       _buildDecisionTile('LAYAK SETELAH TREATMENT', 'LAYAK SETELAH TREATMENT', Colors.orange),
  //       _buildDecisionTile('DITOLAK', 'DITOLAK', Colors.red),
  //     ],
  //   );
  // }
  Widget _buildDecisionSection() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _buildModernDecisionCard(
          label: 'LAYAK SESUAI STANDAR',
          value: 'LAYAK',
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade700,
        ),
        const SizedBox(height: 10),
        _buildModernDecisionCard(
          label: 'LAYAK SETELAH TREATMENT',
          value: 'LAYAK SETELAH TREATMENT',
          icon: Icons.published_with_changes_rounded,
          color: Colors.orange.shade800,
        ),
        const SizedBox(height: 10),
        _buildModernDecisionCard(
          label: 'UNIT DITOLAK (REJECT)',
          value: 'DITOLAK',
          icon: Icons.cancel_rounded,
          color: Colors.red.shade800,
        ),
      ],
    ),
  );
}

Widget _buildModernDecisionCard({
  required String label,
  required String value,
  required IconData icon,
  required Color color,
}) {
  bool isSelected = _decision == value;

  return InkWell(
    onTap: () => setState(() => _decision = value),
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
            : [],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : color,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
        ],
      ),
    ),
  );
}

  Widget _buildDecisionTile(String label, String value, Color color) {
    return RadioListTile<String>(
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      value: value,
      groupValue: _decision,
      onChanged: (v) => setState(() => _decision = v),
    );
  }

  Widget _buildCatatanField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _catatanController,
        maxLines: 3,
        decoration: const InputDecoration(labelText: "Catatan Inspeksi", border: OutlineInputBorder(), hintText: "Tambahkan catatan jika ada..."),
      ),
    );
  }

  // Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
  //   return TextFormField(
  //     controller: controller,
  //     keyboardType: isNumber ? TextInputType.number : TextInputType.text,
  //     decoration: InputDecoration(
  //       labelText: label,
  //       prefixIcon: Icon(icon, size: 20),
  //       border: const OutlineInputBorder(),
  //       isDense: true,
  //     ),
  //     validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
  //   );
  // }

// Widget _buildTextField(
//   TextEditingController controller, 
//   String label, {
//   bool isNumber = false, 
//   bool isUpperCase = false,
//   int? maxLength,
// }) {
//   return Padding(
//     padding: const EdgeInsets.only(bottom: 10),
//     child: TextField(
//       controller: controller,
//       // Jika isNumber true, keyboard akan muncul angka saja
//       keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//       // Memaksa huruf besar saat mengetik
//       textCapitalization: isUpperCase ? TextCapitalization.characters : TextCapitalization.none,
//       inputFormatters: [
//         // Jika isNumber true, hanya angka yang bisa masuk
//         if (isNumber) FilteringTextInputFormatter.digitsOnly,
//         // Jika ada batas karakter (misal No Polisi atau Tahun)
//         if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
//       ],
//       decoration: InputDecoration(
//         labelText: label,
//         border: const OutlineInputBorder(),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       ),
      
//     ),
    
//   );
// }

// Widget _buildTextField(
//   TextEditingController controller, 
//   String label, {
//   bool isNumber = false, 
//   bool isUpperCase = false,
//   int? maxLength,
// }) {
//   return Padding(
//     padding: const EdgeInsets.only(bottom: 10),
//     child: TextFormField( // Gunakan TextFormField agar validator berfungsi
//       controller: controller,
//       keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//       // Memaksa keyboard mode huruf kapital
//       textCapitalization: isUpperCase ? TextCapitalization.characters : TextCapitalization.none,
//       inputFormatters: [
//         // Hanya izinkan angka jika isNumber true
//         if (isNumber) FilteringTextInputFormatter.digitsOnly,
//         // Batasi jumlah karakter jika maxLength diisi
//         if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
//       ],
//       decoration: InputDecoration(
//         labelText: label,
//         border: const OutlineInputBorder(),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//         isDense: true,
//       ),
//       // Balikkan validatornya ke sini
//       validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
//     ),
//   );
// }
Widget _buildTextField(
  TextEditingController controller, 
  String label, {
  bool isNumber = false, 
  bool isUpperCase = false,
  int? maxLength,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10), // Memberi jarak antar field agar pesan error punya ruang
    child: TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      textCapitalization: isUpperCase ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters: [
        if (isNumber) FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      // Gunakan style ini agar teks error tidak berantakan
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        border: const OutlineInputBorder(),
        // Jangan terlalu tipis (isDense) jika menggunakan validator
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), 
        errorStyle: const TextStyle(fontSize: 11, height: 0.8), // Mengatur kerapatan teks error
        counterText: "", // Menghilangkan counter teks jika memakai maxLength
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return "Wajib diisi";
        }
        return null;
      },
    ),
  );
}
  // Widget _buildDetailedSummary() {
  //   final request = _shippingData?['request'] ?? {};
  //   final bool isGroup = request['group_id'] != null;
  //   final List dos = request['delivery_order'] ?? [];
  //   final warehouse = request['warehouse'];
  //   String warehouseDisplay = warehouse != null ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" : "-";

  //   return Container(
  //     decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: isGroup ? Colors.blue.shade700 : Colors.red.shade700, width: 6))),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(isGroup ? "📦 GROUP SHIPMENT" : "🚚 SINGLE SHIPMENT", style: TextStyle(fontWeight: FontWeight.bold, color: isGroup ? Colors.blue.shade900 : Colors.red.shade900, fontSize: 11)),
  //               const SizedBox(height: 8),
  //               Text(isGroup ? "ID Grup: ${request['group_id']}" : "ID Shipping: ${request['shipping_id']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //               const SizedBox(height: 16),
  //               Row(
  //                 children: [
  //                   _infoBox("Stuffing Date", _formatDate(request['stuffing_date'])),
  //                   const Spacer(),
  //                   _buildBadge(warehouseDisplay.toUpperCase(), Colors.red.shade700),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         ...dos.map((doItem) {
  //           final String rddSpesifik = _formatDate(doItem['rdd_origin']);
  //           return Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //             child: Text("DO: ${doItem['do_number']} | RDD: $rddSpesifik", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  //           );
  //         }).toList(),
  //       ],
  //     ),
  //   );
  // }


  Widget _buildDetailedSummary() {
    //final data = _shippingData ?? {};
final data = _shippingData ?? widget.item;
    final request = data['request'] ?? {};

    final bool isGroup = request['group_id'] != null;

    final List dos = request['delivery_order'] ?? [];
// Ambil RDD dan SO dari level request (shipping_request)
    final String rddGlobal = _formatDate(request['rdd']);
    final String soGlobal = request['so']?.toString() ?? "-";
    final warehouse = request['warehouse'];

    String warehouseDisplay = warehouse != null 

        ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}" 

        : "-";

// AMBIL DATA DETAIL VENDOR DARI HASIL JOIN SHIPPING REQUEST / ASSIGNMENTS
    // Menyesuaikan struktur data map penugasan aktif dari widget.item
    Map<String, dynamic>? vendorDetails;
   // Cek di root data (untuk single)
    if (data['vendor_transportasi'] != null) {
      vendorDetails = data['vendor_transportasi'];
    } 
    // Cek di dalam request -> assignments (untuk group)
    else if (request['shipping_assignments'] != null && (request['shipping_assignments'] as List).isNotEmpty) {
      // Ambil dari assignment pertama dalam list
      var firstAssign = request['shipping_assignments'][0];
      vendorDetails = firstAssign['vendor_transportasi'];
    }
    // Cek jika vendor_transportasi malah ada di dalam request langsung
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
                    // _infoBox("Dedicated", (data['is_dedicated'] ?? "-").toString().toUpperCase()),
                    _infoBox("Type Unit", vUnit),
                    _infoBox("City", vCity),
                    _infoBox("Area", vArea),

                    //const Spacer(),

                    // _buildBadge(warehouseDisplay.toUpperCase(), Colors.red.shade700),

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

            // final String soNum = doItem['so']?.toString() ?? 
            //                    doItem['parent_so']?.toString() ?? 
            //                    "-";

            // final String rddSpesifik = _formatDate(doItem['rdd_origin']);



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

                        }).toList(),

                      ],

                    ),

                  ),

                  const SizedBox(height: 12),

                  const Divider(height: 1),

                ],

              ),

            );

          }).toList(),

        ],

      ),

    );

  }
  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitCheckIn,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("SIMPAN HASIL INSPEKSI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildLateWarning() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text("Terlambat: ${widget.lateReason}", style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
 Widget _infoBox(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))]));
  // Widget _infoBox(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]);
  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) => Padding(padding: const EdgeInsets.all(8), child: Text(text, textAlign: align, style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
  Widget _buildBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)), child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)));
  void _showSnackBar(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  String _formatDate(String? s) => s == null || s.isEmpty ? "-" : DateFormat('dd/MM/yy').format(DateTime.parse(s));
}