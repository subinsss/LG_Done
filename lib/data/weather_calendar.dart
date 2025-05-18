class WeatherData {
  final String id;
  final String location;
  final DateTime date;
  final String condition; // 맑음, 흐림, 비, 눈 등
  final double temperature;
  final double humidity;
  final double precipitation; // 강수량
  final double windSpeed;
  final dynamic createdAt;
  final dynamic updatedAt;

  WeatherData({
    required this.id,
    required this.location,
    required this.date,
    required this.condition,
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.createdAt,
    required this.updatedAt,
  });

  WeatherData copyWith({
    String? id,
    String? location,
    DateTime? date,
    String? condition,
    double? temperature,
    double? humidity,
    double? precipitation,
    double? windSpeed,
    dynamic createdAt,
    dynamic updatedAt,
  }) {
    return WeatherData(
      id: id ?? this.id,
      location: location ?? this.location,
      date: date ?? this.date,
      condition: condition ?? this.condition,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      precipitation: precipitation ?? this.precipitation,
      windSpeed: windSpeed ?? this.windSpeed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location': location,
      'date': date.millisecondsSinceEpoch,
      'condition': condition,
      'temperature': temperature,
      'humidity': humidity,
      'precipitation': precipitation,
      'windSpeed': windSpeed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory WeatherData.fromMap(Map<String, dynamic> map, String docId) {
    return WeatherData(
      id: docId,
      location: map['location'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      condition: map['condition'] ?? '',
      temperature: map['temperature']?.toDouble() ?? 0.0,
      humidity: map['humidity']?.toDouble() ?? 0.0,
      precipitation: map['precipitation']?.toDouble() ?? 0.0,
      windSpeed: map['windSpeed']?.toDouble() ?? 0.0,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}

class CalendarEvent {
  final String id;
  final String uid;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String location;
  final String category; // 업무, 개인, 가족 등
  final bool isRecurring;
  final String? recurrenceRule; // 반복 규칙
  final List<String>? relatedRoutineIds; // 관련 루틴 ID
  final dynamic createdAt;

  CalendarEvent({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.location,
    required this.category,
    required this.isRecurring,
    this.recurrenceRule,
    this.relatedRoutineIds,
    required this.createdAt,
  });

  CalendarEvent copyWith({
    String? id,
    String? uid,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    String? category,
    bool? isRecurring,
    String? recurrenceRule,
    List<String>? relatedRoutineIds,
    dynamic createdAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      category: category ?? this.category,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      relatedRoutineIds: relatedRoutineIds ?? this.relatedRoutineIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'isAllDay': isAllDay,
      'location': location,
      'category': category,
      'isRecurring': isRecurring,
      'recurrenceRule': recurrenceRule,
      'relatedRoutineIds': relatedRoutineIds,
      'createdAt': createdAt,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map, String docId) {
    return CalendarEvent(
      id: docId,
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] ?? 0),
      isAllDay: map['isAllDay'] ?? false,
      location: map['location'] ?? '',
      category: map['category'] ?? '',
      isRecurring: map['isRecurring'] ?? false,
      recurrenceRule: map['recurrenceRule'],
      relatedRoutineIds: map['relatedRoutineIds'] != null
          ? List<String>.from(map['relatedRoutineIds'])
          : null,
      createdAt: map['createdAt'],
    );
  }
}

class RoutineWarning {
  final String id;
  final String routineId;
  final String uid;
  final DateTime date;
  final String warningType; // 날씨, 일정 충돌 등
  final String description;
  final String? alternativeRoutineId;
  final bool isResolved;
  final dynamic createdAt;

  RoutineWarning({
    required this.id,
    required this.routineId,
    required this.uid,
    required this.date,
    required this.warningType,
    required this.description,
    this.alternativeRoutineId,
    required this.isResolved,
    required this.createdAt,
  });

  RoutineWarning copyWith({
    String? id,
    String? routineId,
    String? uid,
    DateTime? date,
    String? warningType,
    String? description,
    String? alternativeRoutineId,
    bool? isResolved,
    dynamic createdAt,
  }) {
    return RoutineWarning(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      uid: uid ?? this.uid,
      date: date ?? this.date,
      warningType: warningType ?? this.warningType,
      description: description ?? this.description,
      alternativeRoutineId: alternativeRoutineId ?? this.alternativeRoutineId,
      isResolved: isResolved ?? this.isResolved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routineId': routineId,
      'uid': uid,
      'date': date.millisecondsSinceEpoch,
      'warningType': warningType,
      'description': description,
      'alternativeRoutineId': alternativeRoutineId,
      'isResolved': isResolved,
      'createdAt': createdAt,
    };
  }

  factory RoutineWarning.fromMap(Map<String, dynamic> map, String docId) {
    return RoutineWarning(
      id: docId,
      routineId: map['routineId'] ?? '',
      uid: map['uid'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      warningType: map['warningType'] ?? '',
      description: map['description'] ?? '',
      alternativeRoutineId: map['alternativeRoutineId'],
      isResolved: map['isResolved'] ?? false,
      createdAt: map['createdAt'],
    );
  }
} 