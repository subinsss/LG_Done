class Task {
  final String id;
  final String uid;
  final String title;
  final String description;
  final int duration;
  final bool isCompleted;
  final dynamic createdAt;

  Task({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.duration,
    required this.isCompleted,
    required this.createdAt,
  });

  Task copyWith({
    String? id,
    String? uid,
    String? title,
    String? description,
    int? duration,
    bool? isCompleted,
    dynamic createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'duration': duration,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, String docId) {
    return Task(
      id: docId,
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      duration: map['duration'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      createdAt: map['createdAt'],
    );
  }
} 