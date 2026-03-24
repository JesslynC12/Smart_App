import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RejectedVendorPage extends StatefulWidget {
  final Map<String, dynamic> vendorData;
  const RejectedVendorPage({super.key, required this.vendorData});

  @override
  State<RejectedVendorPage> createState() => _RejectedVendorPageState();
}

class _RejectedVendorPageState extends State<RejectedVendorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    // Pre-fill dengan data lama agar vendor tinggal memperbaiki yang salah
    _nameController = TextEditingController(text: widget.vendorData['nama_perusahaan']);
    _addressController = TextEditingController(text: widget.vendorData['alamat']);
    _phoneController = TextEditingController(text: widget.vendorData['phone']);
  }

  Future<void> _resubmitData() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await Supabase.instance.client.from('profiles_vendor').update({
        'nama_perusahaan': _nameController.text,
        'alamat': _addressController.text,
        'phone': _phoneController.text,
        'status': 'pending', // Balikkan status ke pending
        'notes': null,       // Hapus alasan penolakan lama
      }).eq('profile_id', widget.vendorData['profile_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data berhasil diajukan ulang! Silahkan tunggu verifikasi.")),
        );
        // Logout otomatis setelah submit agar admin bisa verifikasi ulang
        await Supabase.instance.client.auth.signOut();
        Navigator.of(context).pushReplacementNamed('/login'); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pendaftaran Ditolak"), backgroundColor: Colors.red),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BOX ALASAN PENOLAKAN
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Alasan Penolakan:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 5),
                    Text(widget.vendorData['notes'] ?? "Data tidak sesuai kriteria.", style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text("Silahkan perbaiki data di bawah ini:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Nama Perusahaan", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: "Alamat", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: "No. Telepon", border: OutlineInputBorder())),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                  onPressed: _resubmitData,
                  child: const Text("AJUKAN ULANG DATA"),
                ),
              ),
              TextButton(
                onPressed: () => Supabase.instance.client.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')),
                child: const Center(child: Text("Keluar / Logout")),
              )
            ],
          ),
        ),
      ),
    );
  }
}