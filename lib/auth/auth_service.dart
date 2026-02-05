import 'package:supabase_flutter/supabase_flutter.dart';


class User {
  final String id;
  final String email;
  final String nik;
  final String? role;
  final String? status;
  final List<String> privileges;


  User({
    required this.id,
    required this.email,
    required this.nik,
    this.role,
    this.status,
    this.privileges = const [],
  });


  factory User.fromJson(Map<String, dynamic> json) {
    // Parsing privileges dari nested list
    List<String> privs = [];
    if (json['profile_privileges'] != null && json['profile_privileges'] is List) {
      for (var item in json['profile_privileges']) {
        if (item['privileges'] != null) {
          privs.add(item['privileges']['name'].toString());
        }
      }
    }


    // Parsing status dari join vendor_details (dikembalikan sebagai List oleh Supabase)
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
      privileges: privs,
    );
  }
}


class AuthService {
  static final _supabase = Supabase.instance.client;


  // --- LOGIN UNIVERSAL (Mendukung NIK 8 Digit atau Email) ---
  static Future<User?> login(String identifier, String password) async {
    try {
      String emailForAuth = identifier.trim();


      // Jika input bukan email (tidak ada '@'), cari email berdasarkan NIK di tabel profiles
      if (!identifier.contains('@')) {
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
        return await getCurrentUser();
      }
      return null;
    } on AuthException catch (e) {
      throw Exception('Password salah atau akun tidak ditemukan');
    } catch (e) {
      rethrow;
    }
  }


  // --- REGISTRASI VENDOR ---
  static Future<void> registerVendor({
    required String email,
    required String password,
    required String nik,
    required String companyName,
    required String address,
    required String city,
    required String phone,
  }) async {
    try {
      final response = await _supabase.auth.signUp(email: email, password: password);


      if (response.user != null) {
        final userId = response.user!.id;


        // 1. Simpan ke profiles
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          'nik': nik,
          'role': 'vendor',
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
      }
    } catch (e) {
      throw Exception('Gagal registrasi vendor: $e');
    }
  }


  // --- REGISTRASI ADMIN ---
  static Future<void> registerAdmin({
    required String email,
    required String password,
    required String nik,
    required String role,
  }) async {
    try {
      final response = await _supabase.auth.signUp(email: email, password: password);


      if (response.user != null) {
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email,
          'nik': nik,
          'role': role,
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

