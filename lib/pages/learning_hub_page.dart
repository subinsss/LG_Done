import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/learning_hub.dart';
import 'package:intl/intl.dart';

class LearningHubPage extends StatefulWidget {
  const LearningHubPage({super.key});

  @override
  State<LearningHubPage> createState() => _LearningHubPageState();
}

class _LearningHubPageState extends State<LearningHubPage> {
  List<LearningHubRoom> _rooms = [];
  List<Challenge> _challenges = [];
  List<LearningResource> _resources = [];
  bool _isLoading = true;
  String? _userId;
  String _selectedCategory = '전체';

  final List<String> _categories = [
    '전체',
    '시험준비',
    '자격증',
    '취미',
    '운동',
    '언어',
    '기술',
  ];

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 참여 중인 허브 목록 가져오기
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('learning_hub_rooms')
          .where('memberUids', arrayContains: _userId)
          .get();

      final rooms = roomsSnapshot.docs
          .map((doc) => LearningHubRoom.fromMap(doc.data(), doc.id))
          .toList();

      // 추천 리소스 가져오기
      // 실제 구현에서는 사용자 관심사, 활동 기록 등을 기반으로 추천 알고리즘 적용
      final resourcesSnapshot = await FirebaseFirestore.instance
          .collection('learning_resources')
          .orderBy('trustScore', descending: true)
          .limit(10)
          .get();

      final resources = resourcesSnapshot.docs
          .map((doc) => LearningResource.fromMap(doc.data(), doc.id))
          .toList();

      // 참여 가능한 챌린지 목록 가져오기
      final challengesSnapshot = await FirebaseFirestore.instance
          .collection('challenges')
          .where('isActive', isEqualTo: true)
          .get();

