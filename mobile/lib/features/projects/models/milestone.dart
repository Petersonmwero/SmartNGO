class Milestone {
  final int id;
  final int project;
  final String title;
  final String description;
  final String? dueDate;
  final String status; // pending | completed | overdue

  const Milestone({
    required this.id,
    required this.project,
    required this.title,
    required this.description,
    required this.status,
    this.dueDate,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as int,
        project: json['project'] as int,
        title: (json['title'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        dueDate: json['due_date'] as String?,
        status: (json['status'] ?? 'pending') as String,
      );
}
