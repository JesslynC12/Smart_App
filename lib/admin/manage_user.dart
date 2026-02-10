import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Pastikan path import ini benar sesuai struktur folder Anda
import '../auth/auth_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  // Variabel State
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _masterPrivileges = []; // Data Privilege dari DB
  bool _isLoading = true;

  // Controller Form
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? selectedRole;
  // Kita simpan ID privilege (integer)
  final Set<int> selectedPrivilegeIds = {};

  final List<String> roles = ['admin', 'supervisor', 'ppic', 'logistik', 'gudang', 'satpam'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ===================== LOGIKA SUPABASE =====================

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. Ambil Data User beserta Privilege-nya (Join Table)
      final userData = await supabase
          .from('profiles')
          .select('*, profile_privileges(privileges(name))')
          
          // --- TAMBAHKAN FILTER DISINI ---
          .neq('role', 'vendor')  // Filter 1: Jangan ambil yang role-nya 'vendor' (huruf kecil)
          .neq('role', 'VENDOR')  // Filter 2: Jaga-jaga jika ada 'VENDOR' (huruf besar) di database lama
          
          .order('nik', ascending: true);

      // 2. Ambil Master Data Privileges untuk Checkbox
      final privData = await AuthService.getAvailablePrivileges();

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(userData);
          _masterPrivileges = List<Map<String, dynamic>>.from(privData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _saveUser() async {
    // Validasi Form Kosong
    if (_nikController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap lengkapi semua data!")),
      );
      return;
    }

    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Panggil fungsi register dari AuthService
      await AuthService.registerInternalUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        nik: _nikController.text.trim(),
        role: selectedRole!,
        privilegeIds: selectedPrivilegeIds.toList(),
      );

      // Jika sukses, tutup dialog dan refresh
      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        Navigator.pop(context); // Tutup Form Dialog
      }

      _clearForm();
      _fetchData(); // Refresh tabel

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("User Berhasil Didaftarkan"),
        ),
      );
    } catch (e) {
      // --- INI BAGIAN CATCH YANG ANDA MINTA ---
      if (mounted) Navigator.pop(context); // Tutup Loading

      String errorMessage = "Gagal mendaftarkan user.";
      String errorString = e.toString();

      // Cek pesan error spesifik dari Supabase Auth
      if (errorString.contains("User already registered")) {
        errorMessage = "Email ini sudah terdaftar. Silakan gunakan email lain atau hapus user lama di Authentication Supabase.";
      } else if (errorString.contains("NIK sudah terdaftar")) {
        errorMessage = "NIK ini sudah digunakan oleh pegawai lain.";
      } else if (errorString.contains("Password should be at least")) {
        errorMessage = "Password minimal 6 karakter.";
      } else {
        errorMessage = "Error: $e";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(errorMessage)),
      );
    }
  }


  Future<void> _deleteUser(String userId) async {
    try {
      await Supabase.instance.client.from('profiles').delete().eq('id', userId);

      _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data berhasil dihapus")),
      );
    } catch (e) {
      debugPrint("Error Delete: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _clearForm() {
    _nikController.clear();
    _emailController.clear();
    _passwordController.clear();
    selectedRole = null;
    selectedPrivilegeIds.clear();
  }

  // ===================== UI BUILDER =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen User", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildUserTable(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FixedColumnWidth(100), // NIK
            1: FixedColumnWidth(200), // Email
            2: FixedColumnWidth(100), // Role
            3: FixedColumnWidth(250), // Hak Akses
            4: FixedColumnWidth(60),  // Aksi
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.red.shade50),
              children: const [
                _TableHeaderText('NIK'),
                _TableHeaderText('Email'),
                _TableHeaderText('Role'),
                _TableHeaderText('Hak Akses'),
                _TableHeaderText('Aksi'),
              ],
            ),
            ..._users.map((user) {
              final List rawPrivs = user['profile_privileges'] ?? [];
              final String privString = rawPrivs.isNotEmpty
                  ? rawPrivs.map((item) => item['privileges']['name'].toString()).join(', ')
                  : '-';

              return TableRow(
                children: [
                  _TableCellText(user['nik']?.toString() ?? "-"),
                  _TableCellText(user['email']?.toString() ?? "-"),
                  _TableCellText(user['role']?.toString().toUpperCase() ?? "-"),
                  _TableCellText(privString),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _showConfirmDelete(user['id'], user['nik']),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    _clearForm();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Tambah User Baru"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField("NIK", Icons.badge, _nikController),
                  const SizedBox(height: 12),
                  _buildTextField("Email", Icons.email, _emailController),
                  const SizedBox(height: 12),
                  _buildTextField("Password", Icons.lock, _passwordController, isPassword: true),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    label: "Pilih Role",
                    icon: Icons.admin_panel_settings,
                    items: roles,
                    value: selectedRole,
                    onChanged: (val) => setDialogState(() => selectedRole = val),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Pilih Hak Akses:", style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),

                  // LIST CHECKBOX DINAMIS DARI DATABASE
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: _masterPrivileges.isEmpty
                        ? const Padding(padding: EdgeInsets.all(10), child: Text("Master data fitur kosong."))
                        : Column(
                            children: _masterPrivileges.map((priv) {
                              final int pId = priv['id'];
                              final String pName = priv['name']; // Gunakan name karena tidak ada label

                              return CheckboxListTile(
                                title: Text(pName, style: const TextStyle(fontSize: 14)),
                                value: selectedPrivilegeIds.contains(pId),
                                activeColor: Colors.red.shade700,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (bool? val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedPrivilegeIds.add(pId);
                                    } else {
                                      selectedPrivilegeIds.remove(pId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
              onPressed: _saveUser,
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDelete(String id, String nik) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Data?"),
        content: Text("Yakin ingin menghapus user dengan NIK $nik?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(id);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===================== HELPERS =====================

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder(), isDense: true),
    );
  }

  Widget _buildDropdownField(
      {required String label,
      required IconData icon,
      required List<String> items,
      required String? value,
      required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder(), isDense: true),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
            hintText: "Cari NIK atau Email...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
            contentPadding: EdgeInsets.zero),
      ),
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  final String text;
  const _TableHeaderText(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(10), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));
}

class _TableCellText extends StatelessWidget {
  final String text;
  const _TableCellText(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(10), child: Text(text));
}