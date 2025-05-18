class MicroRoutine {
  final String id;
  final String uid;
  final String title;
  final String description;
  final int duration; // 5-10분 사이의 짧은 시간
  final List<String> tags; // 독서, 스트레칭 등 분류 태그
  final bool isCompleted;
  final bool hasAudio; // 오디오 안내 여부
  final String? audioUrl; // 오디오 파일 URL (있는 경우)
  final bool hasWidget; // 위젯 표시 여부
  final String? widgetType; // 위젯 타입 (있는 경우)
  final dynamic createdAt;
  final dynamic lastCompletedAt;
  final int completionCount; // 완료 횟수
  final List<String> timeSlots; // 권장 시간대 (아침, 통근시간, 점심시간 등)
  final bool isSocialShared; // 소셜 공유 여부

  MicroRoutine({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.duration,
    required this.tags,
    required this.isCompleted,
    required this.hasAudio,
    this.audioUrl,
    required this.hasWidget,
    this.widgetType,
    required this.createdAt,
    this.lastCompletedAt,
    required this.completionCount,
    required this.timeSlots,
    required this.isSocialShared,
  });

  MicroRoutine copyWith({
    String? id,
    String? uid,
    String? title,
    String? description,
    int? duration,
    List<String>? tags,
    bool? isCompleted,
    bool? hasAudio,
    String? audioUrl,
    bool? hasWidget,
    String? widgetType,
    dynamic createdAt,
    dynamic lastCompletedAt,
    int? completionCount,
    List<String>? timeSlots,
    bool? isSocialShared,
  }) {
    return MicroRoutine(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      tags: tags ?? this.tags,
      isCompleted: isCompleted ?? this.isCompleted,
      hasAudio: hasAudio ?? this.hasAudio,
      audioUrl: audioUrl ?? this.audioUrl,
      hasWidget: hasWidget ?? this.hasWidget,
      widgetType: widgetType ?? this.widgetType,
      createdAt: createdAt ?? this.createdAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      completionCount: completionCount ?? this.completionCount,
      timeSlots: timeSlots ?? this.timeSlots,
      isSocialShared: isSocialShared ?? this.isSocialShared,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'duration': duration,
      'tags': tags,
      'isCompleted': isCompleted,
      'hasAudio': hasAudio,
      'audioUrl': audioUrl,
      'hasWidget': hasWidget,
      'widgetType': widgetType,
      'createdAt': createdAt,
      'lastCompletedAt': lastCompletedAt,
      'completionCount': completionCount,
      'timeSlots': timeSlots,
      'isSocialShared': isSocialShared,
    };
  }

  factory MicroRoutine.fromMap(Map<String, dynamic> map, String docId) {
    return MicroRoutine(
      id: docId,
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      duration: map['duration'] ?? 5,
      tags: List<String>.from(map['tags'] ?? []),
      isCompleted: map['isCompleted'] ?? false,
      hasAudio: map['hasAudio'] ?? false,
      audioUrl: map['audioUrl'],
      hasWidget: map['hasWidget'] ?? false,
      widgetType: map['widgetType'],
      createdAt: map['createdAt'],
      lastCompletedAt: map['lastCompletedAt'],
      completionCount: map['completionCount'] ?? 0,
      timeSlots: List<String>.from(map['timeSlots'] ?? []),
      isSocialShared: map['isSocialShared'] ?? false,
    );
  }
} 