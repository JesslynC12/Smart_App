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