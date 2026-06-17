class ProjectAssignment {
  final int id;
  final int project;
  final int user;
  final String userName;
  final String role; // manager | officer

  const ProjectAssignment({
    required this.id,
    required this.project,
    required this.user,
    required this.userName,
    required this.role,
  });

  factory ProjectAssignment.fromJson(Map<String, dynamic> json) =>
      ProjectAssignment(
        id: json['id'] as int,
        project: json['project'] as int,
        user: json['user'] as int,
        userName: (json['user_name'] ?? '') as String,
        role: (json['role'] ?? '') as String,
      );
}
