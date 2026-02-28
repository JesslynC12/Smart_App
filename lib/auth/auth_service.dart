import 'package:supabase_flutter/supabase_flutter.dart';

// ===================== USER MODEL (Tetap) =====================
class User {
  final String id;
  final String email;
  final String nik;
  final String? name;
  final String? lokasi;
  final String? role;
  final String? status;
  final bool isActive;
  final List<String> privileges;

  User({
    required this.id,
    required this.email,
    required this.nik,
    this.name,
    this.lokasi,
    this.role,
    this.status,
    this.isActive = true,
    this.privileges = const [],
  });

bool hasPermission(String permissionName) {
    return privileges.contains(permissionName);
  }

  factory User.fromJson(Map<String, dynamic> json) {
    List<String> privs = [];
    if (json['profile_privileges'] != null && json['profile_privileges'] is List) {
      for (var item in json['profile_privileges']) {
        if (item['privileges'] != null) {
          privs.add(item['privileges']['name'].toString());
        }
      }
    }

    String? statusValue;
    if (json['vendor_details'] != null && (json['vendor_details'] as List).isNotEmpty) {
      statusValue = json['vendor_details'][0]['status'];
    }

    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nik: json['nik'] ?? '',
      name: json['name'],
      lokasi: json['lokasi'],
      role: json['role'],
      status: statusValue,
      isActive: json['is_active'] ?? true,
      privileges: privs,
    );
  }
}

// ===================== AUTH SERVICE (Disesuaikan dengan Edge Functions) =====================
class AuthService {
  static final _supabase = Supabase.instance.client;

  // 1. LOGIN SYSTEM (Tetap)
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

  // 2. USER MANAGEMENT (Menggunakan Edge Function)
  // --- CREATE USER INTERNAL ---
  static Future<void> registerInternalUser({
    required String email,
    required String password,
    required String nik,
    required String name,
    required String lokasi,
    required String role,
    required List<int> privilegeIds,
  }) async {
    //if (nik.length != 8) throw Exception('NIK harus 8 karakter.');
try {
    final response = await _supabase.functions.invoke(
      'create-internal-user',
      body: {
        'email': email,
        'password': password,
        'nik': nik,
        'name': name,
        'lokasi': lokasi,
        'role': role,
        'privilegeIds': privilegeIds,
      },
      // Menambahkan header secara manual untuk memastikan autentikasi lolos
      headers: {
        'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Gagal mendaftarkan user');
    }
  } catch (e) {
    throw Exception('Terjadi kesalahan: $e');
  }
}

  // --- UPDATE USER ACCESS ---
  static Future<void> updateUserAccess({
    required String userId,
    required String newRole,
    required List<int> newPrivilegeIds,
    required String newNik,     // NIK kini wajib dikirim agar sinkron
    String? newName,
    String? newLokasi,
  }) async {
    final response = await _supabase.functions.invoke(
      'update-internal-user',
      body: {
        'userId': userId,
        'role': newRole,
        'nik': newNik,
        'name': newName,
        'lokasi': newLokasi,
        'privilegeIds': newPrivilegeIds,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Gagal update user');
    }
  }
  

  // --- DELETE USER ---
  static Future<void> deleteUserPermanently(String userId) async {
    final response = await _supabase.functions.invoke(
      'delete-user',
      body: {'userId': userId},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Gagal menghapus user');
    }
  }

  // 3. VENDOR REGISTRATION (Masih menggunakan signUp karena biasanya dilakukan oleh user sendiri)
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

  // 4. HELPERS
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

  static Future<List<Map<String, dynamic>>> getAvailablePrivileges() async {
    return await _supabase.from('privileges').select('id, name').order('id');
  }
  
}
