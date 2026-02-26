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
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _masterPrivileges = [];
  bool _isLoading = true;
  String _searchQuery = "";

  // Edit Mode State
  bool isEditing = false;
  String? editingUserId;

  String? selectedRole;
  String? selectedLokasi;
  final List<String> lokasiOptions = ['Rungkut', 'Tambak Langon'];
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
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var query = supabase
          .from('profiles')
          .select('*, profile_privileges(privileges(name, id))')
          .neq('role', 'vendor')
          .neq('role', 'VENDOR');

      if (_searchQuery.isNotEmpty) {
        query = query.or('nik.ilike.%$_searchQuery%, email.ilike.%$_searchQuery%, name.ilike.%$_searchQuery%');
      }

      final userData = await query.order('nik', ascending: true);
      final privData = await AuthService.getAvailablePrivileges();

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(userData);
          _masterPrivileges = privData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nikController.text = "";
    _emailController.text = "";
    _passwordController.text = "";
    _nameController.text = "";
    selectedRole = null;
    selectedLokasi = null;
    selectedPrivilegeIds.clear();
    isEditing = false;
    editingUserId = null;
  }

  Future<void> _saveUser() async {
    // Password hanya wajib jika bukan sedang edit (user baru)
    if (_nikController.text.isEmpty || _emailController.text.isEmpty || 
        (!isEditing && _passwordController.text.isEmpty) || 
        _nameController.text.isEmpty || 
        selectedRole == null || selectedLokasi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lengkapi semua data!")));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      if (isEditing) {
        // UPDATE DATA (Menggunakan method di AuthService)
        await AuthService.updateUserAccess(
          userId: editingUserId!,
          newRole: selectedRole!,
          newPrivilegeIds: selectedPrivilegeIds.toList(),
          newName: _nameController.text.trim(),
          newLokasi: selectedLokasi!,
        );
      } else {
        // REGISTER NEW USER
        await AuthService.registerInternalUser(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          nik: _nikController.text.trim(),
          name: _nameController.text.trim(),
          lokasi: selectedLokasi!,
          role: selectedRole!,
          privilegeIds: selectedPrivilegeIds.toList(),
        );
      }

      if (mounted) {
        Navigator.pop(context); // Tutup loading
        Navigator.pop(context); // Tutup dialog form
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green, 
          content: Text(isEditing ? "Data berhasil diperbarui" : "User Berhasil Didaftarkan")
        ));
        _fetchData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = UserDataSource(
      _users, 
      context, 
      onDelete: (id) => supabase.from('profiles').delete().eq('id', id).then((_) => _fetchData()),
      onEdit: (user) => _showAddUserDialog(user: user),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Manajemen User"), backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        onPressed: () => _showAddUserDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(50),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Cari NIK, Nama, atau Email...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (val) { _searchQuery = val; _fetchData(); },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: PaginatedDataTable(
                    columns: const [
                      DataColumn(label: Text('NIK')),
                      DataColumn(label: Text('Nama')),
                      DataColumn(label: Text('Lokasi')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Hak Akses')),
                      DataColumn(label: Text('Aksi')),
                    ],
                    source: source,
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showAddUserDialog({Map<String, dynamic>? user}) {
    _clearForm();
    if (user != null) {
      isEditing = true;
      editingUserId = user['id'];
      _nameController.text = user['name'] ?? "";
      _nikController.text = user['nik'] ?? "";
      _emailController.text = user['email'] ?? "";
      selectedRole = user['role'];
      selectedLokasi = user['lokasi'];
      
      // Ambil ID privilege yang sudah ada
      final List rawPrivs = user['profile_privileges'] ?? [];
      for (var p in rawPrivs) {
        selectedPrivilegeIds.add(p['privileges']['id']);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? "Edit User" : "Tambah User Baru"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField("Nama", Icons.person, _nameController),
                  const SizedBox(height: 12),
                  _buildTextField("NIK", Icons.badge, _nikController),
                  const SizedBox(height: 12),
                  // Email di-disable saat edit karena biasanya unik/auth key
                  _buildTextField("Email", Icons.email, _emailController, enabled: !isEditing),
                  const SizedBox(height: 12),
                  // Password disembunyikan saat edit (bisa lewat reset password tersendiri)
                  if (!isEditing) _buildTextField("Password", Icons.lock, _passwordController, isPassword: true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedLokasi,
                    items: lokasiOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setDialogState(() => selectedLokasi = val),
                    decoration: const InputDecoration(labelText: "Lokasi", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: roles.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                    onChanged: (val) => setDialogState(() => selectedRole = val),
                    decoration: const InputDecoration(labelText: "Pilih Role", border: OutlineInputBorder(), prefixIcon: Icon(Icons.admin_panel_settings)),
                  ),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text("Pilih Hak Akses:", style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: _masterPrivileges.map((priv) {
                        return CheckboxListTile(
                          title: Text(priv['name']),
                          value: selectedPrivilegeIds.contains(priv['id']),
                          onChanged: (val) {
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
            ElevatedButton(onPressed: _saveUser, child: const Text("Simpan")),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon), 
        border: const OutlineInputBorder(), 
        isDense: true,
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
    );
  }
}

class UserDataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  final Function(String) onDelete;
  final Function(Map<String, dynamic>) onEdit;

  UserDataSource(this.data, this.context, {required this.onDelete, required this.onEdit});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final user = data[index];
    final List rawPrivs = user['profile_privileges'] ?? [];
    final String privString = rawPrivs.map((e) => e['privileges']['name'].toString()).join(', ');

    return DataRow(cells: [
      DataCell(Text(user['nik'] ?? '-')),
      DataCell(Text(user['name'] ?? '-')),
      DataCell(Text(user['lokasi'] ?? '-')),
      DataCell(Text(user['role']?.toString().toUpperCase() ?? '-')),
      DataCell(Text(privString.isEmpty ? '-' : privString)),
      DataCell(Row(
        children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => onEdit(user)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(user['id'])),
        ],
      )),
    ]);
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus?"),
        content: const Text("Data yang dihapus tidak dapat dikembalikan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () { onDelete(id); Navigator.pop(c); },
            child: const Text("Hapus"),
          )
        ],
      ),
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}