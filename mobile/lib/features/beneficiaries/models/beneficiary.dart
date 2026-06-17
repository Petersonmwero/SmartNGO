class Beneficiary {
  final int id;
  final String name;
  final String gender;
  final String? dateOfBirth;
  final int? age;
  final String phone;
  final String location;
  final int project;
  final bool isActive;

  const Beneficiary({
    required this.id,
    required this.name,
    required this.gender,
    required this.project,
    required this.isActive,
    this.dateOfBirth,
    this.age,
    this.phone = '',
    this.location = '',
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        gender: (json['gender'] ?? '') as String,
        dateOfBirth: json['date_of_birth'] as String?,
        age: json['age'] as int?,
        phone: (json['phone'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        project: json['project'] as int,
        isActive: (json['is_active'] ?? true) as bool,
      );
}
