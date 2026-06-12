import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorAccountsPage extends StatefulWidget {
  const VendorAccountsPage({super.key});

  @override
  State<VendorAccountsPage> createState() => _VendorAccountsPageState();
}

class _VendorAccountsPageState extends State<VendorAccountsPage> {
  final supabase = Supabase.instance.client;
  bool _isVendorLoading = true;
  bool _isAccountLoading = false;

  List<Map<String, dynamic>> _masterVendors = [];
  Map<String, dynamic>? _selectedVendor; // Vendor aktif yang diklik
  List<Map<String, dynamic>> _vendorAccounts = []; // Akun profiles milik vendor aktif

  @override
  void initState() {
    super.initState();
    _fetchMasterVendors();
  }

  // --- 1. AMBIL MASTER VENDOR (PANEL KIRI) ---
  Future<void> _fetchMasterVendors() async {
    setState(() => _isVendorLoading = true);
    try {
      final data = await supabase.from('master_vendor').select().order('vendor_name', ascending: true);
      setState(() {
        _masterVendors = List<Map<String, dynamic>>.from(data);
        _isVendorLoading = false;
      });
    } catch (e) {
      _showSnackBar("Gagal memuat master vendor: $e", Colors.red);
      setState(() => _isVendorLoading = false);
    }
  }

