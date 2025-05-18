class Badge {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category; // 성취, 루틴, 챌린지 등
  final int level; // 배지 레벨 (1, 2, 3 등)
  final String condition; // 획득 조건
  final bool isRare; // 희귀 배지 여부
  final dynamic createdAt;

  Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.level,
    required this.condition,
    required this.isRare,
    required this.createdAt,
  });

  Badge copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    int? level,
    String? condition,
    bool? isRare,
    dynamic createdAt,
  }) {
    return Badge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      level: level ?? this.level,
      condition: condition ?? this.condition,
      isRare: isRare ?? this.isRare,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'level': level,
      'condition': condition,
      'isRare': isRare,
      'createdAt': createdAt,
    };
  }

  factory Badge.fromMap(Map<String, dynamic> map, String docId) {
    return Badge(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      level: map['level'] ?? 1,
      condition: map['condition'] ?? '',
      isRare: map['isRare'] ?? false,
      createdAt: map['createdAt'],
    );
  }
}

class UserReward {
  final String id;
  final String uid;
  final int mileage; // 총 마일리지
  final List<String> badgeIds; // 획득한 배지 ID 목록
  final Map<String, int> categoryMileage; // 카테고리별 마일리지
  final int streak; // 최대 연속 달성 일수
  final int totalCompletedRoutines; // 총 완료한 루틴 수
  final int totalCompletedChallenges; // 총 완료한 챌린지 수
  final dynamic lastUpdatedAt;

  UserReward({
    required this.id,
    required this.uid,
    required this.mileage,
    required this.badgeIds,
    required this.categoryMileage,
    required this.streak,
    required this.totalCompletedRoutines,
    required this.totalCompletedChallenges,
    required this.lastUpdatedAt,
  });

  UserReward copyWith({
    String? id,
    String? uid,
    int? mileage,
    List<String>? badgeIds,
    Map<String, int>? categoryMileage,
    int? streak,
    int? totalCompletedRoutines,
    int? totalCompletedChallenges,
    dynamic lastUpdatedAt,
  }) {
    return UserReward(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      mileage: mileage ?? this.mileage,
      badgeIds: badgeIds ?? this.badgeIds,
      categoryMileage: categoryMileage ?? this.categoryMileage,
      streak: streak ?? this.streak,
      totalCompletedRoutines: totalCompletedRoutines ?? this.totalCompletedRoutines,
      totalCompletedChallenges: totalCompletedChallenges ?? this.totalCompletedChallenges,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'mileage': mileage,
      'badgeIds': badgeIds,
      'categoryMileage': categoryMileage,
      'streak': streak,
      'totalCompletedRoutines': totalCompletedRoutines,
      'totalCompletedChallenges': totalCompletedChallenges,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }

  factory UserReward.fromMap(Map<String, dynamic> map, String docId) {
    return UserReward(
      id: docId,
      uid: map['uid'] ?? '',
      mileage: map['mileage'] ?? 0,
      badgeIds: List<String>.from(map['badgeIds'] ?? []),
      categoryMileage: Map<String, int>.from(map['categoryMileage'] ?? {}),
      streak: map['streak'] ?? 0,
      totalCompletedRoutines: map['totalCompletedRoutines'] ?? 0,
      totalCompletedChallenges: map['totalCompletedChallenges'] ?? 0,
      lastUpdatedAt: map['lastUpdatedAt'],
    );
  }
}

class MiniChallenge {
  final String id;
  final String title;
  final String description;
  final int durationDays; // 챌린지 기간 (일)
  final int mileageReward; // 보상 마일리지
  final String? badgeId; // 보상 배지 ID (있는 경우)
  final List<Map<String, dynamic>> tasks; // 하위 작업 목록
  final String difficulty; // 쉬움, 보통, 어려움
  final dynamic createdAt;
  final bool isActive;

  MiniChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.mileageReward,
    this.badgeId,
    required this.tasks,
    required this.difficulty,
    required this.createdAt,
    required this.isActive,
  });

  MiniChallenge copyWith({
    String? id,
    String? title,
    String? description,
    int? durationDays,
    int? mileageReward,
    String? badgeId,
    List<Map<String, dynamic>>? tasks,
    String? difficulty,
    dynamic createdAt,
    bool? isActive,
  }) {
    return MiniChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      durationDays: durationDays ?? this.durationDays,
      mileageReward: mileageReward ?? this.mileageReward,
      badgeId: badgeId ?? this.badgeId,
      tasks: tasks ?? this.tasks,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'durationDays': durationDays,
      'mileageReward': mileageReward,
      'badgeId': badgeId,
      'tasks': tasks,
      'difficulty': difficulty,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }

  factory MiniChallenge.fromMap(Map<String, dynamic> map, String docId) {
    return MiniChallenge(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      durationDays: map['durationDays'] ?? 7,
      mileageReward: map['mileageReward'] ?? 0,
      badgeId: map['badgeId'],
      tasks: List<Map<String, dynamic>>.from(map['tasks'] ?? []),
      difficulty: map['difficulty'] ?? '보통',
      createdAt: map['createdAt'],
      isActive: map['isActive'] ?? true,
    );
  }
} 