      final challenges = challengesSnapshot.docs
          .map((doc) => Challenge.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _rooms = rooms;
        _resources = resources;
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e) {
      print('학습 허브 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 큐레이션 학습 허브'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 검색 기능
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryFilter(),
                    const SizedBox(height: 16),
                    _buildMyRoomsSection(),
                    const SizedBox(height: 24),
                    _buildChallengesSection(),
                    const SizedBox(height: 24),
                    _buildRecommendedResourcesSection(),
                    const SizedBox(height: 24),
                    _buildRecommendedRoomsSection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateRoomDialog();
        },
        icon: const Icon(Icons.add),
        label: const Text('새 학습룸 만들기'),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyRoomsSection() {
    final filteredRooms = _selectedCategory == '전체'
        ? _rooms
        : _rooms.where((room) => room.category == _selectedCategory).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '내 학습룸',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // 전체 보기
                },
                child: const Text('전체 보기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          filteredRooms.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('참여 중인 학습룸이 없습니다. 새 학습룸을 만들거나 다른 사람의 학습룸에 참여해보세요.'),
                  ),
                )
              : SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      return _buildRoomCard(room);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(LearningHubRoom room) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            // 룸 상세 페이지로 이동
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(room.category).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        room.category,
                        style: TextStyle(
                          color: _getCategoryColor(room.category),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.people,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${room.memberUids.length}/${room.maxMembers}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  room.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '신뢰도: ${room.trustScore}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${room.challengeIds.length} 챌린지',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.article,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${room.resourceIds.length} 자료',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengesSection() {
    final filteredChallenges = _selectedCategory == '전체'
        ? _challenges
        : _challenges.where((challenge) {
            final room = _rooms.firstWhere(
              (r) => r.id == challenge.hubId,
              orElse: () => LearningHubRoom(
                id: '',
                title: '',
                description: '',
                category: '',
                creatorUid: '',
                memberUids: [],
                maxMembers: 0,
                challengeIds: [],
                resourceIds: [],
                trustScore: 0,
                createdAt: null,
                isPublic: true,
              ),
            );
            return room.category == _selectedCategory;
          }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '참여 가능한 챌린지',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // 전체 보기
                },
                child: const Text('전체 보기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          filteredChallenges.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('현재 참여 가능한 챌린지가 없습니다.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredChallenges.length > 3 ? 3 : filteredChallenges.length,
                  itemBuilder: (context, index) {
                    final challenge = filteredChallenges[index];
                    return _buildChallengeCard(challenge);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    final room = _rooms.firstWhere(
      (r) => r.id == challenge.hubId,
      orElse: () => LearningHubRoom(
        id: '',
        title: '알 수 없는 학습룸',
        description: '',
        category: '',
        creatorUid: '',
        memberUids: [],
        maxMembers: 0,
        challengeIds: [],
        resourceIds: [],
        trustScore: 0,
        createdAt: null,
        isPublic: true,
      ),
    );

    final startDate = DateFormat('MM/dd').format(challenge.startDate);
    final endDate = DateFormat('MM/dd').format(challenge.endDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // 챌린지 상세 페이지로 이동
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '챌린지',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    room.title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$startDate - $endDate',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                challenge.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                challenge.description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.participantUids.length}명 참여 중',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      // 챌린지 참여하기
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 30),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('참여하기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedResourcesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI 추천 학습 자료',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // 전체 보기
                },
                child: const Text('전체 보기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _resources.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('추천 학습 자료가 없습니다.'),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _resources.length,
                    itemBuilder: (context, index) {
                      final resource = _resources[index];
                      return _buildResourceCard(resource);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(LearningResource resource) {
    IconData typeIcon;
    String typeText;

    switch (resource.type.toLowerCase()) {
      case 'video':
        typeIcon = Icons.video_library;
        typeText = '동영상';
        break;
      case 'document':
        typeIcon = Icons.description;
        typeText = '문서';
        break;
      case 'audio':
        typeIcon = Icons.headphones;
        typeText = '오디오';
        break;
      case 'link':
        typeIcon = Icons.link;
        typeText = '링크';
        break;
      default:
        typeIcon = Icons.article;
        typeText = '자료';
    }

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            // 리소스 상세 페이지로 이동
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            typeIcon,
                            size: 12,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            typeText,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: resource.trustScore > 70
                              ? Colors.green
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${resource.trustScore}',
                          style: TextStyle(
                            fontSize: 10,
                            color: resource.trustScore > 70
                                ? Colors.green
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  resource.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  resource.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${resource.viewCount}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.thumb_up,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${resource.likedByUids.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedRoomsSection() {
    // 학습 허브 추천 로직 (실제 앱에서는 사용자 데이터 기반 AI 추천)
    final recommendedRooms = [
      {
        'title': '수능 국어 스터디',
        'category': '시험준비',
        'members': 15,
        'maxMembers': 20,
        'trustScore': 92,
        'description': '수능 국어 문제 분석 및 해결 전략 공유 그룹입니다.',
      },
      {
        'title': '정보처리기사 준비방',
        'category': '자격증',
        'members': 8,
        'maxMembers': 15,
        'trustScore': 87,
        'description': '정보처리기사 시험 준비 및 실습 문제 풀이 공간입니다.',
      },
      {
        'title': '파이썬 코딩 클럽',
        'category': '기술',
        'members': 12,
        'maxMembers': 25,
        'trustScore': 95,
        'description': '파이썬 기초부터 응용까지 함께 공부하는 공간입니다.',
      },
      {
        'title': '영어 회화 스터디',
        'category': '언어',
        'members': 7,
        'maxMembers': 10,
        'trustScore': 89,
        'description': '원어민과 함께하는 영어 회화 스터디 그룹입니다.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '추천 학습룸',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommendedRooms.length,
            itemBuilder: (context, index) {
              final room = recommendedRooms[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    // 학습룸 상세 정보 페이지로 이동
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(room['category'] as String),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (room['title'] as String).substring(0, 1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(room['category'] as String)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      room['category'] as String,
                                      style: TextStyle(
                                        color: _getCategoryColor(room['category'] as String),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.people,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${room['members']}/${room['maxMembers']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: (room['trustScore'] as int) > 90
                                        ? Colors.green
                                        : Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${room['trustScore']}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: (room['trustScore'] as int) > 90
                                          ? Colors.green
                                          : Colors.amber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                room['description'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () {
                // 추천 학습룸 더보기
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 40),
              ),
              child: const Text('더 많은 학습룸 보기'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case '시험준비':
        return Colors.blue;
      case '자격증':
        return Colors.green;
      case '취미':
        return Colors.amber;
      case '운동':
        return Colors.orange;
      case '언어':
        return Colors.purple;
      case '기술':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  void _showCreateRoomDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final maxMembersController = TextEditingController(text: '20');
    String selectedCategory = '시험준비';
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('새 학습룸 만들기'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '학습룸 이름',
                      ),
                    ),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '학습룸 설명',
                        hintText: '이 학습룸의 목적과 활동에 대해 설명해주세요.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: '카테고리',
                      ),
                      items: _categories
                          .where((category) => category != '전체')
                          .map((category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: maxMembersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '최대 참여 인원',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('공개 설정:'),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: isPublic,
                              onChanged: (value) {
                                setState(() {
                                  isPublic = value!;
                                });
                              },
                            ),
                            const Text('공개'),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Radio<bool>(
                              value: false,
                              groupValue: isPublic,
                              onChanged: (value) {
                                setState(() {
                                  isPublic = value!;
                                });
                              },
                            ),
                            const Text('비공개'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    // 학습룸 생성 로직
                    Navigator.pop(context);
                  },
                  child: const Text('생성'),
                ),
              ],
            );
          },
        );
      },
    );
  }
} 