class LearningHubRoom {
  final String id;
  final String title;
  final String description;
  final String category; // 예: 시험준비, 자격증, 취미, 운동 등
  final String creatorUid;
  final List<String> memberUids; // 참여 멤버 UID 목록
  final int maxMembers; // 최대 참여 인원
  final List<String> challengeIds; // 챌린지 ID 목록
  final List<String> resourceIds; // 리소스 ID 목록
  final int trustScore; // 신뢰도 점수 (0-100)
  final dynamic createdAt;
  final bool isPublic; // 공개 여부
  final Map<String, dynamic>? stats; // 통계 정보

  LearningHubRoom({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.creatorUid,
    required this.memberUids,
    required this.maxMembers,
    required this.challengeIds,
    required this.resourceIds,
    required this.trustScore,
    required this.createdAt,
    required this.isPublic,
    this.stats,
  });

  LearningHubRoom copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? creatorUid,
    List<String>? memberUids,
    int? maxMembers,
    List<String>? challengeIds,
    List<String>? resourceIds,
    int? trustScore,
    dynamic createdAt,
    bool? isPublic,
    Map<String, dynamic>? stats,
  }) {
    return LearningHubRoom(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      creatorUid: creatorUid ?? this.creatorUid,
      memberUids: memberUids ?? this.memberUids,
      maxMembers: maxMembers ?? this.maxMembers,
      challengeIds: challengeIds ?? this.challengeIds,
      resourceIds: resourceIds ?? this.resourceIds,
      trustScore: trustScore ?? this.trustScore,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
      stats: stats ?? this.stats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'creatorUid': creatorUid,
      'memberUids': memberUids,
      'maxMembers': maxMembers,
      'challengeIds': challengeIds,
      'resourceIds': resourceIds,
      'trustScore': trustScore,
      'createdAt': createdAt,
      'isPublic': isPublic,
      'stats': stats,
    };
  }

  factory LearningHubRoom.fromMap(Map<String, dynamic> map, String docId) {
    return LearningHubRoom(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      memberUids: List<String>.from(map['memberUids'] ?? []),
      maxMembers: map['maxMembers'] ?? 10,
      challengeIds: List<String>.from(map['challengeIds'] ?? []),
      resourceIds: List<String>.from(map['resourceIds'] ?? []),
      trustScore: map['trustScore'] ?? 0,
      createdAt: map['createdAt'],
      isPublic: map['isPublic'] ?? true,
      stats: map['stats'],
    );
  }
}

class LearningResource {
  final String id;
  final String hubId; // 소속된 허브 ID
  final String title;
  final String description;
  final String type; // 문서, 비디오, 오디오, 링크 등
  final String url;
  final String uploaderUid;
  final int trustScore; // 신뢰도 점수 (0-100)
  final List<String> tags;
  final int viewCount;
  final List<String> likedByUids;
  final Map<String, dynamic>? reviews; // 리뷰 정보
  final dynamic createdAt;

  LearningResource({
    required this.id,
    required this.hubId,
    required this.title,
    required this.description,
    required this.type,
    required this.url,
    required this.uploaderUid,
    required this.trustScore,
    required this.tags,
    required this.viewCount,
    required this.likedByUids,
    this.reviews,
    required this.createdAt,
  });

  LearningResource copyWith({
    String? id,
    String? hubId,
    String? title,
    String? description,
    String? type,
    String? url,
    String? uploaderUid,
    int? trustScore,
    List<String>? tags,
    int? viewCount,
    List<String>? likedByUids,
    Map<String, dynamic>? reviews,
    dynamic createdAt,
  }) {
    return LearningResource(
      id: id ?? this.id,
      hubId: hubId ?? this.hubId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      url: url ?? this.url,
      uploaderUid: uploaderUid ?? this.uploaderUid,
      trustScore: trustScore ?? this.trustScore,
      tags: tags ?? this.tags,
      viewCount: viewCount ?? this.viewCount,
      likedByUids: likedByUids ?? this.likedByUids,
      reviews: reviews ?? this.reviews,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hubId': hubId,
      'title': title,
      'description': description,
      'type': type,
      'url': url,
      'uploaderUid': uploaderUid,
      'trustScore': trustScore,
      'tags': tags,
      'viewCount': viewCount,
      'likedByUids': likedByUids,
      'reviews': reviews,
      'createdAt': createdAt,
    };
  }

  factory LearningResource.fromMap(Map<String, dynamic> map, String docId) {
    return LearningResource(
      id: docId,
      hubId: map['hubId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? '',
      url: map['url'] ?? '',
      uploaderUid: map['uploaderUid'] ?? '',
      trustScore: map['trustScore'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      viewCount: map['viewCount'] ?? 0,
      likedByUids: List<String>.from(map['likedByUids'] ?? []),
      reviews: map['reviews'],
      createdAt: map['createdAt'],
    );
  }
}

class Challenge {
  final String id;
  final String hubId; // 소속된 허브 ID
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> participantUids;
  final Map<String, dynamic> progressByUser; // 사용자별 진행 상황
  final List<String> goalIds; // 관련 목표 ID
  final List<String> routineIds; // 관련 루틴 ID
  final dynamic createdAt;
  final String creatorUid;
  final bool isActive;

  Challenge({
    required this.id,
    required this.hubId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.participantUids,
    required this.progressByUser,
    required this.goalIds,
    required this.routineIds,
    required this.createdAt,
    required this.creatorUid,
    required this.isActive,
  });

  Challenge copyWith({
    String? id,
    String? hubId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? participantUids,
    Map<String, dynamic>? progressByUser,
    List<String>? goalIds,
    List<String>? routineIds,
    dynamic createdAt,
    String? creatorUid,
    bool? isActive,
  }) {
    return Challenge(
      id: id ?? this.id,
      hubId: hubId ?? this.hubId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      participantUids: participantUids ?? this.participantUids,
      progressByUser: progressByUser ?? this.progressByUser,
      goalIds: goalIds ?? this.goalIds,
      routineIds: routineIds ?? this.routineIds,
      createdAt: createdAt ?? this.createdAt,
      creatorUid: creatorUid ?? this.creatorUid,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hubId': hubId,
      'title': title,
      'description': description,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'participantUids': participantUids,
      'progressByUser': progressByUser,
      'goalIds': goalIds,
      'routineIds': routineIds,
      'createdAt': createdAt,
      'creatorUid': creatorUid,
      'isActive': isActive,
    };
  }

  factory Challenge.fromMap(Map<String, dynamic> map, String docId) {
    return Challenge(
      id: docId,
      hubId: map['hubId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] ?? 0),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] ?? 0),
      participantUids: List<String>.from(map['participantUids'] ?? []),
      progressByUser: Map<String, dynamic>.from(map['progressByUser'] ?? {}),
      goalIds: List<String>.from(map['goalIds'] ?? []),
      routineIds: List<String>.from(map['routineIds'] ?? []),
      createdAt: map['createdAt'],
      creatorUid: map['creatorUid'] ?? '',
      isActive: map['isActive'] ?? false,
    );
  }
} 