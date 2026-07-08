/// Authenticated user, as returned by the login endpoint / cached locally.
class User {
  final int id;
  final String fullName;
  final String email;
  final String role; // admin | manager | officer | donor
  final int? ngoId;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.ngoId,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        fullName: (json['full_name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        // Login response uses 'ngo_id'; /auth/me/ uses 'ngo' (FK integer).
        ngoId: (json['ngo_id'] ?? json['ngo']) as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'role': role,
        'ngo_id': ngoId,
      };

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Project Manager';
      case 'officer':
        return 'Field Officer';
      case 'donor':
        return 'Donor';
      default:
        return role;
    }
  }
}
