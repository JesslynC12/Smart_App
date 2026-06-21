import 'package:supabase_flutter/supabase_flutter.dart';

class User {
  final String id;
  final String email;
  final String nik;
  final String? name;
  final String? lokasi;
  final String? role;
  final String? status;
  final String? nikVendor;
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
    this.nikVendor,
    this.isActive = true,
    this.privileges = const [],
  });

  bool hasPermission(String permissionName) {
    return privileges.contains(permissionName);
  }

  factory User.fromJson(Map<String, dynamic> json) {
    List<String> privs = [];
    if (json['profile_privileges'] != null) {
      final List<dynamic> relationList = json['profile_privileges'];
      for (var item in relationList) {
        if (item['privileges'] != null && item['privileges']['name'] != null) {
          privs.add(item['privileges']['name'].toString());
        }
      }
    }

    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nik: json['nik'] ?? '',
      name: json['name'],
      lokasi: json['lokasi'],
      role: json['role'],
      status: json['status'],
      nikVendor: json['nik_vendor'],
      isActive: json['is_active'] ?? true,
      privileges: privs,
    );
  }
}

class AuthService {
  static final _supabase = Supabase.instance.client;
  static Future<User?> login(String identifier, String password) async {
    try {
      String emailForAuth = identifier.trim();
      if (!identifier.contains('@')) {
        final response = await _supabase
            .from('profiles')
            .select('email')
            .or('nik.eq.${identifier.trim()}, nik_vendor.eq.${identifier.trim()}',
            );

        final List<dynamic> findUserList = response ?? [];

        if (findUserList.isEmpty) {
          throw Exception(
            'Akun belum terdaftar. Silakan melakukan registrasi.',
          );
        }

        if (findUserList.length > 1) {
          throw Exception(
            'NIK ini terhubung ke beberapa akun (Vendor). Silakan gunakan Email untuk login.',
          );
        }

        emailForAuth = findUserList[0]['email'];
      } else {
        final checkEmail = await _supabase
            .from('profiles')
            .select('email')
            .eq('email', emailForAuth)
            .maybeSingle();

        if (checkEmail == null) {
          throw Exception(
            'Akun belum terdaftar. Silakan melakukan registrasi.',
          );
        }
      }
      final authResponse = await _supabase.auth.signInWithPassword(
        email: emailForAuth,
        password: password,
      );

      if (authResponse.user != null) {
        final user = await getCurrentUser();

        if (user != null) {
          if (!user.isActive) {
            await logout();
            throw Exception('Akun Anda telah dinonaktifkan oleh Admin.');
          }

          if (user.role?.toLowerCase() == 'vendor' &&
              user.status?.toLowerCase() == 'pending') {
            await logout();
            throw Exception('Silahkan Verifikasi Email Anda.');
          }

          return user;
        }
      }
      return null;
    } on AuthException catch (e) {
      String message = e.message;
      if (message.contains("Invalid login credentials")) {
        message = "Email atau Password yang Anda masukkan salah.";
      } else if (message.contains("Email not confirmed")) {
        message =
            "Email Anda belum terverifikasi. Silakan cek inbox email Anda.";
      }
      throw Exception(message);
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      throw Exception(errorMsg);
    }
  }

  static Future<void> registerInternalUser({
    required String email,
    required String password,
    required String nik,
    required String name,
    required String lokasi,
    required String role,
    required List<int> privilegeIds,
  }) async {
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
          'status': 'active',
          'privilegeIds': privilegeIds,
        },
        headers: {
          'Authorization':
              'Bearer ${_supabase.auth.currentSession?.accessToken}',
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

  static Future<void> updateUserAccess({
    required String userId,
    required String newRole,
    required List<int> newPrivilegeIds,
    required String newNik,
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

  static Future<void> deleteUserPermanently(String userId) async {
    final response = await _supabase.functions.invoke(
      'delete-user',
      body: {'userId': userId},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Gagal menghapus user');
    }
  }

  static Future<void> registerVendor({
    required String email,
    required String password,
    required String name,
    required String nikInput,
    required String registCodeInput,
  }) async {
    try {
      final vendorCheck = await _supabase
          .from('master_vendor')
          .select()
          .eq('nik', nikInput)
          .eq('regist_code', registCodeInput.trim().toUpperCase())
          .maybeSingle();

      if (vendorCheck == null) {
        throw Exception(
          "NIK atau Kode Registrasi tidak valid. Silakan hubungi admin.",
        );
      }

      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'nik_vendor': nikInput},
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<bool> isLoggedIn() async =>
      _supabase.auth.currentSession != null;
  static Future<void> logout() async => await _supabase.auth.signOut();

  static Future<User?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userData = await _supabase
            .from('profiles')
            .select('''
              *,
              
              profile_privileges ( privileges ( name ) )
            ''')
            .eq('id', user.id)
            .single();
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

  static Future<List<int>> getVendorDetailIds(String nik) async {
    final response = await _supabase
        .from('vendor_transportasi')
        .select('id')
        .eq('nik', nik);
    return (response as List).map((e) => e['id'] as int).toList();
  }

  static Future<List<Map<String, dynamic>>> getVendorEnrollments() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('role', 'vendor')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>>
  getPendingVendorEnrollments() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('status', 'pending')
          .order('id', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data: $e');
    }
  }

  static Future<void> updateVendorStatus(
    String userId,
    String newStatus,
  ) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'status': newStatus})
          .eq('id', userId);
      if (newStatus == 'rejected') {
        await _supabase
            .from('profiles')
            .update({'is_active': false})
            .eq('id', userId);
      } else if (newStatus == 'verified') {
        await _supabase
            .from('profiles')
            .update({'is_active': true})
            .eq('id', userId);
      }
    } catch (e) {
      throw Exception('Gagal memperbarui status: $e');
    }
  }
}
