// ignore_for_file: use_build_context_synchronously

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

  bool isEditing = false;
  String? editingUserId;

  String? selectedRole;
  String? selectedLokasi;
  final List<String> lokasiOptions = ['Rungkut', 'Tambak Langon'];
  final Set<int> selectedPrivilegeIds = {};
  final List<String> roles = ['admin', 'supervisor', 'ppic', 'logistik', 'gudang', 'satpam'];


// Letakkan di dalam _UserManagementPageState
final Map<String, List<String>> roleTemplates = {
  'admin': ['Loading', 'CheckIn','InputDO', 'ListDO', 'Complain', 'ListComplain', 'Master', 'Occupancy', 'VendorRequest'],
  'logistik': ['CheckIn', 'Loading', 'ListDO', 'DOdetailsGBJ', 'ListPermintaanPengiriman'],
  'supervisor': ['Master', 'Loading', 'CheckIn','InputDO', 'ListDO', 'Complain', 'ListComplain'],
  'gudang': ['Loading', 'Occupancy', 'ListDO', 'DOdetailsGBJ'],
  // Tambahkan role lainnya...
};


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
      // Mengambil profil internal (non-vendor)
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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengambil data: $e")));
      }
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
    if (_nikController.text.length != 8) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("NIK harus berjumlah 8 karakter!"))
    );
    return;
  }
    if (_nikController.text.isEmpty || 
        _emailController.text.isEmpty || 
        (!isEditing && _passwordController.text.isEmpty) || 
        _nameController.text.isEmpty || 
        selectedRole == null || 
        selectedLokasi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lengkapi semua data!")));
      return;
    }

    // Menampilkan Loading
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      if (isEditing) {
        // UPDATE via Edge Function (Sinkron dengan AuthService terbaru)
        await AuthService.updateUserAccess(
          userId: editingUserId!,
          newRole: selectedRole!,
          newPrivilegeIds: selectedPrivilegeIds.toList(),
          newName: _nameController.text.trim(),
          newNik: _nikController.text.trim(), // Wajib dikirim untuk sinkronisasi
          newLokasi: selectedLokasi!,
        );
      } else {
        // REGISTER via Edge Function (Mencegah Admin ter-logout)
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
      if (mounted) Navigator.pop(context); // Tutup loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red, 
        content: Text(e.toString().replaceAll("Exception: ", ""))
      ));
    }
  }

  // Fungsi Hapus yang Disesuaikan
  Future<void> _handleDelete(String id) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    try {
      await AuthService.deleteUserPermanently(id);
      if (mounted) {
        Navigator.pop(context); // Tutup loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User berhasil dihapus permanent")));
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = UserDataSource(
      _users, 
      context, 
      onDelete: (id) => _handleDelete(id),
      onEdit: (user) => _showAddUserDialog(user: user),
    );

    return Scaffold(
      //appBar: AppBar(title: const Text("Manajemen User"), backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        onPressed: () => _showAddUserDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(50), // Disesuaikan agar tidak terlalu lebar di web/desktop
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Cari NIK, Nama, atau Email...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = "";
                        _fetchData();
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (val) { _searchQuery = val; _fetchData(); },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: PaginatedDataTable(
                    rowsPerPage: 10,
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(label: Text('NIK', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Lokasi', style: TextStyle(fontWeight: FontWeight.bold))),
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
      
      final List rawPrivs = user['profile_privileges'] ?? [];
      for (var p in rawPrivs) {
        if(p['privileges'] != null) {
          selectedPrivilegeIds.add(p['privileges']['id']);
        }
      }
    }

    showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(isEditing ? "Edit User" : "Tambah User Baru"),
        // Mengatur lebar dialog secara proporsional terhadap layar
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6, // Lebar 60% dari layar
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Baris 1: Nama dan NIK berdampingan
                Row(
                  children: [
                    Expanded(child: _buildTextField("Nama Lengkap *", Icons.person, _nameController)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildTextField("NIK (8 Digit) *", Icons.badge, _nikController, maxLength: 8)),
                  ],
                ),
                const SizedBox(height: 15),

                // Baris 2: Email dan Password berdampingan
                Row(
                  children: [
                    Expanded(child: _buildTextField("Email Address *", Icons.email, _emailController, enabled: !isEditing)),
                    if (!isEditing) ...[
                      const SizedBox(width: 15),
                      Expanded(child: _buildTextField("Password *", Icons.lock, _passwordController, isPassword: true)),
                    ],
                  ],
                ),
                const SizedBox(height: 15),

                // Baris 3: Lokasi dan Role berdampingan
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedLokasi,
                        items: lokasiOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setDialogState(() => selectedLokasi = val),
                        decoration: const InputDecoration(labelText: "Lokasi *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedRole,
                        items: roles.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                       onChanged: (val) {
    if (val != null) {
      // Panggil template otomatis saat role dipilih
      _applyRoleTemplate(val, setDialogState);
      // Simpan role yang dipilih ke variable utama
      setDialogState(() => selectedRole = val);
    }
  },
  decoration: const InputDecoration(
    labelText: "Pilih Role *", 
    border: OutlineInputBorder(), 
    prefixIcon: Icon(Icons.admin_panel_settings)
  ),
),
                    ),
                  ],
                ),
                  const SizedBox(height: 16),
                  
                  const Align(alignment: Alignment.centerLeft, child: Text("Pilih Hak Akses: *", style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  Container(
                    height: 250, // Menghindari dialog terlalu panjang
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    // child: ListView(
                    //   shrinkWrap: true,
                    //   children: _masterPrivileges.map((priv) {
                    //     return CheckboxListTile(
                    //       title: Text(priv['name']),
                    //       value: selectedPrivilegeIds.contains(priv['id']),
                    //       onChanged: (val) {
                    //         setDialogState(() {
                    //           if (val == true) selectedPrivilegeIds.add(priv['id']);
                    //           else selectedPrivilegeIds.remove(priv['id']);
                    //         });
                    //       },
                    //     );
                    //   }).toList(),
                    child: Column( // Ubah jadi Column agar Select All selalu di atas
    children: [
      // --- CHECKBOX SELECT ALL ---
      CheckboxListTile(
        title: const Text("PILIH SEMUA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        activeColor: Colors.red,
        value: selectedPrivilegeIds.length == _masterPrivileges.length && _masterPrivileges.isNotEmpty,
        onChanged: (val) {
          setDialogState(() {
            if (val == true) {
              // Tambahkan semua ID dari master ke set
              for (var priv in _masterPrivileges) {
                print("Membandingkan DB: ${priv['name']} dengan Template: ${roleTemplates[selectedRole] ?? []}");
  if (roleTemplates[selectedRole]?.contains(priv['name']) == true) {
    print("COCOK! Menambah ID: ${priv['id']}");
                selectedPrivilegeIds.add(priv['id']);
              }
              }
            } else {
              // Kosongkan semua
              selectedPrivilegeIds.clear();
            }
          });
        },
      ),
      const Divider(height: 1), // Garis pemisah
      
      // List Privilege yang sudah ada
      Expanded(
        child: ListView(
          shrinkWrap: true,
          children: _masterPrivileges.map((priv) {
            return CheckboxListTile(
              title: Text(priv['name']),
              value: selectedPrivilegeIds.contains(priv['id']),
              onChanged: (val) {
                setDialogState(() {
                  if (val == true) {
                    selectedPrivilegeIds.add(priv['id']);
                  } else {
                    selectedPrivilegeIds.remove(priv['id']);
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
              onPressed: _saveUser, 
              child: const Text("Simpan")
            ),
          ],
        ),
      ),
    );
  }

//   void _applyRoleTemplate(String role, Function setDialogState) {
//   if (roleTemplates.containsKey(role)) {
//     final templateNames = roleTemplates[role]!;
    
//     setDialogState(() {
//       // Kita cari ID dari _masterPrivileges berdasarkan nama di template
//       for (var priv in _masterPrivileges) {
//         if (templateNames.contains(priv['name'])) {
//           selectedPrivilegeIds.add(priv['id']);
//         }
//       }
//     });
//   }
// }

// void _applyRoleTemplate(String role, Function setDialogState) {
//   // 1. Cek apakah role ada di template
//   if (roleTemplates.containsKey(role)) {
//     final List<String> templateNames = roleTemplates[role]!;
    
//     setDialogState(() {
//       // 2. Kosongkan pilihan hak akses sebelumnya (opsional, tergantung kebutuhan)
//       selectedPrivilegeIds.clear();

//       // 3. Cocokkan nama di template dengan data dari _masterPrivileges
//       for (var priv in _masterPrivileges) {
//         // Jika nama privilege di database ada dalam daftar template
//         if (templateNames.contains(priv['name'])) {
//           selectedPrivilegeIds.add(priv['id']);
//         }
//       }
//     });
//   }
// }

void _applyRoleTemplate(String role, Function setDialogState) {
  if (roleTemplates.containsKey(role)) {
    // Ubah semua nama di template ke lowercase untuk pembanding
    final List<String> templateNames = roleTemplates[role]!
        .map((e) => e.toLowerCase().trim())
        .toList();
    
    setDialogState(() {
      selectedPrivilegeIds.clear();

      for (var priv in _masterPrivileges) {
        // Bandingkan dengan versi lowercase
        String dbPrivName = priv['name'].toString().toLowerCase().trim();
        
        if (templateNames.contains(dbPrivName)) {
          selectedPrivilegeIds.add(priv['id']);
        }
      }
    });
  }
}

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false, bool enabled = true, int? maxLength}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      enabled: enabled,
      maxLength: maxLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // Sembunyikan counter angka di bawah field
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon), 
        border: const OutlineInputBorder(), 
        isDense: true,
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
        counterText: "",
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
    final String privString = rawPrivs
        .where((e) => e['privileges'] != null)
        .map((e) => e['privileges']['name'].toString())
        .join(', ');

    return DataRow(cells: [
      DataCell(Text(user['nik'] ?? '-')),
      DataCell(Text(user['name'] ?? '-')),
      DataCell(Text(user['lokasi'] ?? '-')),
      DataCell(Text(user['role']?.toString().toUpperCase() ?? '-')),
      DataCell(
      Container(
        width: 600, // Tentukan lebar maksimal kolom Hak Akses di sini
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          privString.isEmpty ? '-' : privString,
          softWrap: true, // Membuat teks turun ke bawah
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ),
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
        title: const Text("Hapus User?"),
        content: const Text("User akan dihapus dari sistem Auth dan Database secara permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(c); onDelete(id); },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }


  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}