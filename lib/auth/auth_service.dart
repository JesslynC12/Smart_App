import 'package:supabase_flutter/supabase_flutter.dart';

// ===================== USER MODEL =====================
class User {
  final String id;
  final String email;
  final String nik;
  final String? name;    // Tambahan: Nama Lengkap
  final String? lokasi;  // Tambahan: Lokasi (Rungkut/Tambak Langon)
  final String? role;
  final String? status; 
  final bool isActive;  
  final List<String> privileges;

  User({
    required this.id,
    required this.email,
    required this.nik,
    this.name,          // New
    this.lokasi,        // New
    this.role,
    this.status,
    this.isActive = true,
    this.privileges = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parsing privileges
    List<String> privs = [];
    if (json['profile_privileges'] != null && json['profile_privileges'] is List) {
      for (var item in json['profile_privileges']) {
        if (item['privileges'] != null) {
          privs.add(item['privileges']['name'].toString());
        }
      }
    }

    // Parsing status vendor
    String? statusValue;
    if (json['vendor_details'] != null && (json['vendor_details'] as List).isNotEmpty) {
      statusValue = json['vendor_details'][0]['status'];
    }

    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nik: json['nik'] ?? '',
      name: json['name'],      // Mapping data name
      lokasi: json['lokasi'],  // Mapping data lokasi
      role: json['role'],
      status: statusValue,
      isActive: json['is_active'] ?? true,
      privileges: privs,
    );
  }
}

// ===================== AUTH SERVICE =====================
class AuthService {
  static final _supabase = Supabase.instance.client;

  // 1. LOGIN SYSTEM
  static Future<User?> login(String identifier, String password) async {
    try {
      String emailForAuth = identifier.trim();

      if (!identifier.contains('@')) {
        if (identifier.length != 8) throw Exception('Format NIK harus 8 digit');

        final findUser = await _supabase
            .from('profiles')
            .select('email')
            .eq('nik', identifier.trim())
            .maybeSingle();

        if (findUser == null) throw Exception('NIK tidak terdaftar');
        emailForAuth = findUser['email'];
      }

      final response = await _supabase.auth.signInWithPassword(
        email: emailForAuth,
        password: password,
      );

      if (response.user != null) {
        final user = await getCurrentUser();
        
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

  // 2. USER MANAGEMENT
  static Future<List<Map<String, dynamic>>> getAvailablePrivileges() async {
    return await _supabase
        .from('privileges')
        .select('id, name')
        .order('id');
  }

  // --- REGISTRASI USER INTERNAL (DIUBAH) ---
  static Future<void> registerInternalUser({
    required String email,
    required String password,
    required String nik,
    required String name,      // Tambahan Baru
    required String lokasi,    // Tambahan Baru
    required String role,
    required List<int> privilegeIds,
  }) async {
    if (nik.length != 8) throw Exception('NIK harus 8 karakter.');

    try {
      // A. Buat Akun Auth
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        final userId = response.user!.id;

        // B. Simpan ke Tabel Profiles dengan field Name & Lokasi
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          'nik': nik,
          'name': name,       // Masuk ke kolom name
          'lokasi': lokasi,   // Masuk ke kolom lokasi
          'role': role,
          'is_active': true,
        });

        // C. Simpan ke Tabel Profile_Privileges
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

  // 3. VENDOR REGISTRATION (Tetap Sama)
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

    final checkNik = await _supabase.from('profiles').select('id').eq('nik', nik).maybeSingle();
    if (checkNik != null) throw Exception('NIK sudah terdaftar.');

    try {
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        final userId = response.user!.id;
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          'nik': nik,
          'role': 'vendor',
          'is_active': true,
        });

        await _supabase.from('vendor_details').insert({
          'profile_id': userId,
          'nama_perusahaan': companyName,
          'alamat': address,
          'city': city,
          'phone': phone,
          'status': 'pending',
        });
      }
    } catch (e) {
      throw Exception('Gagal registrasi vendor: $e');
    }
  }

  // 4. HELPER FUNCTIONS
  static Future<bool> isLoggedIn() async => _supabase.auth.currentSession != null;
  static Future<void> logout() async => await _supabase.auth.signOut();

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

  static Future<void> updateUserAccess({
    required String userId,
    required String newRole,
    required List<int> newPrivilegeIds,
    String? newName,    // Opsi jika ingin update nama juga
    String? newLokasi,  // Opsi jika ingin update lokasi juga
  }) async {
    try {
      // Buat map update secara dinamis
      final Map<String, dynamic> updateData = {'role': newRole};
      if (newName != null) updateData['name'] = newName;
      if (newLokasi != null) updateData['lokasi'] = newLokasi;

      await _supabase.from('profiles').update(updateData).eq('id', userId);

      await _supabase.from('profile_privileges').delete().eq('profile_id', userId);

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