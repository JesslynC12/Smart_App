import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/auth_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  // Variabel State
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _masterPrivileges = [];
  bool _isLoading = true;
  String _searchQuery = "";

  // Controller Form
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? selectedRole;
  final Set<int> selectedPrivilegeIds = {};
  final List<String> roles = ['admin', 'supervisor', 'ppic', 'logistik', 'gudang', 'satpam'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nikController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ===================== LOGIKA DATA =====================

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Ambil Data User
      var query = supabase
          .from('profiles')
          .select('*, profile_privileges(privileges(name))')
          .neq('role', 'vendor')
          .neq('role', 'VENDOR');

      if (_searchQuery.isNotEmpty) {
        query = query.or('nik.ilike.%$_searchQuery%, email.ilike.%$_searchQuery%');
      }

      final userData = await query.order('nik', ascending: true);

      // 2. Ambil Master Data Privileges
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUser() async {
    if (_nikController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lengkapi semua data!")));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      await AuthService.registerInternalUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        nik: _nikController.text.trim(),
        role: selectedRole!,
        privilegeIds: selectedPrivilegeIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        Navigator.pop(context); // Tutup Form Dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("User Berhasil Didaftarkan")));
      }
      _clearForm();
      _fetchData();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      String errorString = e.toString();
      String msg = errorString.contains("User already registered") ? "Email sudah terdaftar." : "Error: $e";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(msg)));
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await supabase.from('profiles').delete().eq('id', userId);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data berhasil dihapus"), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      debugPrint("Error Delete: $e");
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
    final source = UserDataSource(
      _users, 
      context, 
      onDelete: (id) => _deleteUser(id)
    );

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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(50), // Sesuai WarehousePage
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: "Cari NIK atau Email...",
                      prefixIcon: const Icon(Icons.search),
                      suffix: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = "";
                          _fetchData();
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (val) {
                      _searchQuery = val;
                      _fetchData();
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      header: const Text("Daftar Pengguna Internal"),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('NIK', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Hak Akses', style: TextStyle(fontWeight: FontWeight.bold))),
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

  void _showAddUserDialog() {
    _clearForm();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: roles.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                    onChanged: (val) => setDialogState(() => selectedRole = val),
                    decoration: const InputDecoration(labelText: "Pilih Role", prefixIcon: Icon(Icons.admin_panel_settings), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text("Pilih Hak Akses:", style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: _masterPrivileges.isEmpty
                        ? const Padding(padding: EdgeInsets.all(10), child: Text("Memuat data..."))
                        : Column(
                            children: _masterPrivileges.map((priv) {
                              return CheckboxListTile(
                                title: Text(priv['name'], style: const TextStyle(fontSize: 14)),
                                value: selectedPrivilegeIds.contains(priv['id']),
                                activeColor: Colors.red.shade700,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (bool? val) {
                                  setDialogState(() {
                                    if (val == true) selectedPrivilegeIds.add(priv['id']);
                                    else selectedPrivilegeIds.remove(priv['id']);
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

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder(), isDense: true),
    );
  }
}

// ===================== DATA SOURCE CLASS =====================

class UserDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(String) onDelete;

  UserDataSource(this.data, this.context, {required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final user = data[index];

    final List rawPrivs = user['profile_privileges'] ?? [];
    final String privString = rawPrivs.isNotEmpty
        ? rawPrivs.map((item) => item['privileges']['name'].toString()).join(', ')
        : '-';

    return DataRow(cells: [
      DataCell(Text(user['nik']?.toString() ?? '-')),
      DataCell(Text(user['email']?.toString() ?? '-')),
      DataCell(Text(user['role']?.toString().toUpperCase() ?? '-')),
      DataCell(Text(privString)),
      DataCell(
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(user['id'], user['nik']),
        ),
      ),
    ]);
  }

  void _confirmDelete(String id, String nik) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus User?"),
        content: Text("Yakin ingin menghapus user dengan NIK $nik?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              onDelete(id);
              Navigator.pop(c);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}