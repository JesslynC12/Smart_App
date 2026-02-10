import 'package:supabase_flutter/supabase_flutter.dart';

// ===================== USER MODEL =====================
class User {
  final String id;
  final String email;
  final String nik;
  final String? role;
  final String? status; // Status Vendor
  final bool isActive;  // Fitur Akun Aktif/Non-aktif
  final List<String> privileges;

  User({
    required this.id,
    required this.email,
    required this.nik,
    this.role,
    this.status,
    this.isActive = true,
    this.privileges = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parsing privileges dari nested list
    List<String> privs = [];
    if (json['profile_privileges'] != null && json['profile_privileges'] is List) {
      for (var item in json['profile_privileges']) {
        if (item['privileges'] != null) {
          // Mengambil nama privilege
          privs.add(item['privileges']['name'].toString());
        }
      }
    }

    // Parsing status vendor dari list (join table vendor_details)
    String? statusValue;
    if (json['vendor_details'] != null &&
        (json['vendor_details'] as List).isNotEmpty) {
      statusValue = json['vendor_details'][0]['status'];
    }

    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nik: json['nik'] ?? '',
      role: json['role'],
      status: statusValue,
      isActive: json['is_active'] ?? true, // Default ke true jika null
      privileges: privs,
    );
  }
}

// ===================== AUTH SERVICE =====================
class AuthService {
  static final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 1. LOGIN SYSTEM (Support Email & NIK)
  // ---------------------------------------------------------------------------
  static Future<User?> login(String identifier, String password) async {
    try {
      String emailForAuth = identifier.trim();

      // Jika input bukan email (tidak ada '@'), cari email berdasarkan NIK
      if (!identifier.contains('@')) {
        // Validasi NIK harus 8 digit
        if (identifier.length != 8) {
           throw Exception('Format NIK harus 8 digit');
        }

        final findUser = await _supabase
            .from('profiles')
            .select('email')
            .eq('nik', identifier.trim())
            .maybeSingle();

        if (findUser == null) {
          throw Exception('NIK tidak terdaftar');
        }
        emailForAuth = findUser['email'];
      }

      // Melakukan autentikasi ke Supabase Auth
      final response = await _supabase.auth.signInWithPassword(
        email: emailForAuth,
        password: password,
      );

      if (response.user != null) {
        final user = await getCurrentUser();
        
        // CEK STATUS AKTIF: Jika false, paksa logout dan throw error
        if (user != null && !user.isActive) {
          await logout();
          throw Exception('Akun Anda telah dinonaktifkan oleh Admin.');
        }

        return user;
      }
      return null;
    } on AuthException catch (e) {
      throw Exception('Login Gagal: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. USER MANAGEMENT (Digunakan oleh UserManagementPage)
  // ---------------------------------------------------------------------------
  
  // Ambil daftar Master Privileges untuk Checkbox
  static Future<List<Map<String, dynamic>>> getAvailablePrivileges() async {
    return await _supabase
        .from('privileges')
        .select('id, name') // Pastikan kolom label ada di DB Anda
        .order('id');
  }

  // Registrasi User Internal (Admin/PPIC/Logistik) + Simpan Hak Akses
  static Future<void> registerInternalUser({
    required String email,
    required String password,
    required String nik,
    required String role,
    required List<int> privilegeIds, // List ID Hak Akses yang dicentang
  }) async {
    if (nik.length != 8) throw Exception('NIK harus 8 karakter.');

    try {
      // A. Buat Akun Auth
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        final userId = response.user!.id;

        // B. Simpan ke Tabel Profiles
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          'nik': nik,
          'role': role,
          'is_active': true,
        });

        // C. Simpan ke Tabel Profile_Privileges (Looping Insert)
        if (privilegeIds.isNotEmpty) {
          final List<Map<String, dynamic>> privilegesData = privilegeIds.map((pId) {
            return {
              'profile_id': userId,
              'privilege_id': pId,
            };
          }).toList();

          await _supabase.from('profile_privileges').insert(privilegesData);
        }
      }
    } catch (e) {
      throw Exception('Gagal mendaftarkan user: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 3. VENDOR REGISTRATION (Public Register)
  // ---------------------------------------------------------------------------
  static Future<void> registerVendor({
    required String email,
    required String password,
    required String nik,
    required String companyName,
    required String address,
    required String city,
    required String phone,
  }) async {
    if (nik.length != 8) throw Exception('NIK harus tepat 8 karakter.');

    // Cek duplikasi NIK sederhana sebelum request auth
    final checkNik = await _supabase.from('profiles').select('id').eq('nik', nik).maybeSingle();
    if (checkNik != null) throw Exception('NIK sudah terdaftar.');

    try {
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        final userId = response.user!.id;

        try {
          // 1. Simpan ke profiles
          await _supabase.from('profiles').insert({
            'id': userId,
            'email': email,
            'nik': nik,
            'role': 'vendor',
            'is_active': true,
          });

          // 2. Simpan ke vendor_details
          await _supabase.from('vendor_details').insert({
            'profile_id': userId,
            'nama_perusahaan': companyName,
            'alamat': address,
            'city': city,
            'phone': phone,
            'status': 'pending',
          });
        } catch (dbError) {
          // Jika insert DB gagal, lempar error agar UI tahu
          throw Exception('Gagal menyimpan profil vendor: $dbError');
        }
      }
    } catch (e) {
      throw Exception('Gagal registrasi vendor: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 4. HELPER FUNCTIONS
  // ---------------------------------------------------------------------------
  static Future<bool> isLoggedIn() async => _supabase.auth.currentSession != null;

  static Future<void> logout() async => await _supabase.auth.signOut();

  // Ambil Data User yang sedang login (Beserta Relasi Privileges & Vendor)
  static Future<User?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userData = await _supabase.from('profiles').select('''
              *,
              vendor_details ( status ),
              profile_privileges ( privileges ( name ) )
            ''').eq('id', user.id).single();
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- UPDATE USER (ROLE & PRIVILEGES) ---
  static Future<void> updateUserAccess({
    required String userId,
    required String newRole,
    required List<int> newPrivilegeIds,
  }) async {
    try {
      // 1. Update Role di tabel profiles
      await _supabase.from('profiles').update({
        'role': newRole,
      }).eq('id', userId);

      // 2. Update Hak Akses (Konsep: Hapus Semua yg Lama -> Insert yg Baru)
      // Ini cara paling aman untuk sinkronisasi many-to-many
      
      // A. Hapus akses lama
      await _supabase.from('profile_privileges').delete().eq('profile_id', userId);

      // B. Insert akses baru (jika ada yg dipilih)
      if (newPrivilegeIds.isNotEmpty) {
        final List<Map<String, dynamic>> privilegesData = newPrivilegeIds.map((pId) {
          return {
            'profile_id': userId,
            'privilege_id': pId,
          };
        }).toList();

        await _supabase.from('profile_privileges').insert(privilegesData);
      }
    } catch (e) {
      throw Exception('Gagal update user: $e');
    }
  }
}