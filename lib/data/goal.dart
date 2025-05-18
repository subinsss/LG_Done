class Goal {
  final String id;
  final String uid;
  final String title;
  final String description;
  final GoalTimeframe timeframe; // 단기(1개월), 중기(3개월), 장기(12개월)
  final DateTime startDate;
  final DateTime endDate;
  final List<String> subGoalIds; // 하위 목표 ID 목록
  final List<String> relatedRoutineIds; // 관련 루틴 ID 목록
  final bool isCompleted;
  final int progress; // 0-100 진행률
  final dynamic createdAt;
  final Map<String, dynamic>? emotionData; // 감정 데이터 추적 (날짜별)
  final Map<String, dynamic>? focusData; // 집중도 데이터 추적 (날짜별)
  final Map<String, dynamic>? fatigueData; // 피로도 데이터 추적 (날짜별)
  final List<String> achievementBadges; // 획득한 배지 목록

  Goal({
    required this.id,
    required this.uid,
    required this.title, 
    required this.description,
    required this.timeframe,
    required this.startDate,
    required this.endDate,
    required this.subGoalIds,
    required this.relatedRoutineIds,
    required this.isCompleted,
    required this.progress,
    required this.createdAt,
    this.emotionData,
    this.focusData,
    this.fatigueData,
    required this.achievementBadges,
  });

  Goal copyWith({
    String? id,
    String? uid,
    String? title,
    String? description,
    GoalTimeframe? timeframe,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? subGoalIds,
    List<String>? relatedRoutineIds,
    bool? isCompleted,
    int? progress,
    dynamic createdAt,
    Map<String, dynamic>? emotionData,
    Map<String, dynamic>? focusData,
    Map<String, dynamic>? fatigueData,
    List<String>? achievementBadges,
  }) {
    return Goal(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      description: description ?? this.description,
      timeframe: timeframe ?? this.timeframe,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      subGoalIds: subGoalIds ?? this.subGoalIds,
      relatedRoutineIds: relatedRoutineIds ?? this.relatedRoutineIds,
      isCompleted: isCompleted ?? this.isCompleted,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      emotionData: emotionData ?? this.emotionData,
      focusData: focusData ?? this.focusData,
      fatigueData: fatigueData ?? this.fatigueData,
      achievementBadges: achievementBadges ?? this.achievementBadges,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'timeframe': timeframeToString(timeframe),
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'subGoalIds': subGoalIds,
      'relatedRoutineIds': relatedRoutineIds,
      'isCompleted': isCompleted,
      'progress': progress,
      'createdAt': createdAt,
      'emotionData': emotionData,
      'focusData': focusData,
      'fatigueData': fatigueData,
      'achievementBadges': achievementBadges,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map, String docId) {
    return Goal(
      id: docId,
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      timeframe: stringToTimeframe(map['timeframe'] ?? 'SHORT'),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] ?? 0),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] ?? 0),
      subGoalIds: List<String>.from(map['subGoalIds'] ?? []),
      relatedRoutineIds: List<String>.from(map['relatedRoutineIds'] ?? []),
      isCompleted: map['isCompleted'] ?? false,
      progress: map['progress'] ?? 0,
      createdAt: map['createdAt'],
      emotionData: map['emotionData'],
      focusData: map['focusData'],
      fatigueData: map['fatigueData'],
      achievementBadges: List<String>.from(map['achievementBadges'] ?? []),
    );
  }
}

enum GoalTimeframe { SHORT, MEDIUM, LONG } // 단기(1개월), 중기(3개월), 장기(12개월)

String timeframeToString(GoalTimeframe timeframe) {
  switch (timeframe) {
    case GoalTimeframe.SHORT:
      return 'SHORT';
    case GoalTimeframe.MEDIUM:
      return 'MEDIUM';
    case GoalTimeframe.LONG:
      return 'LONG';
    default:
      return 'SHORT';
  }
}

GoalTimeframe stringToTimeframe(String value) {
  switch (value) {
    case 'SHORT':
      return GoalTimeframe.SHORT;
    case 'MEDIUM':
      return GoalTimeframe.MEDIUM;
    case 'LONG':
      return GoalTimeframe.LONG;
    default:
      return GoalTimeframe.SHORT;
  }
} 