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
    //if (json['profile_privileges'] != null && json['profile_privileges'] is List) {
      if (json['profile_privileges'] != null) {
      for (var item in json['profile_privileges']) {
        if (item['privileges'] != null) {
          privs.add(item['privileges']['name'].toString());
        }
      }
    }

    String? statusValue;
    // if (json['profiles_vendor'] != null && (json['profiles_vendor'] as List).isNotEmpty) {
    //   statusValue = json['profiles_vendor'][0]['status'];
    // }
     if (json['profiles_vendor'] != null) {

    if (json['profiles_vendor'] is List && (json['profiles_vendor'] as List).isNotEmpty) {

      statusValue = json['profiles_vendor'][0]['status'];

    } else if (json['profiles_vendor'] is Map) {

      statusValue = json['profiles_vendor']['status'];

    }

    }

    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nik: json['nik'] ?? '',
      name: json['name'],
      lokasi: json['lokasi'],
      role: json['role'],
      status: statusValue,
      //status: json['status'],
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

      // if (response.user != null) {
      //   final user = await getCurrentUser();
      //   if (user != null && !user.isActive) {
      //     await logout();
      //     throw Exception('Akun Anda telah dinonaktifkan oleh Admin.');
      //   }
      //   // 2. Cek jika Vendor belum diverifikasi
      // if (user?.role == 'vendor' && user?.status == 'pending') {
      //   await logout();
      //   throw Exception('Akun vendor Anda sedang menunggu verifikasi admin.');
      // }
      
      // // 3. Cek jika pendaftaran ditolak
      // if (user?.role == 'vendor' && user?.status == 'rejected') {
      //   await logout();
      //   throw Exception('Maaf, pendaftaran vendor Anda ditolak.');
      // }
    
      //   return user;
      // }
      if (response.user != null) {

  final user = await getCurrentUser();

 

 if (user != null) {

    // 1. Cek Blokir Admin (is_active)

    if (!user.isActive) {

      await logout();

      throw Exception('Akun Anda telah dinonaktifkan oleh Admin.');

    }



    // 2. Cek Status Vendor

    // Gunakan .toLowerCase() untuk memastikan 'Pending' atau 'pending' keduanya tertangkap

    final role = user.role?.toLowerCase();

    final status = user.status?.toLowerCase();



    if (role == 'vendor') {

      if (status == 'pending') {

        await logout();

        throw Exception('Akun Anda sedang menunggu verifikasi admin.');

      // } else if (status == 'rejected') {

      //   await logout();

      //   throw Exception('Maaf, pendaftaran vendor Anda ditolak.');

      }

    }

   

    return user;

  }
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
        'status': 'active',
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
          // 'status': 'pending',
          'is_active': true,
        });

        await _supabase.from('profiles_vendor').insert({
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
              profiles_vendor ( status ),
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
  
  
  // Tambahkan di dalam class AuthService
// static Future<List<Map<String, dynamic>>> getVendorEnrollments() async {
//   try {
//     // Mengambil data profile yang rolenya vendor beserta detail perusahaannya
//     final response = await _supabase
//         .from('profiles')
//         .select('*, profiles_vendor(*)')
//         .eq('role', 'vendor')
//         .order('created_at', ascending: false);
    
//     return List<Map<String, dynamic>>.from(response);
//   } catch (e) {
//     throw Exception('Gagal mengambil data enrollment: $e');
//   }
// }


static Future<List<Map<String, dynamic>>> getVendorEnrollments() async {
  try {
    // Kita melakukan join (*) dari profiles dan profiles_vendor
    final response = await _supabase
        .from('profiles')
        .select('*, profiles_vendor(*)')
        .eq('role', 'vendor')
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    throw Exception('Gagal mengambil data: $e');
  }
}

// static Future<List<Map<String, dynamic>>> getPendingVendorEnrollments() async {
//   try {
//     final response = await _supabase
//         .from('profiles')
//         .select('*, profiles_vendor(*)')
//         .eq('role', 'vendor')
//         .eq('status', 'pending') // Filter: Hanya tampilkan yang pending
//         .order('created_at', ascending: false);
    
//     return List<Map<String, dynamic>>.from(response);
//   } catch (e) {
//     throw Exception('Gagal mengambil data: $e');
//   }
// }

static Future<List<Map<String, dynamic>>> getPendingVendorEnrollments() async {
    try {
      // Kita memantau status yang ada di profiles_vendor
      final response = await _supabase
          .from('profiles_vendor')
          .select('*, profiles(*)')
          .eq('status', 'pending') 
          .order('profile_id', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data: $e');
    }
  }


// static Future<void> updateVendorStatus(String profileId, String status) async {
//   try {
//     await _supabase
//         .from('profiles_vendor')
//         .update({'status': status})
//         .eq('profile_id', profileId);
//   } catch (e) {
//     throw Exception('Gagal memperbarui status: $e');
//   }
// }

// static Future<void> updateVendorStatus(String userId, String newStatus) async {
//   try {
//     await Supabase.instance.client
//         .from('profiles')
//         .update({'status': newStatus})
//         .eq('id', userId);
//         if (newStatus == 'rejected') {
//        await _supabase.from('profiles').update({'is_active': false}).eq('id', userId);
//     }
//   } catch (e) {
//     throw Exception('Gagal memperbarui status: $e');
//   }
// }

static Future<void> updateVendorStatus(String userId, String newStatus) async {
    try {
      // --- PERBAIKAN 3: Update tabel profiles_vendor, bukan profiles ---
     await Supabase.instance.client
          .from('profiles_vendor')
          .update({'status': newStatus})
          .eq('profile_id', userId);
          //.select();

      // Jika ditolak, kita nonaktifkan akunnya di tabel profiles
      if (newStatus == 'rejected') {
        await _supabase
            .from('profiles')
            .update({'is_active': false})
            .eq('id', userId);
      } 
      // Jika diverifikasi, kita pastikan akun aktif
      else if (newStatus == 'verified') {
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

