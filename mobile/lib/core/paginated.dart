/// Wrapper for DRF's paginated list response: {count, next, previous, results}.
class Paginated<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  Paginated({
    required this.count,
    required this.results,
    this.next,
    this.previous,
  });

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final raw = (json['results'] as List? ?? const []);
    return Paginated(
      count: json['count'] as int? ?? raw.length,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: raw
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  bool get hasNext => next != null;
}
