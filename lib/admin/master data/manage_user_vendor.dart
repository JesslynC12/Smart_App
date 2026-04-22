// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class VendorManagementPage extends StatefulWidget {
  const VendorManagementPage({super.key});


  @override
  State<VendorManagementPage> createState() => _VendorManagementPageState();
}

class _VendorManagementPageState extends State<VendorManagementPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription? _vendorSubscription;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _namaPerusahaanController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();

  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
    _fetchVendors();
  }

void _setupRealtimeSubscription() {
    setState(() => _isLoading = true);
    _vendorSubscription = supabase
        .from('profiles_vendor')
        .stream(primaryKey: ['id'])
         .listen((_) {
          _fetchVendors(); // Setiap ada insert/update/delete, ambil data terbaru
        });
          
  }

  @override
  void dispose() {
    _searchController.dispose();
    _namaPerusahaanController.dispose();
    _alamatController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _nikController.dispose();
    super.dispose();
  }

  Future<void> _fetchVendors() async {
    // if (!mounted) return;
    // setState(() => _isLoading = true);
    try {
      // Mengambil data vendor yang terverifikasi beserta status is_active dari tabel profiles
      var query = supabase
          .from('profiles_vendor')
          .select('*, profiles(email, name, nik, is_active)')
          .eq('status', 'verified');

      if (_searchQuery.isNotEmpty) {
        query = query.or('nama_perusahaan.ilike.%$_searchQuery%, city.ilike.%$_searchQuery%');
      }

      final data = await query.order('nama_perusahaan', ascending: true);

      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengambil data vendor: $e"))
        );
      }
    }
  }

  // Fungsi untuk mengubah status is_active di tabel profiles
  Future<void> _handleToggleStatus(String profileId, bool currentStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );


    try {
      
      // Update is_active menjadi kebalikan dari status saat ini
      final response = await supabase
          .from('profiles')
          .update({'is_active': !currentStatus})
          .eq('id', profileId)
          .select();

          if (response.isEmpty) {
      throw "Update gagal: Data tidak ditemukan atau RLS memblokir akses.";
    }

    print("Berhasil Update: ${response[0]}");

      if (mounted) {
        Navigator.pop(context); // Tutup loading
        _fetchVendors(); // Refresh data dari DB
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
            content: Text(!currentStatus ? "Vendor berhasil Diaktifkan" : "Vendor berhasil Dinonaktifkan")
          )
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("Gagal mengubah status: $e"))
      );
    }
  }

  Future<void> _updateVendor(String profileId) async {
    try {
      await supabase.from('profiles_vendor').update({
        'nama_perusahaan': _namaPerusahaanController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'city': _cityController.text.trim(),
        'phone': _phoneController.text.trim(),
      }).eq('profile_id', profileId);

      if (mounted) {
        Navigator.pop(context);
        _fetchVendors();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("Data detail vendor diperbarui"))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.toString()))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = VendorDataSource(
      _vendors,
      context,
      onEdit: (vendor) => _showEditVendorDialog(vendor),
      onToggle: (id, currentStatus) => _handleToggleStatus(id, currentStatus),
    );

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Manajemen Vendor Terverifikasi"),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: "Cari NIK, Nama Perusahaan, atau Kota...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (val) {
                      _searchQuery = val;
                      _fetchVendors();
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      rowsPerPage: 10,
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('NIK', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Perusahaan', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Alamat', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Kota', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Telepon', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status Akun', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      source: source,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showEditVendorDialog(Map<String, dynamic> vendor) {
    final profile = vendor['profiles'] as Map<String, dynamic>?;
    _nikController.text = profile?['nik'] ?? "-";
    _namaPerusahaanController.text = vendor['nama_perusahaan'] ?? "";
    _alamatController.text = vendor['alamat'] ?? "";
    _cityController.text = vendor['city'] ?? "";
    _phoneController.text = vendor['phone'] ?? "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Informasi Vendor"),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField("NIK (Read Only)", _nikController, enabled: false, icon: Icons.badge),
                const SizedBox(height: 15),
                _buildField("Nama Perusahaan", _namaPerusahaanController, icon: Icons.business),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildField("Kota", _cityController, icon: Icons.location_city)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildField("Telepon", _phoneController, icon: Icons.phone)),
                  ],
                ),
                const SizedBox(height: 15),
                _buildField("Alamat", _alamatController, maxLines: 3, icon: Icons.map),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => _updateVendor(vendor['profile_id']),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1, bool enabled = true, IconData? icon}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
        isDense: true,
      ),
    );
  }
}

class VendorDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String, bool) onToggle;

  VendorDataSource(this.data, this.context, {required this.onEdit, required this.onToggle});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final vendor = data[index];
    final profile = vendor['profiles'] as Map<String, dynamic>?;
    
    // Logika Status Aktif berdasarkan kolom is_active di tabel profiles
    final bool isActive = profile?['is_active'] ?? true;

    return DataRow(
      // Memberikan warna background abu-abu jika is_active = false
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isActive ? null : Colors.grey.shade200,
      ),
      cells: [
        DataCell(Text(profile?['nik'] ?? '-')),
        DataCell(Text(vendor['nama_perusahaan'] ?? '-')),
        DataCell(Text(profile?['email'] ?? '-')),
        DataCell(
          SizedBox(
            width: 180,
            child: Text(vendor['alamat'] ?? '-', overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ),
        DataCell(Text(vendor['city'] ?? '-')),
        DataCell(Text(vendor['phone'] ?? '-')),
        DataCell(
          // UI Kolom Status (Menampilkan Aktif/Non-Aktif)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              isActive ? "AKTIF" : "NON-AKTIF",
              style: TextStyle(
                color: isActive ? Colors.green.shade900 : Colors.red.shade900,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => onEdit(vendor),
            ),
            IconButton(
              // Icon dinamis berdasarkan status aktif/non-aktif
              icon: Icon(
                isActive ? Icons.block : Icons.check_circle_outline,
                color: isActive ? Colors.orange : Colors.green,
              ),
              onPressed: () => _showConfirmToggle(vendor['profile_id'], isActive),
              tooltip: isActive ? "Non-aktifkan" : "Aktifkan",
            ),
          ],
        )),
      ],
    );
  }

  void _showConfirmToggle(String id, bool currentStatus) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(currentStatus ? "Non-aktifkan Akun?" : "Aktifkan Akun?"),
        content: Text(currentStatus
            ? "Vendor ini tidak akan bisa login ke aplikasi jika dinonaktifkan."
            : "Vendor akan bisa kembali menggunakan akses login mereka."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange : Colors.green,
            ),
            onPressed: () {
              Navigator.pop(c);
              onToggle(id, currentStatus);
            },
            child: Text(
              currentStatus ? "Non-aktifkan" : "Aktifkan",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => data.length;
  @override
  int get selectedRowCount => 0;
}