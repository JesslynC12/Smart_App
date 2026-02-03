import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:project_app/home_page.dart';

class User {
  final String id;
  final String email;
  final String? username;
  final String? role;
  final String? status; // Khusus untuk Vendor (pending/approved)
  final List<String> privileges; // Daftar hak akses fitur

  User({
    required this.id,
    required this.email,
    this.username,
    this.role,
    this.status,
    this.privileges = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // 1. Ambil list privileges dari nested join
    List<String> privs = [];
    if (json['profile_privileges'] != null) {
      for (var item in json['profile_privileges']) {
        if (item['privileges'] != null) {
          privs.add(item['privileges']['name']);
        }
      }
    }

    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
      role: json['role'],
      // 2. Ambil status dari join vendor_details (jika ada)
      status: json['vendor_details'] != null ? json['vendor_details']['status'] : null,
      privileges: privs,
    );
  }
}

class AuthService {
  static final _supabase = Supabase.instance.client;

  // --- INITIALIZE ---
  static Future<void> initializeSupabase({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  // --- REGISTRASI VENDOR ---
  static Future<void> registerVendor({
    required String email,
    required String password,
    required String username,
    required String companyName,
    required String address,
    required String city,
    required String phone,
  }) async {
    try {
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        final userId = response.user!.id;

        // Simpan data identitas dasar
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          'username': username,
          'role': 'vendor',
        });

        // Simpan metadata perusahaan ke tabel terpisah (Pilihan B)
        await _supabase.from('vendor_details').insert({
          'profile_id': userId,
          'nama_perusahaan': companyName,
          'alamat': address,
          'city': city,
          'phone': phone,
          'status': 'pending', // Vendor baru wajib pending
        });
      }
    } catch (e) {
      throw Exception('Gagal registrasi vendor: $e');
    }
  }

  // --- REGISTRASI ADMIN INTERNAL ---
  static Future<void> registerAdmin({
    required String email,
    required String password,
    required String username,
    required String role, // misal: 'admin_ppic', 'admin_logistic', 'admin_gudang'
  }) async {
    try {
      final response = await _supabase.auth.signUp(email: email, password: password);

      if (response.user != null) {
        // Admin hanya masuk ke tabel profiles
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email,
          'username': username,
          'role': role,
        });
      }
    } catch (e) {
      throw Exception('Gagal registrasi admin: $e');
    }
  }

  // --- LOGIN UNIVERSAL ---
  static Future<User?> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Ambil profile + metadata vendor + privileges dalam satu query
        final userData = await _supabase
            .from('profiles')
            .select('''
              *,
              vendor_details ( status ),
              profile_privileges (
                privileges ( name )
              )
            ''')
            .eq('id', response.user!.id)
            .single();

        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      throw Exception('Login gagal: $e');
    }
  }

  // --- FUNGSI PENDUKUNG ---
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