  // --- 2. AMBIL AKUN PROFILES VENDOR (PANEL KANAN) ---
  Future<void> _fetchVendorAccounts(String nik) async {
    setState(() => _isAccountLoading = true);
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('nik_vendor', nik) // Relasi ke master_vendor (nik)
          .order('created_at', ascending: false);
      setState(() {
        _vendorAccounts = List<Map<String, dynamic>>.from(data);
        _isAccountLoading = false;
      });
    } catch (e) {
      _showSnackBar("Gagal memuat akun vendor: $e", Colors.red);
      setState(() => _isAccountLoading = false);
    }
  }

  // --- 3. AKSI: TOGGLE STATUS AKTIF (is_active) ---
  Future<void> _toggleAccountStatus(String profileId, bool currentStatus) async {
    try {
      await supabase
          .from('profiles')
          .update({'is_active': !currentStatus})
          .eq('id', profileId);

      _showSnackBar("Status akun berhasil diperbarui", Colors.green);
      if (_selectedVendor != null) {
        _fetchVendorAccounts(_selectedVendor!['nik']);
      }
    } catch (e) {
      _showSnackBar("Gagal mengubah status akun: $e", Colors.red);
    }
  }

  // --- 4. AKSI: HAPUS AKUN (Trigger CASCADE ke auth.users via handle_delete_user_auth) ---
  Future<void> _deleteVendorAccount(String profileId) async {
    try {
      // Menghapus record di public.profiles otomatis memicu trigger_delete_auth_user Anda
      await supabase.from('profiles').delete().eq('id', profileId);

      _showSnackBar("Akun vendor berhasil dihapus", Colors.redAccent);
      if (_selectedVendor != null) {
        _fetchVendorAccounts(_selectedVendor!['nik']);
      }
    } catch (e) {
      _showSnackBar("Gagal menghapus akun: $e", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Manajemen Akun Login Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      //   backgroundColor: Colors.blueGrey.shade800,
      //   foregroundColor: Colors.white,
      // ),
      body: _isVendorLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // =======================================================
                // 🏢 PANEL KIRI: DAFTAR MASTER VENDOR (FLEX 2)
                // =======================================================
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Daftar Vendor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _showAddMasterVendorDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text("Vendor Baru"),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _masterVendors.isEmpty
                              ? const Center(child: Text("Belum ada data vendor."))
                              : ListView.separated(
                                  itemCount: _masterVendors.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final vendor = _masterVendors[index];
                                    final isSelected = _selectedVendor?['nik'] == vendor['nik'];

                                    return ListTile(
                                      selected: isSelected,
                                      selectedTileColor: Colors.blueGrey.shade50,
                                      selectedColor: Colors.blueGrey.shade900,
                                      title: Text(vendor['vendor_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text("NIK: ${vendor['nik']} \nCode: ${vendor['regist_code'] ?? '-'}"),
                                      isThreeLine: true,
                                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isSelected ? Colors.blueGrey.shade700 : Colors.grey),
                                      onTap: () {
                                        setState(() {
                                          _selectedVendor = vendor;
                                        });
                                        _fetchVendorAccounts(vendor['nik']);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =======================================================
                // 👥 PANEL KANAN: MANAJEMEN AKUN PROFILES VENDOR (FLEX 3)
                // =======================================================
                Expanded(
                  flex: 3,
                  child: _selectedVendor == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.manage_accounts_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text("Pilih vendor di sebelah kiri\nuntuk memanajemen hak akses login (Profiles)",
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Header Informasi Vendor Terpilih
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              color: Colors.grey.shade100,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blueGrey.shade100,
                                    child: Icon(Icons.business, color: Colors.blueGrey.shade900),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedVendor!['vendor_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text("NIK Vendor Terkunci: ${_selectedVendor!['nik']}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            
                            // Daftar User Terdaftar (Profiles)
                            Expanded(
                              child: _isAccountLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _vendorAccounts.isEmpty
                                      ? const Center(child: Text("Belum ada akun login yang terdaftar untuk vendor ini."))
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: _vendorAccounts.length,
                                          itemBuilder: (context, index) {
                                            final profile = _vendorAccounts[index];
                                            final bool isActive = profile['is_active'] ?? false;

                                            return Card(
                                              elevation: 2,
                                              margin: const EdgeInsets.only(bottom: 12),
                                              child: Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text(profile['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                              const SizedBox(width: 8),
                                                              // Badge Status IsActive
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Text(
                                                                  isActive ? "AKTIF" : "NON-AKTIF",
                                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.green.shade800 : Colors.red.shade800),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text("Email: ${profile['email']}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                                          Text("Role: ${profile['role'] ?? 'Guest'}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                                        ],
                                                      ),
                                                    ),
                                                    
                                                    // TOMBOL AKSI: Block / Unblock Status Akun
                                                    IconButton(
                                                      tooltip: isActive ? "Non-aktifkan Akun" : "Aktifkan Akun",
                                                      icon: Icon(
                                                        isActive ? Icons.block : Icons.check_circle_outline,
                                                        color: isActive ? Colors.orange.shade800 : Colors.green,
                                                      ),
                                                      onPressed: () => _toggleAccountStatus(profile['id'], isActive),
                                                    ),
                                                    
                                                    // TOMBOL AKSI: Hapus Akun Total
                                                    IconButton(
                                                      tooltip: "Hapus Akun Permanen",
                                                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                                                      onPressed: () => _showConfirmDeleteDialog(profile['id'], profile['name'] ?? 'No Name'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  // =======================================================
  // 💾 DIALOG POPUP: INPUT MASTER VENDOR BARU
  // =======================================================
  void _showAddMasterVendorDialog() {
    final nikController = TextEditingController();
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registrasi Master Vendor"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nikController, decoration: const InputDecoration(labelText: "NIK Vendor * (Primary Key)", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nama Perusahaan/Vendor *", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: codeController, decoration: const InputDecoration(labelText: "Registration Code *", border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              if (nikController.text.trim().isEmpty || nameController.text.trim().isEmpty) {
                _showSnackBar("NIK dan Nama wajib diisi!", Colors.orange);
                return;
              }
              try {
                await supabase.from('master_vendor').insert({
                  'nik': nikController.text.trim(),
                  'vendor_name': nameController.text.trim(),
                  'regist_code': codeController.text.trim(),
                });
                Navigator.pop(context);
                _showSnackBar("Master Vendor berhasil disimpan!", Colors.green);
                _fetchMasterVendors();
              } catch (e) {
                _showSnackBar("Gagal menyimpan: $e", Colors.red);
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // 💾 DIALOG KONFIRMASI: HAPUS AKUN TOTAL
  // =======================================================
  void _showConfirmDeleteDialog(String profileId, String profileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Akun Login?"),
        content: Text("Apakah Anda yakin ingin menghapus akun milik '$profileName'? \n\nAksi ini akan memicu trigger database untuk menghapus kredensial login (Auth) secara permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _deleteVendorAccount(profileId);
            },
            child: const Text("Ya, Hapus Permanen"),
          ),
        ],
      ),
    );
  }
}