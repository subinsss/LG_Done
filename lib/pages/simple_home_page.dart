import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';
import '../services/firestore_todo_service.dart';
import '../screens/character_settings_page.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/profile_service.dart';
import 'profile_edit_page.dart';
import '../data/character.dart';

class SimpleHomePage extends StatefulWidget {
  const SimpleHomePage({super.key});

  @override
  State<SimpleHomePage> createState() => _SimpleHomePageState();
}

class _SimpleHomePageState extends State<SimpleHomePage> {
  // Firestore 서비스
  final FirestoreTodoService _firestoreService = FirestoreTodoService();
  
  // 할일 목록 (Firestore에서 실시간으로 받아옴)
  List<TodoItem> _todos = [];
  StreamSubscription<List<TodoItem>>? _todosSubscription;
  
  // 드래그 중 상태 관리
  bool _isDragging = false;
  Map<String, List<TodoItem>> _localTodoOrder = {};

  // 카테고리 목록 (Firebase에서 실시간으로 받아옴)
  List<String> _categories = [];
  StreamSubscription<List<String>>? _categoriesSubscription;
  
  // 달력 관련 추가
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now(); // 오늘 날짜로 고정
  bool _isCalendarExpanded = false;
  
  // 날짜별 할일 개수 (캘린더 표시용) - 문자열 키 사용
  Map<String, int> _todoCountsByDate = {};
  
  // 카테고리별 접힘 상태 관리
  Map<String, bool> _categoryCollapsed = {};

  // 할일 추가 컨트롤러
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  String _selectedPriority = 'medium';
  DateTime _selectedDate = DateTime.now();
    String _selectedCategory = '';
  
  // 카테고리별 색상 저장 (Firebase에서 관리)
  Map<String, Color> _categoryColors = {};
  StreamSubscription<Map<String, int>>? _categoryColorsSubscription;

  // 캐릭터 커스터마이징을 위한 상태 추가
  String _selectedCharacter = 'emoji_default'; // 기본 이모지 캐릭터
  bool _isPremiumUser = false; // 사용자 등급 (테스트용으로 false 설정)
  
  // AI 생성 캐릭터 정보
  Map<String, dynamic>? _selectedAICharacter;
  
  // 사용 가능한 캐릭터 목록 (나중에 실제 이미지로 교체될 예정)
  final Map<String, Map<String, dynamic>> _availableCharacters = {
    'emoji_default': {
      'name': '기본 이모지',
      'type': 'emoji',
      'happy': '🎉',
      'working': '💪',
      'starting': '🌱',
      'normal': '😊',
    },
    'emoji_cat': {
      'name': '고양이',
      'type': 'emoji', 
      'happy': '😸',
      'working': '🙀',
      'starting': '😺',
      'normal': '😸',
    },
    'emoji_robot': {
      'name': '로봇',
      'type': 'emoji',
      'happy': '🤖',
      'working': '🤖',
      'starting': '🤖', 
      'normal': '🤖',
    },
    'image_girl': {
      'name': '소녀 캐릭터',
      'type': 'image',
      'path': 'assets/characters/girl.png', // 나중에 추가될 이미지
    },
    'image_boy': {
      'name': '소년 캐릭터', 
      'type': 'image',
      'path': 'assets/characters/boy.png', // 나중에 추가될 이미지
    },
    'image_wizard': {
      'name': '마법사',
      'type': 'image', 
      'path': 'assets/characters/wizard.png', // 나중에 추가될 이미지
    },
  };

  bool _isDataLoading = false;

  StreamSubscription<DocumentSnapshot>? _selectedCharacterSubscription;
  StreamSubscription<Map<String, dynamic>>? _profileSubscription;
  
