/// Named AppNotification to avoid clashing with Flutter's `Notification`.
class AppNotification {
  final int id;
  final String title;
  final String message;
  final String status; // unread | read
  final String? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    this.createdAt,
  });

  bool get isUnread => status == 'unread';

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        title: (json['title'] ?? '') as String,
        message: (json['message'] ?? '') as String,
        status: (json['status'] ?? 'unread') as String,
        createdAt: json['created_at'] as String?,
      );

  AppNotification copyWith({String? status}) => AppNotification(
        id: id,
        title: title,
        message: message,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
