class Routine {
  final String id;
  final String uid;
  final String title;
  final String description;
  final String category;
  final int duration;
  final List<String> weekdays; // 요일별 반복 설정 (월,화,수,목,금,토,일)
  final DateTime timeOfDay; // 하루 중 시작 시간
  final bool isCompleted;
  final int streakCount; // 연속 달성 횟수
  final dynamic createdAt;
  final dynamic lastCompletedAt;
  final bool hasAlternative; // 대체 루틴 존재 여부
  final String? alternativeId; // 대체 루틴 ID (있는 경우)
  final int failureCount; // 실패 횟수
  final Map<String, dynamic>? weatherCondition; // 날씨 조건 설정
  final int mileage; // 적립된 마일리지

  Routine({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.category,
    required this.duration,
    required this.weekdays,
    required this.timeOfDay,
    required this.isCompleted,
    required this.streakCount,
    required this.createdAt,
    this.lastCompletedAt,
    this.hasAlternative = false,
    this.alternativeId,
    this.failureCount = 0,
    this.weatherCondition,
    this.mileage = 0,
  });

  Routine copyWith({
    String? id,
    String? uid,
    String? title,
    String? description,
    String? category,
    int? duration,
    List<String>? weekdays,
    DateTime? timeOfDay,
    bool? isCompleted,
    int? streakCount,
    dynamic createdAt,
    dynamic lastCompletedAt,
    bool? hasAlternative,
    String? alternativeId,
    int? failureCount,
    Map<String, dynamic>? weatherCondition,
    int? mileage,
  }) {
    return Routine(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      weekdays: weekdays ?? this.weekdays,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      isCompleted: isCompleted ?? this.isCompleted,
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt ?? this.createdAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      hasAlternative: hasAlternative ?? this.hasAlternative,
      alternativeId: alternativeId ?? this.alternativeId,
      failureCount: failureCount ?? this.failureCount,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      mileage: mileage ?? this.mileage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'category': category,
      'duration': duration,
      'weekdays': weekdays,
      'timeOfDay': timeOfDay.millisecondsSinceEpoch,
      'isCompleted': isCompleted,
      'streakCount': streakCount,
      'createdAt': createdAt,
      'lastCompletedAt': lastCompletedAt,
      'hasAlternative': hasAlternative,
      'alternativeId': alternativeId,
      'failureCount': failureCount,
      'weatherCondition': weatherCondition,
      'mileage': mileage,
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map, String docId) {
    return Routine(
      id: docId,
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      duration: map['duration'] ?? 0,
      weekdays: List<String>.from(map['weekdays'] ?? []),
      timeOfDay: DateTime.fromMillisecondsSinceEpoch(map['timeOfDay'] ?? 0),
      isCompleted: map['isCompleted'] ?? false,
      streakCount: map['streakCount'] ?? 0,
      createdAt: map['createdAt'],
      lastCompletedAt: map['lastCompletedAt'],
      hasAlternative: map['hasAlternative'] ?? false,
      alternativeId: map['alternativeId'],
      failureCount: map['failureCount'] ?? 0,
      weatherCondition: map['weatherCondition'],
      mileage: map['mileage'] ?? 0,
    );
  }
} 