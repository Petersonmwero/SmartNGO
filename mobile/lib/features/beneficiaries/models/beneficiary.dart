class Beneficiary {
  final int id;
  final String name;
  final String gender;
  final String? dateOfBirth;
  final int? age;
  final String phone;
  final String country;
  final String county;
  final String constituency;
  final String ward;
  final String location;
  final String subLocation;
  final String village;
  final String fullLocation;
  final int project;
  final String projectName;
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
    this.country = 'Kenya',
    this.county = '',
    this.constituency = '',
    this.ward = '',
    this.location = '',
    this.subLocation = '',
    this.village = '',
    this.fullLocation = '',
    this.projectName = '',
  });

  /// Compact card line: the three most specific non-empty parts, e.g.
  /// "Sub-Location · Location · Ward", degrading to
  /// "Location · Ward · Constituency" and "Ward · Constituency · County".
  String get locationSummary => [subLocation, location, ward, constituency, county]
      .where((p) => p.isNotEmpty)
      .take(3)
      .join(' · ');

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        gender: (json['gender'] ?? '') as String,
        dateOfBirth: json['date_of_birth'] as String?,
        age: json['age'] as int?,
        phone: (json['phone'] ?? '') as String,
        country: (json['country'] ?? 'Kenya') as String,
        county: (json['county'] ?? '') as String,
        constituency: (json['constituency'] ?? '') as String,
        ward: (json['ward'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        subLocation: (json['sub_location'] ?? '') as String,
        village: (json['village'] ?? '') as String,
        fullLocation: (json['full_location'] ?? '') as String,
        project: json['project'] as int,
        projectName: (json['project_name'] ?? '') as String,
        isActive: (json['is_active'] ?? true) as bool,
      );
}
