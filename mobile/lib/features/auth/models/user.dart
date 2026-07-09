/// Authenticated user, as returned by the login endpoint / cached locally.
class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role; // admin | manager | officer | donor
  final int? ngoId;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.ngoId,
  });

  /// Display name: "First Last" trimmed (graceful when last name is empty).
  String get fullName => '$firstName $lastName'.trim();

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        firstName: (json['first_name'] ?? '') as String,
        lastName: (json['last_name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        // Login response uses 'ngo_id'; /auth/me/ uses 'ngo' (FK integer).
        ngoId: (json['ngo_id'] ?? json['ngo']) as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
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