  // 프로필 정보
  String _userName = '사용자';
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _todoController.dispose();
    _categoryController.dispose();
    _todosSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _categoryColorsSubscription?.cancel();
    _selectedCharacterSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isDataLoading = true;
    });

    try {
      // FirestoreTodoService 초기화 상태 확인 및 재초기화
      if (!_firestoreService.isInitialized) {
        print('⚠️ FirestoreTodoService가 초기화되지 않음. 재초기화 시도...');
        final db = FirebaseFirestore.instance;
        _firestoreService.initialize(db);
        print('🔧 FirestoreTodoService 재초기화 완료');
      }
      
      // Firebase 연결 상태 확인 및 재시도
      print('🔥 Firebase 연결 상태 확인 중...');
      final db = FirebaseFirestore.instance;
      
      int retryCount = 0;
      bool connectionSuccessful = false;
      
      while (!connectionSuccessful && retryCount < 3) {
        try {
          retryCount++;
          print('🔄 Firebase 연결 시도 ${retryCount}/3');
          
          final testQuery = await db.collection('todos').limit(1).get(
            const GetOptions(source: Source.server)
          );
          
          print('✅ Firebase 연결 성공 - 문서 개수: ${testQuery.docs.length}');
          connectionSuccessful = true;
          
        } catch (e) {
          print('❌ Firebase 연결 실패 (${retryCount}/3): $e');
          if (retryCount < 3) {
            print('⏳ 2초 후 재시도...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
      
      if (!connectionSuccessful) {
        print('💥 Firebase 연결 최종 실패 - 오프라인 모드로 진행');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('서버 연결에 실패했습니다. 오프라인 데이터를 사용합니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      // 스트림 연결 시작
      print('📡 실시간 스트림 연결 시작...');
      _listenToTodos();
      _listenToCategories();
      _listenToCategoryColors();
      _listenToSelectedCharacter();
      _listenToProfile();
      
      // 초기 월별 할일 개수 로드
      print('🚀 초기 월별 할일 개수 로드 시작...');
      await _loadTodoCountsForMonth(_focusedDay);
      print('🚀 초기 월별 할일 개수 로드 완료!');
      
      print('✅ 모든 스트림 연결 완료');
      
    } catch (e) {
      print('❌ 데이터 초기화 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 초기화 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isDataLoading = false;
      });
    }
  }

  // 프로필 실시간 감지
  void _listenToProfile() {
    _profileSubscription = ProfileService.getProfileStream().listen(
      (profile) {
        setState(() {
          _userName = profile['name'] ?? '사용자';
          _profileImageUrl = profile['profileImageUrl'] ?? '';
        });
        print('✅ 프로필 실시간 업데이트: ${profile['name']}');
      },
      onError: (error) {
        print('❌ 프로필 스트림 오류: $error');
        setState(() {
          _userName = '사용자';
          _profileImageUrl = '';
        });
      },
    );
  }

  // 프로필 아이콘 생성
  Widget _buildProfileIcon() {
    return GestureDetector(
      onTap: _showUserInfoDialog,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: _profileImageUrl.isNotEmpty 
          ? NetworkImage(_profileImageUrl) 
          : null,
        child: _profileImageUrl.isEmpty 
          ? Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            )
          : null,
      ),
    );
  }

  void _showUserInfoDialog() {
    final user = FirebaseAuth.instance.currentUser;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 배경 패턴
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.1),
                          Colors.purple.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 메인 컨텐츠
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 헤더
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '프로필 정보',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // 프로필 이미지
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade100, Colors.purple.shade100],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : _profileImageUrl.isNotEmpty
                                  ? NetworkImage(_profileImageUrl)
                                  : null,
                              child: (user?.photoURL == null && _profileImageUrl.isEmpty)
                                  ? Text(
                                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // 사용자 이름
                        Text(
                          _userName.isNotEmpty ? _userName : (user?.displayName ?? '사용자'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? '이메일 정보 없음',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // 정보 카드들
                        _buildModernInfoCard(
                          '기본 정보',
                          Icons.info_outline,
                          Colors.blue,
                          [
                            _buildModernInfoRow(Icons.person, '이름', _userName.isNotEmpty ? _userName : (user?.displayName ?? '설정되지 않음')),
                            _buildModernInfoRow(Icons.email, '이메일', user?.email ?? '설정되지 않음'),
                            _buildModernInfoRow(Icons.fingerprint, 'ID', user?.uid.substring(0, 8) ?? '정보 없음'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        _buildModernInfoCard(
                          '계정 정보',
                          Icons.account_circle_outlined,
                          Colors.purple,
                          [
                            _buildModernInfoRow(Icons.star, '계정 유형', _isPremiumUser ? '프리미엄' : '기본'),
                            _buildModernInfoRow(Icons.calendar_today, '가입일', user?.metadata.creationTime != null 
                                ? '${user!.metadata.creationTime!.year}년 ${user.metadata.creationTime!.month}월 ${user.metadata.creationTime!.day}일'
                                : '정보 없음'),
                            _buildModernInfoRow(Icons.access_time, '최근 로그인', user?.metadata.lastSignInTime != null 
                                ? '${user!.metadata.lastSignInTime!.year}년 ${user.metadata.lastSignInTime!.month}월 ${user.metadata.lastSignInTime!.day}일'
                                : '정보 없음'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernInfoCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // 컨텐츠
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: child,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🔥 Firestore에서 선택된 캐릭터 실시간 감지
  void _listenToSelectedCharacter() {
    _selectedCharacterSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc('anonymous_user')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final userData = snapshot.data()!;
        final selectedCharacter = userData['selected_character'];
        
        if (selectedCharacter != null) {
          final newCharacterId = selectedCharacter['character_id'] ?? '';
          final currentCharacterId = _selectedAICharacter?['character_id'] ?? '';
          
          // 캐릭터가 실제로 변경된 경우에만 업데이트
          if (newCharacterId != currentCharacterId) {
            setState(() {
              _selectedAICharacter = {
                'character_id': selectedCharacter['character_id'] ?? '',
                'name': selectedCharacter['name'] ?? '이름 없음',
                'image_url': selectedCharacter['image_url'] ?? '',
                'prompt': selectedCharacter['prompt'] ?? '',
                'selected_at': selectedCharacter['selected_at'] ?? '',
              };
            });
            // 캐릭터 변경됨 (로그 제거)
          }
        } else {
          // 선택된 캐릭터가 null인 경우에만 업데이트
          if (_selectedAICharacter != null) {
            setState(() {
              _selectedAICharacter = null;
            });
            // 선택된 캐릭터 제거됨 (로그 제거)
          }
        }
      } else {
        // 문서가 없는 경우에만 업데이트
        if (_selectedAICharacter != null) {
          setState(() {
            _selectedAICharacter = null;
          });
          // 사용자 문서 없음 (로그 제거)
        }
      }
    }, onError: (error) {
      print('❌ 선택된 캐릭터 스트림 오류: $error');
    });
  }

  // 🔥 Firestore에서 카테고리 색상 실시간 감지
  void _listenToCategoryColors() {
    _categoryColorsSubscription = _firestoreService.getCategoryColorsStream().listen(
      (categoryColors) {
        setState(() {
          _categoryColors = categoryColors.map(
            (key, value) => MapEntry(key, Color(value)),
          );
        });
        print('✅ 카테고리 색상 실시간 업데이트: $categoryColors');
      },
      onError: (error) {
        print('❌ 카테고리 색상 스트림 오류: $error');
        setState(() {
          _categoryColors = {};
        });
      },
    );
  }

  // 카테고리 색상 설정 (Firestore에 저장)
  Future<void> _setCategoryColor(String category, Color color) async {
    setState(() {
      _categoryColors[category] = color;
    });
    
    // Firestore에 색상 저장
    final success = await _firestoreService.updateCategoryColor(category, color.value);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리 색상 저장에 실패했습니다')),
      );
    }
  }

  // 색상 선택기 표시
  void _showColorPicker(String category, StateSetter setDialogState) {
    final colorGroups = {
      '빨강': [Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFE53935), Color(0xFFEF5350), Color(0xFFFF5252), Color(0xFFFF6B6B)],
      '분홍': [Color(0xFF880E4F), Color(0xFFAD1457), Color(0xFFE91E63), Color(0xFFEC407A), Color(0xFFF06292), Color(0xFFF48FB1)],
      '보라': [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0), Color(0xFFBA68C8), Color(0xFFCE93D8), Color(0xFFE1BEE7)],
      '인디고': [Color(0xFF1A237E), Color(0xFF303F9F), Color(0xFF3F51B5), Color(0xFF5C6BC0), Color(0xFF7986CB), Color(0xFF9FA8DA)],
      '파랑': [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF2196F3), Color(0xFF42A5F5), Color(0xFF64B5F6), Color(0xFF90CAF9)],
      '하늘': [Color(0xFF006064), Color(0xFF0097A7), Color(0xFF00BCD4), Color(0xFF26C6DA), Color(0xFF4DD0E1), Color(0xFF80DEEA)],
      '청록': [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF009688), Color(0xFF26A69A), Color(0xFF4DB6AC), Color(0xFF80CBC4)],
      '초록': [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF4CAF50), Color(0xFF66BB6A), Color(0xFF81C784), Color(0xFFA5D6A7)],
      '연두': [Color(0xFF33691E), Color(0xFF689F38), Color(0xFF8BC34A), Color(0xFF9CCC65), Color(0xFFAED581), Color(0xFFC5E1A5)],
      '노랑': [Color(0xFFF57F17), Color(0xFFF9A825), Color(0xFFFFC107), Color(0xFFFFD54F), Color(0xFFFFE082), Color(0xFFFFECB3)],
      '주황': [Color(0xFFE65100), Color(0xFFFF8F00), Color(0xFFFF9800), Color(0xFFFFA726), Color(0xFFFFB74D), Color(0xFFFFCC02)],
      '갈색': [Color(0xFF3E2723), Color(0xFF5D4037), Color(0xFF795548), Color(0xFF8D6E63), Color(0xFFA1887F), Color(0xFFBCAAA4)],
      '회색': [Color(0xFF212121), Color(0xFF424242), Color(0xFF616161), Color(0xFF757575), Color(0xFF9E9E9E), Color(0xFFBDBDBD)],
    };

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getCategoryColor(category),
                          _getCategoryColor(category).withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '색상 선택',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 색상 팔레트들 (색상별 분류)
              Container(
                height: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: colorGroups.entries.map((entry) {
                      final groupName = entry.key;
                      final colors = entry.value;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: colors.map((color) {
                                final isSelected = _getCategoryColor(category) == color;
                                
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: GestureDetector(
                                                                              onTap: () async {
                                        await _setCategoryColor(category, color);
                                        setDialogState(() {}); // 부모 다이얼로그 업데이트
                                        
                                        // 성공 피드백
                                        HapticFeedback.mediumImpact();
                                        
                                        // 약간의 지연 후 닫기
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          Navigator.of(context).pop();
                                        });
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? Colors.white : Colors.grey.shade300,
                                            width: isSelected ? 3 : 1,
                                          ),

                                        ),
                                        child: isSelected
                                            ? Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.3),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 완료 버튼
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade100,
                      Colors.grey.shade50,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),

                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '완료',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 카테고리 목록 실시간 구독
  void _listenToCategories() {
    _categoriesSubscription = _firestoreService.getCategoriesStream().listen(
      (categories) {
        setState(() {
          _categories = categories;
          // 선택된 카테고리가 목록에 없으면 첫 번째 카테고리로 설정 (있는 경우에만)
          if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }
        });
        print('✅ 카테고리 목록 업데이트: $_categories');
      },
      onError: (error) {
        print('❌ 카테고리 목록 구독 오류: $error');
        
        // 에러 발생 시 빈 목록 사용
        setState(() {
          _categories = [];
          _selectedCategory = '';
        });
        
        // 사용자에게 알림
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카테고리를 불러오는데 실패했습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }

  // Firestore에서 할일 목록 실시간 구독 (선택된 날짜 기준)
  void _listenToTodos() {
    print('🔄 Firebase 연결 중...');
    print('🔍 FirestoreTodoService 초기화 상태 확인: ${_firestoreService.toString()}');
    
    // FirestoreTodoService가 초기화되지 않은 경우 재초기화
    if (!_firestoreService.isInitialized) {
      print('! FirestoreTodoService가 초기화되지 않음. 재초기화 시도...');
      final firestore = FirebaseFirestore.instance;
      _firestoreService.initialize(firestore);
      print('🔧 FirestoreTodoService 재초기화 완료');
    }
    
    _todosSubscription?.cancel();
    
    try {
      // 선택된 날짜에 맞는 할일 스트림 구독
      _todosSubscription = _firestoreService.getTodosStreamByDate(_selectedDay).listen(
        (todos) {
          print('✅ 데이터 수신: ${todos.length}개 할일 (${DateFormat('yyyy-MM-dd').format(_selectedDay)})');
          
          if (mounted) {
            setState(() {
              _todos = todos;
              // 선택된 날짜의 할일 개수를 캐시에도 반영
              final selectedDateString = DateFormat('yyyy-MM-dd').format(_selectedDay);
              _todoCountsByDate[selectedDateString] = todos.length;
            });
          }
        },
        onError: (error) {
          print('❌ 연결 오류: $error');
          
          // 오프라인 모드에서 기본 할일 표시
          if (mounted) {
            setState(() {
              _todos = _getDefaultTodos();
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('오프라인 모드로 동작합니다'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      );
    } catch (e) {
      print('❌ 스트림 생성 오류: $e');
      
      // 예외 발생 시 기본 할일 표시
      if (mounted) {
        setState(() {
          _todos = _getDefaultTodos();
        });
      }
    }
  }

  // 날짜 변경 시 새로운 스트림 구독
  void _updateTodosForSelectedDate() {
    print('📅 날짜 변경: ${DateFormat('yyyy-MM-dd').format(_selectedDay)}');
    _listenToTodos(); // 새로운 날짜로 스트림 재구독
    // 캘린더 할일 개수도 업데이트
    _loadTodoCountsForMonth(_selectedDay);
  }

  // 실시간 캘린더 업데이트를 위한 헬퍼 함수
  void _updateTodoCountForDate(String dateString, int change) {
    setState(() {
      final currentCount = _todoCountsByDate[dateString] ?? 0;
      final newCount = currentCount + change;
      
      if (newCount <= 0) {
        _todoCountsByDate.remove(dateString);
      } else {
        _todoCountsByDate[dateString] = newCount;
      }
    });
  }

  // 월별 할일 개수 로드
  Future<void> _loadTodoCountsForMonth(DateTime month) async {
    try {
      final counts = await _firestoreService.getTodoCountsByMonth(month);
      
      setState(() {
        _todoCountsByDate = counts;
      });
      
    } catch (e) {
      print('❌ 월별 할일 개수 로드 실패: $e');
      setState(() {
        _todoCountsByDate = {};
      });
    }
  }

  // 할일 토글 (Firestore 업데이트)
  Future<void> _toggleTodo(TodoItem todo) async {
    final success = await _firestoreService.toggleTodoCompletion(
      todo.id, 
      !todo.isCompleted
    );
    
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 상태 변경에 실패했습니다')),
      );
    }
  }

  // 할일 삭제 (Firestore에서 삭제)
  Future<void> _deleteTodo(TodoItem todo) async {
    print('🗑️ 삭제 요청: ${todo.title} (ID: ${todo.id})');
    
    final success = await _firestoreService.deleteTodo(todo.id);
    
    if (success) {
      print('✅ Firestore 삭제 성공: ${todo.id}');
      
      // 실시간 캘린더 개수 업데이트 (삭제된 날짜에서 -1)
      final todoDateString = DateFormat('yyyy-MM-dd').format(todo.dueDate ?? _selectedDay);
      _updateTodoCountForDate(todoDateString, -1);
      
    } else {
      print('❌ Firestore 삭제 실패: ${todo.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 삭제에 실패했습니다')),
      );
    }
  }

  // 할일 액션 처리 (수정, 삭제, 내일하기, 내일 또하기)
  Future<void> _handleTodoAction(TodoItem todo, String action) async {
    switch (action) {
      case 'edit':
        _showEditTodoDialog(todo);
        break;
      case 'delete':
        // 간단한 삭제 확인 다이얼로그
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.all(20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '할일을 삭제하시겠습니까?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '삭제하기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        if (confirmed == true) {
          await _deleteTodo(todo);
        }
        break;
      case 'move_tomorrow':
        // 내일하기 (현재 할일 날짜 기준으로 하루 증가)
        final success = await _firestoreService.moveTodoToTomorrow(todo.id);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${todo.title}을(를) 다음 날로 이동했습니다')),
          );
          
          // 실시간 캘린더 개수 업데이트 (기존 날짜 -1, 이동된 날짜 +1)
          if (todo.dueDate != null) {
            final currentDateString = DateFormat('yyyy-MM-dd').format(todo.dueDate!);
            final nextDay = todo.dueDate!.add(Duration(days: 1));
            final nextDayString = DateFormat('yyyy-MM-dd').format(nextDay);
            
            _updateTodoCountForDate(currentDateString, -1);
            _updateTodoCountForDate(nextDayString, 1);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('내일하기에 실패했습니다')),
          );
        }
        break;
      case 'copy_tomorrow':
        // 내일 또하기 (현재 할일 날짜 기준으로 하루 증가해서 복사)
        final success = await _firestoreService.copyTodoToTomorrow(todo.id);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${todo.title}을(를) 다음 날로 복사했습니다')),
          );
          
          // 실시간 캘린더 개수 업데이트 (복사된 날짜에 +1)
          if (todo.dueDate != null) {
            final nextDay = todo.dueDate!.add(Duration(days: 1));
            final nextDayString = DateFormat('yyyy-MM-dd').format(nextDay);
            _updateTodoCountForDate(nextDayString, 1);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('내일 또하기에 실패했습니다')),
          );
        }
        break;
    }
  }

  // 오프라인 모드용 기본 할일 목록
  List<TodoItem> _getDefaultTodos() {
    final today = DateTime.now();
    return [
      TodoItem(
        id: 'default_1',
        title: '🌅 오늘의 계획 세우기',
        priority: '높음',
        dueDate: today,
        category: '기본',
        isCompleted: false,
        userId: 'anonymous',
        order: 0,
      ),
      TodoItem(
        id: 'default_2',
        title: '📚 새로운 기술 학습하기',
        priority: '보통',
        dueDate: today,
        category: '공부',
        isCompleted: false,
        userId: 'anonymous',
        order: 1,
      ),
      TodoItem(
        id: 'default_3', 
        title: '💪 운동 30분하기',
        priority: '보통',
        dueDate: today,
        category: '건강',
        isCompleted: false,
        userId: 'anonymous',
        order: 2,
      ),
    ];
  }

  // 할일 추가 (Firestore에 추가)
  Future<void> _addTodo() async {
    if (_todoController.text.trim().isEmpty) return;
    if (_selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요')),
      );
      return;
    }
    
    final todoId = await _firestoreService.addTodo(
      title: _todoController.text.trim(),
      priority: _selectedPriority,
      dueDate: _selectedDay, // 캘린더에서 선택한 날짜 사용
      category: _selectedCategory,
    );
    
    if (todoId != null) {
      _todoController.clear();
      _categoryController.clear();
      Navigator.of(context).pop();
      
      // 실시간 캘린더 개수 업데이트 (추가된 날짜에 +1)
      final addedDateString = DateFormat('yyyy-MM-dd').format(_selectedDay);
      _updateTodoCountForDate(addedDateString, 1);
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 추가에 실패했습니다')),
      );
    }
  }

  // 할일 수정 (Firestore에서 수정)
  Future<void> _updateTodo({
    required TodoItem todo,
    required String newTitle,
    required String newPriority,
    required DateTime newDueDate,
    required String newCategory,
  }) async {
    final success = await _firestoreService.updateTodo(
      todoId: todo.id,
      title: newTitle,
      priority: newPriority,
      dueDate: newDueDate,
      category: newCategory,
    );
    
    if (success) {
      // 날짜가 변경된 경우만 실시간 캘린더 개수 업데이트
      final oldDateString = DateFormat('yyyy-MM-dd').format(todo.dueDate ?? _selectedDay);
      final newDateString = DateFormat('yyyy-MM-dd').format(newDueDate);
      
      if (oldDateString != newDateString) {
        // 기존 날짜에서 -1, 새 날짜에서 +1
        _updateTodoCountForDate(oldDateString, -1);
        _updateTodoCountForDate(newDateString, 1);
      }
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 수정에 실패했습니다')),
      );
    }
  }

  Widget _buildCharacterImage() {
    // 선택한 날짜의 할일만 필터링
    final selectedDateTodos = _todos.where((todo) {
      if (todo.dueDate == null) return false;
      return isSameDay(todo.dueDate!, _selectedDay);
    }).toList();

    int completedCount = selectedDateTodos.where((todo) => todo.isCompleted).length;
    double completionRate = selectedDateTodos.isEmpty ? 0 : completedCount / selectedDateTodos.length;
    
    // 🔥 선택된 AI 캐릭터가 있으면 그것을 표시
    if (_selectedAICharacter != null && _selectedAICharacter!['image_url'] != null) {
      String imageUrl = _selectedAICharacter!['image_url'];
      
      try {
        // Base64 이미지인지 확인
        if (imageUrl.startsWith('data:image/')) {
          // Base64 이미지 처리
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.memory(
                base64Decode(imageUrl.split(',')[1]),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Base64 이미지 로딩 오류: $error');
                  return _buildDefaultCharacter();
                },
              ),
            ),
          );
        } else {
          // 일반 네트워크 이미지
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  print('AI 캐릭터 네트워크 이미지 로딩 오류: $error');
                  return _buildDefaultCharacter();
                },
              ),
            ),
          );
        }
      } catch (e) {
        print('AI 캐릭터 이미지 처리 오류: $e');
        return _buildDefaultCharacter();
      }
    } 
    
    // 기본 이모지 캐릭터 표시
    return _buildDefaultCharacter();
  }
  
  Widget _buildCharacterWidget() {
    // AI 캐릭터가 선택되어 있는 경우
    if (_selectedAICharacter != null) {
      final imageUrl = _selectedAICharacter!['image_url'];
      
      try {
        // Base64 이미지인지 확인
        if (imageUrl.startsWith('data:image/')) {
          final base64String = imageUrl.split(',')[1];
          final Uint8List bytes = base64Decode(base64String);
          
          return Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(75),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(75),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('AI 캐릭터 이미지 로딩 오류: $error');
                  return _buildDefaultCharacter();
                },
              ),
            ),
          );
        } else {
          // 일반 네트워크 이미지
          return Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(75),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  print('AI 캐릭터 네트워크 이미지 로딩 오류: $error');
                  return _buildDefaultCharacter();
                },
              ),
            ),
          );
        }
      } catch (e) {
        print('AI 캐릭터 이미지 처리 오류: $e');
        return _buildDefaultCharacter();
      }
    } 
    
    // 기본 이모지 캐릭터 표시
    return _buildDefaultCharacter();
  }
  
  Widget _buildDefaultCharacter() {
    // 기본 캐릭터 이미지 표시 (Character 클래스의 getDefaultCharacter 사용)
    final defaultCharacter = Character.getDefaultCharacter();
    
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Image.network(
          defaultCharacter.networkImageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('기본 캐릭터 이미지 로딩 오류: $error');
            // 이미지 로딩 실패 시 이모지 대신 예쁜 기본 아바타 표시
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade300,
                    Colors.blue.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.person,
                size: 100,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    // 선택한 날짜의 할일만 필터링
    final selectedDateTodos = _todos.where((todo) {
      if (todo.dueDate == null) return false;
      return isSameDay(todo.dueDate!, _selectedDay);
    }).toList();

    int totalTodos = selectedDateTodos.length;
    int completedTodos = selectedDateTodos.where((todo) => todo.isCompleted).length;
    int pendingTodos = totalTodos - completedTodos;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                              Text(
                DateFormat('yyyy년 M월 d일 (E)').format(_selectedDay),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isCalendarExpanded = !_isCalendarExpanded;
                  });
                },
                icon: Icon(
                  _isCalendarExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade600,
                ),
                tooltip: _isCalendarExpanded ? '달력 접기' : '달력 펼치기',
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('전체', totalTodos, Colors.black),
              _buildStatItem('완료', completedTodos, Colors.black),
              _buildStatItem('대기', pendingTodos, Colors.grey.shade600),
            ],
          ),
          
          // 접었다 폈다 할 수 있는 달력
          if (_isCalendarExpanded) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 10),
            TableCalendar<TodoItem>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              eventLoader: (day) {
                final dayString = DateFormat('yyyy-MM-dd').format(day);
                
                // 현재 선택된 날짜면 _todos 데이터 사용 (항상 우선)
                if (isSameDay(day, _selectedDay)) {
                  final todosForDay = _todos.length;
                  return List.generate(todosForDay, (index) => TodoItem(
                    id: 'selected_day_$index',
                    title: 'dummy',
                    isCompleted: false,
                    category: '',
                    priority: 'medium',
                    dueDate: day,
                    userId: 'dummy',
                  ));
                }
                
                // 다른 날짜는 _todoCountsByDate에서 확인
                int count = _todoCountsByDate[dayString] ?? 0;
                
                return List.generate(count, (index) => TodoItem(
                  id: 'cached_${dayString}_$index',
                  title: 'dummy',
                  isCompleted: false,
                  category: '',
                  priority: 'medium',
                  dueDate: day,
                  userId: 'dummy',
                ));
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1, // 할일 개수 표시 활성화
                canMarkersOverflow: false,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isNotEmpty) {
                    final count = events.length;
                    
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey.shade600),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey.shade600),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedDate = selectedDay; // 할일 추가시 사용할 날짜도 업데이트
                });
                // 선택된 날짜의 할일을 새로 불러오기
                _updateTodosForSelectedDate();
              },
              onPageChanged: (focusedDay) async {
                setState(() {
                  _focusedDay = focusedDay;
                });
                // 새로운 월의 할일 개수 로드
                await _loadTodoCountsForMonth(focusedDay);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoList() {
    // Firebase에서 이미 오늘 날짜로 필터링된 할일들
    final todayTodos = _todos;
    
    // 카테고리가 없으면 안내 메시지 표시
    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              '카테고리가 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '할일을 관리하기 위해\n카테고리를 먼저 추가해주세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _addNewCategory,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('첫 번째 카테고리 추가하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 카테고리별로 오늘 할일을 그룹화하여 표시
    return Column(
      children: _categories.map((category) {
        final categoryTodos = todayTodos
            .where((todo) => todo.category == category)
            .toList();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade100,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: _getCategoryColor(category).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리 헤더 (접기/펼치기 기능 포함)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _categoryCollapsed[category] = !(_categoryCollapsed[category] ?? false);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getCategoryColor(category).withOpacity(0.15),
                        _getCategoryColor(category).withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular((_categoryCollapsed[category] ?? false) ? 20 : 0),
                      bottomRight: Radius.circular((_categoryCollapsed[category] ?? false) ? 20 : 0),
                    ),
                    border: Border(
                      bottom: (_categoryCollapsed[category] ?? false) 
                        ? BorderSide.none 
                        : BorderSide(
                            color: _getCategoryColor(category).withOpacity(0.1),
                            width: 1,
                          ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // 접기/펼치기 아이콘
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getCategoryColor(category).withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                (_categoryCollapsed[category] ?? false) 
                                    ? Icons.keyboard_arrow_right 
                                    : Icons.keyboard_arrow_down,
                                color: _getCategoryColor(category),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getCategoryColor(category),
                                    _getCategoryColor(category).withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _getCategoryColor(category).withOpacity(0.3),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getCategoryColor(category),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getCategoryColor(category).withOpacity(0.25),
                                    _getCategoryColor(category).withOpacity(0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getCategoryColor(category).withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '${categoryTodos.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getCategoryColor(category),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!(_categoryCollapsed[category] ?? false))
                        IconButton(
                          onPressed: () => _showAddTodoDialogForCategory(category),
                          icon: Icon(
                            Icons.add,
                            color: _getCategoryColor(category),
                            size: 20,
                          ),
                          tooltip: '$category에 할일 추가',
                        ),
                    ],
                  ),
                ),
              ),
              
              // 카테고리별 할일 목록 (접힌 상태가 아닐 때만 표시)
              if (!(_categoryCollapsed[category] ?? false)) ...[
                if (categoryTodos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        '오늘 이 카테고리의 할일이 없습니다',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  _buildReorderableTodoList(category, categoryTodos),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // 드래그 앤 드롭 가능한 할일 목록
  Widget _buildReorderableTodoList(String category, List<TodoItem> categoryTodos) {
    // 순서별로 정렬
    categoryTodos.sort((a, b) => a.order.compareTo(b.order));
    
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.transparent,
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categoryTodos.length,
        buildDefaultDragHandles: false, // 기본 드래그 핸들 비활성화
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double animValue = Curves.easeOutCubic.transform(animation.value);
              final double elevation = lerpDouble(0, 8, animValue)!;
              final double scale = lerpDouble(1, 1.05, animValue)!;
              return Transform.scale(
                scale: scale,
                child: Material(
                  elevation: elevation,
                  color: Colors.white,
                  shadowColor: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        onReorder: (oldIndex, newIndex) => _onReorderTodos(category, oldIndex, newIndex),
        itemBuilder: (context, index) {
          final todo = categoryTodos[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey('${todo.id}_${todo.order}_drag'),
            index: index,
            child: _buildTodoItem(todo, index),
          );
        },
      ),
    );
  }

  // 드래그 상태 추적
  bool _isReordering = false;
  
  // 할일 순서 변경 처리 (부드러운 애니메이션)
  void _onReorderTodos(String category, int oldIndex, int newIndex) async {
    // ReorderableListView는 newIndex가 oldIndex보다 크면 1을 빼줘야 함
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    if (oldIndex == newIndex) return;
    
    print('🔄 할일 순서 변경 시도: $category 카테고리에서 $oldIndex → $newIndex');
    
    // 1. 드래그 상태 시작 - Firebase 스트림 업데이트 무시
    setState(() {
      _isReordering = true;
    });
    
    // 2. Firebase 백그라운드 업데이트 (실패 시 롤백)
    try {
      final success = await _firestoreService.reorderTodos(
        category, 
        _selectedDay, 
        oldIndex, 
        newIndex
      );
      
      if (!success) {
        throw Exception('Firebase 업데이트 실패');
      }
      
      print('✅ 할일 순서 변경 완료');
    } catch (e) {
      print('❌ 할일 순서 변경 실패: $e');
      
      // 실패 시 원래 상태로 롤백하지 않음 - Firebase 스트림이 자동으로 복원
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('할일 순서 변경에 실패했습니다'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // 3. 드래그 상태 종료 - Firebase 스트림 다시 활성화
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _isReordering = false;
        });
      }
    }
  }

  Widget _buildTodoItem(TodoItem todo, int index) {
    return Container(
      key: ValueKey('${todo.id}_${todo.order}'), // 더 안정적인 key
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 상단 정렬로 변경
        children: [
          GestureDetector(
            onTap: () => _toggleTodo(todo),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: todo.isCompleted ? Colors.green : Colors.grey.shade300,
                  width: 2,
                ),
                color: todo.isCompleted ? Colors.green : Colors.transparent,
              ),
              child: todo.isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                    color: todo.isCompleted ? Colors.grey.shade500 : Colors.black87,
                  ),
                  maxLines: null, // 무제한 줄 수
                  softWrap: true, // 자동 줄바꿈
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(todo.priority).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getPriorityText(todo.priority),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getPriorityColor(todo.priority),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // 완료된 할일에 시간 정보 표시
                    if (todo.isCompleted && _hasTimeData(todo)) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 10,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _calculateWorkingTime(todo),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                // 완료된 할일에 상세 시간 타임라인 표시 (할일 카드 내부)
                if (todo.isCompleted && _hasTimeData(todo)) ...[
                  const SizedBox(height: 8),
                  _buildTimeVisualization(todo),
                ],
              ],
            ),
          ),
          // 더보기 메뉴 버튼 (수정, 삭제, 내일하기, 내일 또하기)
          PopupMenuButton<String>(
            onSelected: (value) => _handleTodoAction(todo, value),
            offset: const Offset(-10, 45),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            itemBuilder: (context) {
              // 디버깅: 할일 완료 상태 확인
              print('🔍 할일 "${todo.title}" 완료 상태: ${todo.isCompleted}');
              
              // 기본 메뉴 아이템들 (수정, 삭제)
              List<PopupMenuEntry<String>> items = [
                                  PopupMenuItem(
                    value: 'edit',
                    height: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.edit_outlined, color: Colors.blue.shade700, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '수정',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                                  PopupMenuItem(
                    value: 'delete',
                    height: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '삭제',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ];

              // 완료되지 않은 할일에만 "내일하기"와 "내일 또하기" 옵션 추가
              if (!todo.isCompleted) {
                items.addAll([
                                      PopupMenuItem(
                      value: 'move_tomorrow',
                      height: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.arrow_forward, color: Colors.orange.shade700, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '내일하기',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                                      PopupMenuItem(
                      value: 'copy_tomorrow',
                      height: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.copy, color: Colors.green.shade700, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '내일 또하기',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ]);
              }

              return items;
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.more_horiz,
                color: Colors.grey.shade700,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 실제 드래그 핸들 (맨 오른쪽)
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(
                Icons.drag_handle,
                color: Colors.grey.shade500,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // 사용자가 설정한 색상이 있으면 그것을 사용
    if (_categoryColors.containsKey(category)) {
      return _categoryColors[category]!;
    }

    // 기본 색상 (블루그레이) - Firestore의 기본값과 일치
    return Colors.blueGrey.shade600;
  }







  void _showAddTodoDialogForCategory(String category) {
    _selectedCategory = category;
    
    // 다이얼로그 열 때마다 초기화
    _selectedDate = _selectedDay;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_task,
                  color: _getCategoryColor(category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$category 할일 추가',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 할일 제목 입력
                Text(
                  '할일 제목',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _todoController,
                  decoration: InputDecoration(
                    hintText: '할일을 입력하세요',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                
                // 우선순위 선택
                Text(
                  '우선순위',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    dropdownColor: Colors.white,
                    items: [
                      DropdownMenuItem(
                        value: 'high',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('높음'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('보통'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'low',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('낮음'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedPriority = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // 선택된 날짜 표시
                Text(
                  '목표 날짜',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('yyyy년 M월 d일 (E)').format(_selectedDay),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _todoController.clear();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                '취소',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: _addTodo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                '추가',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return '높음';
      case 'medium':
        return '보통';
      case 'low':
        return '낮음';
      default:
        return '보통';
    }
  }

  // Firebase와 연동된 카테고리 추가
  void _addNewCategory() {
    _showCategoryManagementDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
            appBar: AppBar(
        toolbarHeight: 60,  // 앱바 높이 줄임
        title: Center(
          child: Image.asset(
            'assets/icon/life guide logo.png',
            fit: BoxFit.contain,
            height: 215,  // 로고 크기를 더 크게!
            errorBuilder: (context, error, stackTrace) {
              print('제목 이미지 로드 오류: $error');
              return Text(
                '할일 관리',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              );
            },
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // 스크롤 시 색상 변화 방지
        scrolledUnderElevation: 0, // 스크롤 시 elevation 효과 제거
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildProfileIcon(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
              body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 헤더 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // 캐릭터 이미지
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // 캐릭터 이미지 (터치 가능)
                        GestureDetector(
                          onTap: _showCharacterSettings,
                          child: _buildCharacterImage(),
                        ),
                        
                        // 설정 버튼 (우상단)
                        Positioned(
                          top: 0,
                          right: 20,
                          child: GestureDetector(
                            onTap: _showCharacterSettings,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.settings,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // 빠른 통계
                    _buildQuickStats(),
                  ],
                ),
              ),
              
              // 메인 컨텐츠 섹션
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            
                                // 관리 버튼과 할일 개수
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${DateFormat('M월 d일').format(_selectedDay)} 할일: ${_todos.length}개',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showCategoryManagementDialog,
                          icon: const Icon(Icons.category, size: 16),
                          label: const Text('관리'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // 할일 목록
                    _buildTodoList(),
                    

                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  void _showCategoryManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.category, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                '카테고리 관리',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // 카테고리 추가 섹션
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '새 카테고리 추가',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                hintText: '카테고리 이름',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.black, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onSubmitted: (_) => _addCategoryFromDialog(setDialogState),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _addCategoryFromDialog(setDialogState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('추가'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // 카테고리 목록 섹션
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현재 카테고리 (${_categories.length}개)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _categories.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 48,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '카테고리가 없습니다',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      leading: GestureDetector(
                                        onTap: () => _showColorPicker(category, setDialogState),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(category),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),

                                          ),
                                          child: Icon(
                                            Icons.palette,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        category,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              color: Colors.grey.shade600,
                                              size: 20,
                                            ),
                                            onPressed: () => _showEditCategoryDialog(category, setDialogState),
                                            tooltip: '이름 변경',
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.grey.shade600,
                                              size: 20,
                                            ),
                                            onPressed: () => _deleteCategoryFromDialog(category, setDialogState),
                                            tooltip: '삭제',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCategoryFromDialog(StateSetter setDialogState) async {
    if (_categoryController.text.trim().isNotEmpty) {
      final newCategory = _categoryController.text.trim();
      if (!_categories.contains(newCategory)) {
        // categories 컬렉션에 기본 색상과 함께 추가
        final categoryId = await _firestoreService.addCategory(
          newCategory, 
          colorValue: Colors.blueGrey.shade600.value, // 기본 색상
        );
        
        if (categoryId != null) {
          _categoryController.clear();
          
          // 다이얼로그 내 UI 즉시 업데이트
          setDialogState(() {
            if (!_categories.contains(newCategory)) {
              _categories.add(newCategory);
              _categories.sort(); // 정렬 유지
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('카테고리 "$newCategory"이 추가되었습니다')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카테고리 추가에 실패했습니다')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 존재하는 카테고리입니다')),
        );
      }
    }
  }

  void _showEditCategoryDialog(String oldCategory, StateSetter setDialogState) {
    final TextEditingController editController = TextEditingController(text: oldCategory);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '카테고리 이름 변경',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '새로운 카테고리 이름을 입력해주세요.',
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: editController,
              decoration: InputDecoration(
                labelText: '카테고리 이름',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
              autofocus: true,
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              editController.dispose();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCategoryName = editController.text.trim();
              
              if (newCategoryName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('카테고리 이름을 입력해주세요')),
                );
                return;
              }
              
              if (newCategoryName == oldCategory) {
                editController.dispose();
                Navigator.of(context).pop();
                return;
              }
              
              if (_categories.contains(newCategoryName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이미 존재하는 카테고리 이름입니다')),
                );
                return;
              }
              
              Navigator.of(context).pop(); // 다이얼로그 닫기
              
              try {
                final success = await _firestoreService.updateCategoryName(oldCategory, newCategoryName);
                if (success) {
                  // 다이얼로그 내 UI 즉시 업데이트
                  setDialogState(() {
                    final index = _categories.indexOf(oldCategory);
                    if (index != -1) {
                      _categories[index] = newCategoryName;
                      _categories.sort(); // 정렬 유지
                    }
                    // 선택된 카테고리도 업데이트
                    if (_selectedCategory == oldCategory) {
                      _selectedCategory = newCategoryName;
                    }
                    // 색상 정보도 업데이트
                    if (_categoryColors.containsKey(oldCategory)) {
                      final color = _categoryColors[oldCategory]!;
                      _categoryColors.remove(oldCategory);
                      _categoryColors[newCategoryName] = color;
                    }
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('카테고리 이름이 "$newCategoryName"으로 변경되었습니다'),
                      backgroundColor: Colors.black,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('카테고리 이름 변경에 실패했습니다'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('카테고리 이름 변경에 실패했습니다'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } finally {
                editController.dispose();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  void _deleteCategoryFromDialog(String category, StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Colors.red.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '카테고리 삭제',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              children: [
                TextSpan(text: '카테고리 "'),
                TextSpan(
                  text: category,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                TextSpan(text: '"를 삭제하시겠습니까?\n\n'),
                TextSpan(
                  text: '⚠️ 이 카테고리의 모든 할일도 함께 삭제됩니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: '\n이 작업은 되돌릴 수 없습니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.grey.shade50,
                      foregroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop(); // 확인 다이얼로그 닫기
                      
                      try {
                        final success = await _firestoreService.deleteCategory(category);
                        if (success) {
                          // 다이얼로그 내 UI 즉시 업데이트
                          setDialogState(() {
                            _categories.remove(category);
                            // 선택된 카테고리가 삭제된 경우 초기화
                            if (_selectedCategory == category) {
                              _selectedCategory = _categories.isNotEmpty ? _categories.first : '';
                            }
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('카테고리 "$category"가 삭제되었습니다'),
                              backgroundColor: Colors.black,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('카테고리 삭제에 실패했습니다'),
                              backgroundColor: Colors.grey.shade600,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('카테고리 삭제에 실패했습니다'),
                            backgroundColor: Colors.grey.shade600,
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '삭제',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditTodoDialog(TodoItem todo) {
    // 초기값 설정
    _todoController.text = todo.title;
    _selectedPriority = todo.priority;
    _selectedCategory = todo.category;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getCategoryColor(todo.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit,
                  color: _getCategoryColor(todo.category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '할일 수정',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 할일 제목 입력
                Text(
                  '할일 제목',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _todoController,
                  decoration: InputDecoration(
                    hintText: '할일을 입력하세요',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                
                // 우선순위 선택
                Text(
                  '우선순위',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    dropdownColor: Colors.white,
                    items: [
                      DropdownMenuItem(
                        value: 'high',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('높음'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('보통'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'low',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('낮음'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedPriority = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // 카테고리 선택
                Text(
                  '카테고리',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    dropdownColor: Colors.white,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(category),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // 목표 날짜 표시 (수정 불가)
                Text(
                  '목표 날짜',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('yyyy년 M월 d일 (E)').format(todo.dueDate ?? DateTime.now()),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _todoController.clear();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                '취소',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_todoController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('할일을 입력해주세요')),
                  );
                  return;
                }
                
                await _updateTodo(
                  todo: todo,
                  newTitle: _todoController.text.trim(),
                  newPriority: _selectedPriority,
                  newDueDate: todo.dueDate ?? DateTime.now(),
                  newCategory: _selectedCategory,
                );
                
                _todoController.clear();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                '저장',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 캐릭터 설정 페이지로 이동
  void _showCharacterSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CharacterSettingsPage(),
      ),
    );
    
    // 캐릭터가 선택되어 돌아온 경우 새로고침
    if (result == true) {
      // 캐릭터 변경됨 (로그 제거)
      // 실시간 스트림이 자동으로 업데이트하므로 별도 로딩 불필요
    }
  }

  // 시간 데이터가 있는지 확인
  bool _hasTimeData(TodoItem todo) {
    return todo.startTime != null || 
           todo.stopTime != null ||
           (todo.pauseTimes != null && todo.pauseTimes!.isNotEmpty) ||
           (todo.resumeTimes != null && todo.resumeTimes!.isNotEmpty);
  }

  // 총 작업 시간 계산
  String _calculateWorkingTime(TodoItem todo) {
    try {
      if (!_hasTimeData(todo)) return '0분';

      DateTime? startTime;
      DateTime? endTime;
      
      if (todo.startTime != null) {
        startTime = _parseTime(todo.startTime!);
      }

      // 종료 시간 결정
      bool hasValidPauseData = todo.pauseTimes != null && 
                               todo.pauseTimes!.isNotEmpty &&
                               todo.pauseTimes!.any((time) => time.trim().isNotEmpty);
      bool hasValidResumeData = todo.resumeTimes != null && 
                                todo.resumeTimes!.isNotEmpty &&
                                todo.resumeTimes!.any((time) => time.trim().isNotEmpty);
      
      if (hasValidPauseData && hasValidResumeData) {
        // pause와 resume 둘 다 있는 경우
        int pauseCount = todo.pauseTimes!.length;
        int resumeCount = todo.resumeTimes!.length;
        
        if (pauseCount != resumeCount) {
          // pause가 더 많으면 마지막 pause가 종료시간
          endTime = _parseTime(todo.pauseTimes!.last);
        } else {
          // 개수가 같으면 stop_time 사용
          if (todo.stopTime != null) {
            endTime = _parseTime(todo.stopTime!);
          }
        }
      } else if (hasValidPauseData && !hasValidResumeData) {
        // pause만 있고 resume이 없는 경우 → 첫 번째 pause가 종료시간
        endTime = _parseTime(todo.pauseTimes!.first);
      } else if (todo.stopTime != null) {
        // pause도 없고 resume도 없으면 stop_time 사용
        endTime = _parseTime(todo.stopTime!);
      }

      if (startTime == null || endTime == null) return '0초';

      int totalSeconds = endTime.difference(startTime).inSeconds;
      int pausedSeconds = _calculatePausedTimeInSeconds(todo);
      
      int workingSeconds = totalSeconds - pausedSeconds;
      workingSeconds = workingSeconds < 0 ? 0 : workingSeconds;
      
      // 초 단위로 시간 표시
      if (workingSeconds < 60) {
        return '${workingSeconds}초';
      } else if (workingSeconds < 3600) {
        int minutes = workingSeconds ~/ 60;
        int seconds = workingSeconds % 60;
        return '${minutes}분 ${seconds}초';
      } else {
        int hours = workingSeconds ~/ 3600;
        int minutes = (workingSeconds % 3600) ~/ 60;
        int seconds = workingSeconds % 60;
        return '${hours}시간 ${minutes}분 ${seconds}초';
      }
    } catch (e) {
      return '0초';
    }
  }

  // 일시정지 시간 계산 (초 단위)
  int _calculatePausedTimeInSeconds(TodoItem todo) {
    bool hasValidPauseData = todo.pauseTimes != null && 
                             todo.pauseTimes!.isNotEmpty &&
                             todo.pauseTimes!.any((time) => time.trim().isNotEmpty);
    bool hasValidResumeData = todo.resumeTimes != null && 
                              todo.resumeTimes!.isNotEmpty &&
                              todo.resumeTimes!.any((time) => time.trim().isNotEmpty);
    
    // if문1,2: pause_times, resume_times 둘다 없거나, pause_times만 있고 resume_times가 없으면 쉬는시간 없음
    if (!hasValidPauseData || !hasValidResumeData) {
      return 0;
    }
    
    // if문3,4: 둘다 있을 때 처리
    int pausedSeconds = 0;
    int pauseCount = todo.pauseTimes!.length;
    int resumeCount = todo.resumeTimes!.length;
    
    // if문4: 둘다 있고 리스트 len이 같으면 인덱스별로 매칭
    if (pauseCount == resumeCount) {
      for (int i = 0; i < pauseCount; i++) {
        try {
          DateTime pauseTime = _parseTime(todo.pauseTimes![i]);
          DateTime resumeTime = _parseTime(todo.resumeTimes![i]);
          int restSeconds = resumeTime.difference(pauseTime).inSeconds;
          if (restSeconds > 0) {
            pausedSeconds += restSeconds;
          }
        } catch (e) {
          // 무시
        }
      }
    }
    // if문3: 둘다 있지만 값 리스트 len이 다르면
    else {
      // 작은 쪽 개수만큼 쉬는시간 계산
      int pairCount = pauseCount < resumeCount ? pauseCount : resumeCount;
      for (int i = 0; i < pairCount; i++) {
        try {
          DateTime pauseTime = _parseTime(todo.pauseTimes![i]);
          DateTime resumeTime = _parseTime(todo.resumeTimes![i]);
          int restSeconds = resumeTime.difference(pauseTime).inSeconds;
          if (restSeconds > 0) {
            pausedSeconds += restSeconds;
          }
        } catch (e) {
          // 무시
        }
      }
    }
    
    return pausedSeconds;
  }

  // 일시정지 시간 계산 (분 단위 - 기존 호환성)
  int _calculatePausedTime(TodoItem todo) {
    bool hasValidPauseData = todo.pauseTimes != null && 
                             todo.pauseTimes!.isNotEmpty &&
                             todo.pauseTimes!.any((time) => time.trim().isNotEmpty);
    bool hasValidResumeData = todo.resumeTimes != null && 
                              todo.resumeTimes!.isNotEmpty &&
                              todo.resumeTimes!.any((time) => time.trim().isNotEmpty);
    
    // if문1,2: pause_times, resume_times 둘다 없거나, pause_times만 있고 resume_times가 없으면 쉬는시간 없음
    if (!hasValidPauseData || !hasValidResumeData) {
      return 0;
    }
    
    // if문3,4: 둘다 있을 때 처리
    int pausedMinutes = 0;
    int pauseCount = todo.pauseTimes!.length;
    int resumeCount = todo.resumeTimes!.length;
    
    // if문4: 둘다 있고 리스트 len이 같으면 인덱스별로 매칭
    if (pauseCount == resumeCount) {
      for (int i = 0; i < pauseCount; i++) {
        try {
          DateTime pauseTime = _parseTime(todo.pauseTimes![i]);
          DateTime resumeTime = _parseTime(todo.resumeTimes![i]);
          int restMinutes = resumeTime.difference(pauseTime).inMinutes;
          if (restMinutes > 0) {
            pausedMinutes += restMinutes;
          }
        } catch (e) {
          // 무시
        }
      }
    }
    // if문3: 둘다 있지만 값 리스트 len이 다르면
    else {
      // 작은 쪽 개수만큼 쉬는시간 계산
      int pairCount = pauseCount < resumeCount ? pauseCount : resumeCount;
      for (int i = 0; i < pairCount; i++) {
        try {
          DateTime pauseTime = _parseTime(todo.pauseTimes![i]);
          DateTime resumeTime = _parseTime(todo.resumeTimes![i]);
          int restMinutes = resumeTime.difference(pauseTime).inMinutes;
          if (restMinutes > 0) {
            pausedMinutes += restMinutes;
          }
        } catch (e) {
          // 무시
        }
      }
    }
    
    return pausedMinutes;
  }

  // 시간 문자열 파싱
  DateTime _parseTime(String timeString) {
    final today = DateTime.now();
    final parts = timeString.split(':');
    return DateTime(
      today.year, 
      today.month, 
      today.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
      parts.length > 2 ? int.parse(parts[2]) : 0,
    );
  }

  // 시간 시각화 위젯
  Widget _buildTimeVisualization(TodoItem todo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '작업 타임라인',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            child: _buildTimeline(todo),
          ),
        ],
      ),
    );
  }

  // 타임라인 구성
  Widget _buildTimeline(TodoItem todo) {
    List<Widget> timelineItems = [];
    
    // 1. 시작 시간
    if (todo.startTime != null) {
      timelineItems.add(_buildTimelineItem(
        '시작', 
        todo.startTime!, 
        Colors.green,
        Icons.play_arrow,
      ));
    }

    // 2. 쉬는 시간 처리
    bool hasValidPauseData = todo.pauseTimes != null && 
                             todo.pauseTimes!.isNotEmpty &&
                             todo.pauseTimes!.any((time) => time.trim().isNotEmpty);
    bool hasValidResumeData = todo.resumeTimes != null && 
                              todo.resumeTimes!.isNotEmpty &&
                              todo.resumeTimes!.any((time) => time.trim().isNotEmpty);
    
    // if문1,2: pause_times, resume_times 둘다 없거나, pause_times만 있고 resume_times가 없으면 쉬는시간 없음
    if (!hasValidPauseData || !hasValidResumeData) {
      // 쉬는시간 없음
    }
    // if문3,4: 둘다 있을 때 처리
    else {
      int pauseCount = todo.pauseTimes!.length;
      int resumeCount = todo.resumeTimes!.length;
      
      // if문4: 둘다 있고 리스트 len이 같으면 인덱스별로 매칭시켜서 쉬는시간에 넣기
      if (pauseCount == resumeCount) {
        for (int i = 0; i < pauseCount; i++) {
          String pauseTime = todo.pauseTimes![i];
          String resumeTime = todo.resumeTimes![i];
          timelineItems.add(_buildRestTimeItem(pauseTime, resumeTime));
        }
      }
      // if문3: 둘다 있지만 값 리스트 len이 다르면 pause_times의 마지막 인덱스가 종료시간
      else {
        // 작은 쪽 개수만큼 쉬는시간 표시
        int pairCount = pauseCount < resumeCount ? pauseCount : resumeCount;
        for (int i = 0; i < pairCount; i++) {
          String pauseTime = todo.pauseTimes![i];
          String resumeTime = todo.resumeTimes![i];
          timelineItems.add(_buildRestTimeItem(pauseTime, resumeTime));
        }
      }
    }

    // 3. 완료 시간 결정
    String? endTime;
    String endLabel = '완료';
    
    if (hasValidPauseData && hasValidResumeData) {
      // pause와 resume 둘 다 있는 경우
      int pauseCount = todo.pauseTimes!.length;
      int resumeCount = todo.resumeTimes!.length;
      
      if (pauseCount != resumeCount) {
        // pause가 더 많으면 마지막 pause가 종료시간
        endTime = todo.pauseTimes!.last;
        endLabel = '완료';
      } else {
        // 개수가 같으면 stop_time 사용
        if (todo.stopTime != null) {
          endTime = todo.stopTime!;
          endLabel = '완료';
        }
      }
         } else if (hasValidPauseData && !hasValidResumeData) {
       // pause만 있고 resume이 없는 경우 → 첫 번째 pause가 종료시간
       endTime = todo.pauseTimes!.first;
      endLabel = '완료';
    } else if (todo.stopTime != null) {
      // pause도 없고 resume도 없으면 stop_time 사용
      endTime = todo.stopTime!;
      endLabel = '완료';
    }

    if (endTime != null) {
      timelineItems.add(_buildTimelineItem(
        endLabel, 
        endTime, 
        Colors.red,
        Icons.stop,
      ));
    }

    return Column(children: timelineItems);
  }

  // 타임라인 아이템
  Widget _buildTimelineItem(String label, String time, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label: $time',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  // 쉬는 시간 아이템
  Widget _buildRestTimeItem(String startTime, String endTime) {
    String duration = _calculateRestDuration(startTime, endTime);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange, width: 1.5),
            ),
            child: Icon(Icons.coffee, size: 12, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '쉬는 시간: $startTime ~ $endTime ($duration)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  // 쉬는 시간 계산 (초 단위 표시)
  String _calculateRestDuration(String startTime, String endTime) {
    try {
      DateTime start = _parseTime(startTime);
      DateTime end = _parseTime(endTime);
      int totalSeconds = end.difference(start).inSeconds;
      
      if (totalSeconds < 60) {
        return '${totalSeconds}초';
      } else if (totalSeconds < 3600) {
        int minutes = totalSeconds ~/ 60;
        int seconds = totalSeconds % 60;
        return '${minutes}분 ${seconds}초';
      } else {
        int hours = totalSeconds ~/ 3600;
        int minutes = (totalSeconds % 3600) ~/ 60;
        int seconds = totalSeconds % 60;
        return '${hours}시간 ${minutes}분 ${seconds}초';
      }
    } catch (e) {
      return '0초';
    }
  }
} 