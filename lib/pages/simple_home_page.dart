import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/firestore_todo_service.dart';
import '../widgets/local_ml_widget.dart';
import '../screens/character_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // 카테고리 목록 (Firebase에서 실시간으로 받아옴)
  List<String> _categories = [];
  StreamSubscription<List<String>>? _categoriesSubscription;
  
  // 달력 관련 추가
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isCalendarExpanded = false;

  // 할일 추가 컨트롤러
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  String _selectedPriority = 'medium';
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = '';

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

  StreamSubscription<QuerySnapshot>? _selectedCharacterSubscription;

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
    _selectedCharacterSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isDataLoading = true;
    });

    try {
      _listenToTodos();
      _listenToCategories();
      _listenToSelectedCharacter();
    } catch (e) {
      print('❌ 데이터 초기화 오류: $e');
    } finally {
      setState(() {
        _isDataLoading = false;
      });
    }
  }

  // 🔥 Firestore에서 선택된 캐릭터 실시간 감지
  void _listenToSelectedCharacter() {
    _selectedCharacterSubscription = FirebaseFirestore.instance
        .collection('characters')
        .where('is_selected', isEqualTo: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final characterData = snapshot.docs.first.data();
        setState(() {
          _selectedAICharacter = {
            'character_id': snapshot.docs.first.id,
            'name': characterData['name'] ?? '이름 없음',
            'image_url': characterData['image_url'] ?? '',
            'prompt': characterData['prompt'] ?? '',
            'is_selected': characterData['is_selected'] ?? false,
          };
        });
        print('✅ 선택된 캐릭터 실시간 업데이트: ${characterData['name']}');
      } else {
        setState(() {
          _selectedAICharacter = null;
        });
        print('📝 선택된 캐릭터 없음 - 기본 이모지 사용');
      }
    }, onError: (error) {
      print('❌ 선택된 캐릭터 스트림 오류: $error');
    });
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

  // Firestore에서 할일 목록 실시간 구독
  void _listenToTodos() {
    _todosSubscription = _firestoreService.getTodosStream().listen(
      (todos) {
        setState(() {
          _todos = todos;
        });
      },
      onError: (error) {
        print('❌ 할일 목록 구독 오류: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('할일 목록을 불러오는데 실패했습니다: $error')),
        );
      },
    );
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
    } else {
      print('❌ Firestore 삭제 실패: ${todo.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 삭제에 실패했습니다')),
      );
    }
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
    
    if (!success) {
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
    // 선택한 날짜의 할일만 필터링해서 감정 결정
    final selectedDateTodos = _todos.where((todo) {
      if (todo.dueDate == null) return false;
      return isSameDay(todo.dueDate!, _selectedDay);
    }).toList();

    int completedCount = selectedDateTodos.where((todo) => todo.isCompleted).length;
    double completionRate = selectedDateTodos.isEmpty ? 0 : completedCount / selectedDateTodos.length;
    
    final characterData = _availableCharacters[_selectedCharacter]!;
    String characterDisplay;
    
    if (completionRate >= 0.8) {
      characterDisplay = characterData['type'] == 'emoji' ? characterData['happy'] : characterData['path'];
    } else if (completionRate >= 0.5) {
      characterDisplay = characterData['type'] == 'emoji' ? characterData['working'] : characterData['path'];
    } else if (completionRate > 0) {
      characterDisplay = characterData['type'] == 'emoji' ? characterData['starting'] : characterData['path'];
    } else {
      characterDisplay = characterData['type'] == 'emoji' ? characterData['normal'] : characterData['path'];
    }
    
    if (characterData['type'] == 'emoji') {
      return Text(
        characterDisplay,
        style: const TextStyle(fontSize: 80),
        textAlign: TextAlign.center,
      );
    } else {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(60),
          color: Colors.grey.shade200,
        ),
        child: Icon(
          Icons.person,
          size: 60,
          color: Colors.grey.shade400,
        ),
      );
    }
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('yyyy년 M월 d일').format(_selectedDay),
                style: TextStyle(
                  fontSize: 18,
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
              _buildStatItem('전체', totalTodos, Colors.blue),
              _buildStatItem('완료', completedTodos, Colors.green),
              _buildStatItem('대기', pendingTodos, Colors.orange),
            ],
          ),
          
          // 접었다 폈다 할 수 있는 달력
          if (_isCalendarExpanded) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            TableCalendar<TodoItem>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              eventLoader: (day) => _todos.where((todo) {
                if (todo.dueDate == null) return false;
                return isSameDay(todo.dueDate!, day);
              }).toList(),
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
                markerDecoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
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
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoList() {
    // 선택한 날짜의 할일만 필터링
    final selectedDateTodos = _todos.where((todo) {
      if (todo.dueDate == null) return false;
      return isSameDay(todo.dueDate!, _selectedDay);
    }).toList();

    // 카테고리가 없으면 안내 메시지 표시
    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
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

    // 모든 카테고리를 표시하되, 각 카테고리별로 선택한 날짜의 할일만 필터링
    return Column(
      children: _categories.map((category) {
        final categoryTodos = selectedDateTodos
            .where((todo) => todo.category == category)
            .toList();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리 헤더
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(category),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
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
              
              // 카테고리별 할일 목록
              if (categoryTodos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      '${DateFormat('M월 d일').format(_selectedDay)}에 이 카테고리의 할일이 없습니다',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...categoryTodos.map((todo) => _buildTodoItem(todo)).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodoItem(TodoItem todo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
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
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(todo.priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
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
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade400, size: 20),
            onPressed: () => _showEditTodoDialog(todo),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 20),
            onPressed: () => _deleteTodo(todo),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // 자주 사용되는 카테고리들에 대한 고정 색상
    final predefinedColors = {
      '업무': Colors.blue,
      '개인': Colors.green,
      '학습': Colors.purple,
      '건강': Colors.orange,
      '약속': Colors.cyan,
      '꼭할일': Colors.red,
      '집나가기전': Colors.amber,
      '건우': Colors.teal,
      '마루.아리': Colors.pink,
    };

    if (predefinedColors.containsKey(category)) {
      return predefinedColors[category]!;
    }

    // 새로운 카테고리에 대해서는 해시 기반으로 색상 할당
    final colorOptions = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
      Colors.amber,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.lime,
      Colors.deepOrange,
    ];

    final index = category.hashCode.abs() % colorOptions.length;
    return colorOptions[index];
  }

  void _showAddTodoDialogForCategory(String category) {
    _selectedCategory = category;
    
    // 다이얼로그 열 때마다 초기화
    _selectedDate = _selectedDay;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${category}에 할일 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 할일 제목 입력
                TextField(
                  controller: _todoController,
                  decoration: const InputDecoration(
                    hintText: '할일을 입력하세요',
                    border: OutlineInputBorder(),
                    labelText: '할일',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                
                // 우선순위 선택
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    labelText: '우선순위',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('높음')),
                    DropdownMenuItem(value: 'medium', child: Text('보통')),
                    DropdownMenuItem(value: 'low', child: Text('낮음')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedPriority = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // 선택된 날짜 표시 (수정 불가)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '날짜: ${DateFormat('yyyy년 M월 d일').format(_selectedDay)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey.shade400,
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
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: _addTodo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('추가'),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '할일 관리',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          // 프리미엄 테스트 버튼
          IconButton(
            onPressed: () {
              setState(() {
                _isPremiumUser = !_isPremiumUser;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isPremiumUser ? 'Premium 모드로 변경되었습니다' : 'Free 모드로 변경되었습니다',
                  ),
                  backgroundColor: _isPremiumUser ? Colors.amber.shade600 : Colors.grey.shade600,
                ),
              );
            },
            icon: Icon(
              _isPremiumUser ? Icons.star : Icons.star_border,
              color: _isPremiumUser ? Colors.yellow.shade200 : Colors.white,
            ),
            tooltip: _isPremiumUser ? 'Premium 모드' : 'Free 모드 (탭하여 변경)',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 캐릭터 이미지
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: Stack(
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.settings,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // 빠른 통계
            _buildQuickStats(),
            const SizedBox(height: 20),
            
            // 할일 목록 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '할일 목록',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${_todos.where((todo) {
                        if (todo.dueDate == null) return false;
                        return isSameDay(todo.dueDate!, _selectedDay);
                      }).length}개',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCategoryManagementDialog,
                      icon: const Icon(Icons.category, size: 18),
                      label: const Text('카테고리 관리'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 할일 목록
            _buildTodoList(),
            
            const SizedBox(height: 20),
            
            // ML 위젯
            LocalMLWidget(
              todos: _todos.map((todo) => {
                'title': todo.title,
                'isCompleted': todo.isCompleted,
                'priority': todo.priority,
              }).toList(),
              completionRate: _todos.isEmpty ? 0 : _todos.where((todo) => todo.isCompleted).length / _todos.length,
              totalTodos: _todos.length,
              completedTodos: _todos.where((todo) => todo.isCompleted).length,
              studyTimeMinutes: 60,
              currentMood: _todos.isEmpty ? 'encouraging' : 
                          (_todos.where((todo) => todo.isCompleted).length / _todos.length > 0.7 ? 'happy' : 
                           _todos.where((todo) => todo.isCompleted).length / _todos.length > 0.4 ? 'working' : 'encouraging'),
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
          title: Row(
            children: [
              Icon(Icons.category, color: Colors.black),
              const SizedBox(width: 8),
              const Text('카테고리 관리'),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '새 카테고리 추가',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _categoryController,
                              decoration: const InputDecoration(
                                hintText: '카테고리 이름',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onSubmitted: (_) => _addCategoryFromDialog(setDialogState),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _addCategoryFromDialog(setDialogState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('추가'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 카테고리 목록 섹션
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현재 카테고리 (${_categories.length}개)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                    const SizedBox(height: 8),
                                    Text(
                                      '카테고리가 없습니다',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(category),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      title: Text(category),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade400,
                                        ),
                                        onPressed: () => _deleteCategoryFromDialog(category, setDialogState),
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
        // categories 컬렉션에 직접 추가 (더미 할일 생성하지 않음)
        final categoryId = await _firestoreService.addCategory(newCategory);
        
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

  void _deleteCategoryFromDialog(String category, StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text('카테고리 "$category"를 삭제하시겠습니까?\n이 카테고리의 모든 할일도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
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
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('카테고리 삭제에 실패했습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('카테고리 삭제에 실패했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
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
          title: const Text('할일 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 할일 제목 입력
                TextField(
                  controller: _todoController,
                  decoration: const InputDecoration(
                    hintText: '할일을 입력하세요',
                    border: OutlineInputBorder(),
                    labelText: '할일',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                
                // 우선순위 선택
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    labelText: '우선순위',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('높음')),
                    DropdownMenuItem(value: 'medium', child: Text('보통')),
                    DropdownMenuItem(value: 'low', child: Text('낮음')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedPriority = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // 카테고리 선택
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // 날짜 표시 (수정 불가)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '날짜: ${DateFormat('yyyy년 M월 d일').format(todo.dueDate ?? DateTime.now())}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey.shade400,
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
              child: const Text('취소'),
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
              ),
              child: const Text('저장'),
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
      print('🔄 캐릭터 변경됨! 실시간 업데이트될 예정...');
      // 실시간 스트림이 자동으로 업데이트하므로 별도 로딩 불필요
    }
  }
} 