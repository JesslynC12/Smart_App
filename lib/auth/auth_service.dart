import 'package:supabase_flutter/supabase_flutter.dart';

class User {
  final String id;
  final String email;
  final String nik;
  final String? role;
  final String? status; // Status Vendor
  final bool isActive;  // <--- TAMBAHAN PENTING
  final List<String> privileges;

  User({
    required this.id,
    required this.email,
    required this.nik,
    this.role,
    this.status,
    this.isActive = true, // Default true
    this.privileges = const [],
  });

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
      role: json['role'],
      status: statusValue,
      isActive: json['is_active'] ?? true, // <--- Mapping dari SQL
      privileges: privs,
    );
  }
}
class AuthService {
  static final _supabase = Supabase.instance.client;

  // --- LOGIN UNIVERSAL ---
  static Future<User?> login(String identifier, String password) async {
    try {
      String emailForAuth = identifier.trim();

      // 1. Cek User by NIK (Jika input bukan email)
      if (!identifier.contains('@')) {
        // Validasi NIK harus 8 digit sebelum query ke DB untuk hemat resource
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

      // 2. Sign In
      final response = await _supabase.auth.signInWithPassword(
        email: emailForAuth,
        password: password,
      );

      // 3. Cek Profile & Status Aktif
      if (response.user != null) {
        final user = await getCurrentUser();
        
        // PENCEGAHAN LOGIN JIKA AKUN NON-AKTIF
        if (user != null && !user.isActive) {
          await logout(); // Logout paksa
          throw Exception('Akun Anda telah dinonaktifkan oleh Admin.');
        }
        
        return user;
      }
      return null;
    } on AuthException catch (e) {
      // Supabase Auth specific errors
      throw Exception(e.message);
    } catch (e) {
      rethrow;
    }
  }

  // --- REGISTRASI VENDOR (Dengan Validasi & Rollback Manual) ---
  static Future<void> registerVendor({
    required String email,
    required String password,
    required String nik,
    required String companyName,
    required String address,
    required String city,
    required String phone,
  }) async {
    // 1. VALIDASI DI SISI DART AGAR TIDAK ERROR SQL
    if (nik.length != 8) {
      throw Exception('NIK harus tepat 8 karakter.');
    }

    // Cek apakah NIK sudah dipakai (Opsional tapi disarankan agar error lebih rapi)
    final checkNik = await _supabase.from('profiles').select('id').eq('nik', nik).maybeSingle();
    if (checkNik != null) throw Exception('NIK sudah terdaftar.');

    try {
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        final userId = response.user!.id;

        try {
          // 2. Simpan ke profiles
          await _supabase.from('profiles').insert({
            'id': userId,
            'email': email,
            'nik': nik,
            'role': 'vendor',
            'is_active': true,
          });

          // 3. Simpan ke vendor_details
          await _supabase.from('vendor_details').insert({
            'profile_id': userId,
            'nama_perusahaan': companyName,
            'alamat': address,
            'city': city,
            'phone': phone,
            'status': 'pending',
          });
        } catch (dbError) {
          // CRITICAL: Jika insert profile gagal (misal duplikat), 
          // HAPUS user di auth agar tidak jadi "sampah" (Orphan User)
          // Catatan: Ini membutuhkan Service Role Key di server side sebenarnya, 
          // tapi untuk client-side, kita setidaknya throw error yang jelas.
          throw Exception('Gagal membuat profil: $dbError. Silakan hubungi admin.');
        }
      }
    } catch (e) {
      throw Exception('Registrasi Gagal: ${e.toString()}');
    }
  }

  // --- REGISTRASI ADMIN ---
  static Future<void> registerAdmin({
    required String email,
    required String password,
    required String nik,
    required String role,
  }) async {
    if (nik.length != 8) {
      throw Exception('NIK harus tepat 8 karakter.');
    }

    try {
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email,
          'nik': nik,
          'role': role,
          'is_active': true,
        });
      }
    } catch (e) {
      throw Exception('Gagal registrasi admin: $e');
    }
  }

  // --- FUNGSI HELPER ---
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
}
