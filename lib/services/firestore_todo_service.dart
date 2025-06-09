import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TodoItem {
  final String id;
  final String title;
  final bool isCompleted;
  final String priority;
  final DateTime? dueDate; // 시간 제외, 날짜만
  final String userId;
  final String category;
  final int order; // 순서 필드 추가
  
  // 시간 관련 필드들 추가
  final String? startTime;
  final String? stopTime;
  final List<String>? pauseTimes;
  final List<String>? resumeTimes;

  TodoItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.priority,
    this.dueDate,
    required this.userId,
    required this.category,
    this.order = 0, // 기본값 0
    this.startTime,
    this.stopTime,
    this.pauseTimes,
    this.resumeTimes,
  });

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // due_date_string이나 기존 dueDate 필드 체크
    DateTime? parsedDate;
    
    // 새로운 문자열 필드 우선 체크
    if (data['due_date_string'] != null) {
      try {
        parsedDate = DateTime.parse(data['due_date_string']);
      } catch (e) {
        print('❌ 날짜 파싱 오류: ${data['due_date_string']}');
      }
    }
    // 기존 dueDate 필드 체크 (하위 호환성)
    else if (data['dueDate'] != null) {
      if (data['dueDate'] is String) {
        try {
          parsedDate = DateTime.parse(data['dueDate']);
        } catch (e) {
          print('❌ 날짜 파싱 오류: ${data['dueDate']}');
        }
      } else if (data['dueDate'] is Timestamp) {
        parsedDate = data['dueDate'].toDate();
      }
    }
    
    // 기존 isCompleted와 새로운 is_completed 모두 지원
    bool completed = data['is_completed'] ?? data['isCompleted'] ?? false;
    
    // 시간 필드들 읽기
    List<String>? pauseTimes;
    List<String>? resumeTimes;
    
    // 시간 데이터 파싱 (핵심 로그만)
    if (data['pause_times'] != null) {
      try {
        if (data['pause_times'] is List) {
          pauseTimes = List<String>.from(data['pause_times']);
        } else if (data['pause_times'] is String) {
          String pauseStr = data['pause_times'];
          
          if (pauseStr.startsWith('[') && pauseStr.endsWith(']')) {
            try {
              String cleanStr = pauseStr.substring(1, pauseStr.length - 1).trim();
              
              if (cleanStr.isEmpty) {
                pauseTimes = [];
              } else {
                pauseTimes = cleanStr
                    .split(',')
                    .map((s) => s.trim().replaceAll("'", "").replaceAll('"', ''))
                    .where((s) => s.isNotEmpty)
                    .toList();
              }
            } catch (e) {
              pauseTimes = null;
            }
          } else {
            pauseTimes = [pauseStr];
          }
        }
      } catch (e) {
        pauseTimes = null;
      }
    }
    
    if (data['resume_times'] != null) {
      try {
        if (data['resume_times'] is List) {
          resumeTimes = List<String>.from(data['resume_times']);
        } else if (data['resume_times'] is String) {
          String resumeStr = data['resume_times'];
          
          if (resumeStr.startsWith('[') && resumeStr.endsWith(']')) {
            try {
              String cleanStr = resumeStr.substring(1, resumeStr.length - 1).trim();
              
              if (cleanStr.isEmpty) {
                resumeTimes = [];
                print('📊 ${data['title']}: resume_times 빈 배열');
              } else {
                resumeTimes = cleanStr
                    .split(',')
                    .map((s) => s.trim().replaceAll("'", "").replaceAll('"', ''))
                    .where((s) => s.isNotEmpty)
                    .toList();
              }
            } catch (e) {
              resumeTimes = null;
            }
          } else {
            resumeTimes = [resumeStr];
          }
        }
      } catch (e) {
        resumeTimes = null;
      }
    }
    
    return TodoItem(
      id: doc.id,
      title: data['title'] ?? '',
      isCompleted: completed,
      priority: data['priority'] ?? 'medium',
      dueDate: parsedDate,
      userId: data['userId'] ?? 'anonymous',
      category: data['category'] ?? '',
      order: data['order'] ?? 0,
      startTime: data['start_time'],
      stopTime: data['stop_time'],
      pauseTimes: pauseTimes,
      resumeTimes: resumeTimes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'is_completed': isCompleted,
      'priority': priority,
      'due_date_string': dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null,
      'userId': userId,
      'category': category,
      'order': order,
    };
  }
}

class FirestoreTodoService {
  static final FirestoreTodoService _instance = FirestoreTodoService._internal();
  factory FirestoreTodoService() => _instance;
  
  FirebaseFirestore? _firestore;
  final String _collection = 'todos';
  final String _categoriesCollection = 'categories';  // 카테고리 컬렉션 이름
  final String _userId = 'anonymous'; // 로그인 없이 사용

  FirestoreTodoService._internal();

  // Firebase 초기화 메서드
  void initialize(FirebaseFirestore firestoreInstance) {
    _firestore = firestoreInstance;
  }

  // Firebase 사용 가능 여부 확인
  Future<bool> _isFirebaseAvailable() async {
    return _firestore != null;
  }

  // 할일 추가 - Firestore에 직접 저장
  Future<String?> addTodo({
    required String title,
    String priority = 'medium',
    DateTime? dueDate,
    required String category,
  }) async {
    try {
      // 날짜를 문자열로 저장 (YYYY-MM-DD 형식)
      String? dateString;
      if (dueDate != null) {
        final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
        dateString = DateFormat('yyyy-MM-dd').format(dateOnly);
      }
      
      // 해당 카테고리와 날짜의 기존 할일 개수를 조회하여 순서 설정
      final existingTodos = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('category', isEqualTo: category)
          .where('due_date_string', isEqualTo: dateString)
          .get();
      
      final newOrder = existingTodos.docs.length;
      
      final docRef = await _firestore!.collection(_collection).add({
        'title': title,
        'is_completed': false,
        'priority': priority,
        'due_date_string': dateString,
        'userId': _userId,
        'category': category,
        'order': newOrder,
      });
      
      print('✅ Firestore에 할일 추가 성공: $title (ID: ${docRef.id})');
      print('📅 저장된 날짜: $dateString');
      print('📋 순서: $newOrder');
      return docRef.id;
    } catch (e) {
      print('❌ 할일 추가 실패: $e');
      return null;
    }
  }

  // 할일 목록 실시간 스트림 (오늘 날짜 기준)
  Stream<List<TodoItem>> getTodosStream() {
    print('🔄 Firestore 스트림 시작...');
    
    // 오늘 날짜 계산
    final today = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, today.day));
    
    print('📅 오늘 날짜 필터: $todayString');
    
    return _firestore!
        .collection(_collection)
        .where('userId', isEqualTo: _userId)
        .where('due_date_string', isEqualTo: todayString) // 오늘 날짜만 가져오기
        .snapshots(includeMetadataChanges: true)
        .handleError((error) {
          print('❌ Firestore 스트림 오류: $error');
          print('❌ 오류 타입: ${error.runtimeType}');
          print('❌ 상세 정보: ${error.toString()}');
          
          if (error.toString().contains('indexes')) {
            print('💡 해결방법: Firebase Console에서 복합 인덱스를 생성해야 합니다.');
          } else if (error.toString().contains('permission')) {
            print('💡 해결방법: Firestore 보안 규칙을 확인해주세요.');
          } else if (error.toString().contains('network') || error.toString().contains('connection')) {
            print('💡 해결방법: 네트워크 연결을 확인해주세요.');
          }
          
          throw error;
        })
        .map((snapshot) {
      print('📊 오늘 할일 개수: ${snapshot.docs.length}');
      print('📊 메타데이터 - hasPendingWrites: ${snapshot.metadata.hasPendingWrites}');
      print('📊 메타데이터 - isFromCache: ${snapshot.metadata.isFromCache}');
      
      final todos = snapshot.docs.map((doc) {
        try {
          return TodoItem.fromFirestore(doc);
        } catch (e) {
          print('❌ 문서 파싱 오류: $e');
          print('❌ 문서 ID: ${doc.id}');
          rethrow;
        }
      }).toList();
      
      print('✅ 오늘 할일 처리 완료: ${todos.length}개');
      
      return todos;
    });
  }

  // 할일 완료 상태 토글 - Firestore에 직접 업데이트
  Future<bool> toggleTodoCompletion(String todoId, bool isCompleted) async {
    try {
      await _firestore!.collection(_collection).doc(todoId).update({
        'is_completed': isCompleted,
      });
      
      print('✅ Firestore에서 할일 상태 변경 성공: $todoId -> $isCompleted');
      return true;
    } catch (e) {
      print('❌ 할일 상태 변경 실패: $e');
      return false;
    }
  }

  // 할일 삭제 - Firestore에서 직접 삭제
  Future<bool> deleteTodo(String todoId) async {
    try {
      await _firestore!.collection(_collection).doc(todoId).delete();
      print('✅ Firestore에서 할일 삭제 성공: $todoId');
      return true;
    } catch (e) {
      print('❌ 할일 삭제 실패: $e');
      return false;
    }
  }

  // 할일 순서 변경 - 같은 카테고리, 같은 날짜 내에서만
  Future<bool> reorderTodos(String category, DateTime date, int oldIndex, int newIndex) async {
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      
      // 해당 카테고리와 날짜의 모든 할일 가져오기
      final snapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('category', isEqualTo: category)
          .where('due_date_string', isEqualTo: dateString)
          .get();
      
      // 클라이언트 사이드에서 정렬
      final todos = snapshot.docs.toList();
      todos.sort((a, b) {
        final aOrder = a.data()['order'] ?? 0;
        final bOrder = b.data()['order'] ?? 0;
        return aOrder.compareTo(bOrder);
      });
      
      if (oldIndex >= todos.length || newIndex >= todos.length) {
        print('❌ 인덱스 범위 초과: oldIndex=$oldIndex, newIndex=$newIndex, length=${todos.length}');
        return false;
      }
      
      // 배치로 업데이트
      final batch = _firestore!.batch();
      
      // 순서 재배열
      if (oldIndex < newIndex) {
        // 뒤로 이동하는 경우
        for (int i = oldIndex + 1; i <= newIndex; i++) {
          batch.update(todos[i].reference, {'order': i - 1});
        }
        batch.update(todos[oldIndex].reference, {'order': newIndex});
      } else {
        // 앞으로 이동하는 경우
        for (int i = newIndex; i < oldIndex; i++) {
          batch.update(todos[i].reference, {'order': i + 1});
        }
        batch.update(todos[oldIndex].reference, {'order': newIndex});
      }
      
      await batch.commit();
      print('✅ 할일 순서 변경 성공: $category 카테고리에서 $oldIndex → $newIndex');
      
      // 변경 후 확인
      print('📋 변경된 할일들:');
      for (int i = 0; i < todos.length; i++) {
        final data = todos[i].data();
        final newOrder = i == oldIndex ? newIndex : 
                        (oldIndex < newIndex && i > oldIndex && i <= newIndex) ? i - 1 :
                        (oldIndex > newIndex && i >= newIndex && i < oldIndex) ? i + 1 : 
                        data['order'];
        print('  - ${data['title']}: 순서 ${data['order']} → $newOrder');
      }
      
      return true;
    } catch (e) {
      print('❌ 할일 순서 변경 실패: $e');
      return false;
    }
  }

  // 완료된 할일 목록
  Future<List<TodoItem>> getCompletedTodos() async {
    try {
      final snapshot = await _firestore!.collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('is_completed', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ 완료된 할일 조회 실패: $e');
      return [];
    }
  }

  // 미완료 할일 목록
  Future<List<TodoItem>> getIncompleteTodos() async {
    try {
      final snapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('is_completed', isEqualTo: false)
          .get();
      
      return snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ 미완료 할일 조회 실패: $e');
      return [];
    }
  }

  // 할일 통계
  Future<Map<String, int>> getTodoStats() async {
    try {
      final snapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      int total = snapshot.docs.length;
      int completed = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['is_completed'] ?? data['isCompleted'] ?? false;
      }).length;
      int pending = total - completed;
      
      return {
        'total': total,
        'completed': completed,
        'pending': pending,
      };
    } catch (e) {
      print('❌ 할일 통계 조회 실패: $e');
      return {'total': 0, 'completed': 0, 'pending': 0};
    }
  }

  // 서버 데이터 동기화
  Future<void> syncServerData() async {
    try {
      print('🔄 서버 데이터 동기화 시작...');
      final snapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      print('📊 동기화된 할일 개수: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ 서버 데이터 동기화 실패: $e');
    }
  }

  // 기존 데이터 마이그레이션 - category 필드가 없거나 빈 할일 삭제
  Future<void> migrateLegacyData() async {
    try {
      print('🔄 기존 데이터 마이그레이션 시작...');
      
      final snapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      int deletedCount = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // category 필드가 없거나 빈 문자열이거나 '기본'인 문서 삭제
        if (!data.containsKey('category') || 
            data['category'] == null || 
            data['category'] == '' || 
            data['category'] == '기본') {
          await _firestore!.collection(_collection).doc(doc.id).delete();
          deletedCount++;
          print('🗑️ 카테고리 없는 할일 삭제: ${doc.id}');
        }
      }
      
      print('✅ 마이그레이션 완료: ${deletedCount}개 문서 삭제됨');
    } catch (e) {
      print('❌ 마이그레이션 실패: $e');
    }
  }

  // 카테고리 추가 (중복 체크 강화)
  Future<String?> addCategory(String categoryName, {int? colorValue}) async {
    try {
      // 먼저 중복 체크
      final existingSnapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .where('name', isEqualTo: categoryName)
          .get();
      
      if (existingSnapshot.docs.isNotEmpty) {
        print('⚠️ 카테고리 이미 존재함: $categoryName');
        return existingSnapshot.docs.first.id;
      }
      
      final docRef = await _firestore!.collection(_categoriesCollection).add({
        'name': categoryName,
        'userId': _userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'color': colorValue ?? 0xFF607D8B, // 기본 색상: blueGrey.shade600
      });
      
      print('✅ 카테고리 추가 성공: $categoryName (ID: ${docRef.id})');
      return docRef.id;
    } catch (e) {
      print('❌ 카테고리 추가 실패: $e');
      return null;
    }
  }

  // 카테고리 색상 업데이트
  Future<bool> updateCategoryColor(String categoryName, int colorValue) async {
    try {
      final snapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .where('name', isEqualTo: categoryName)
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('❌ 카테고리를 찾을 수 없음: $categoryName');
        return false;
      }
      
      await snapshot.docs.first.reference.update({
        'color': colorValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      print('✅ 카테고리 색상 업데이트 성공: $categoryName -> $colorValue');
      return true;
    } catch (e) {
      print('❌ 카테고리 색상 업데이트 실패: $e');
      return false;
    }
  }

  // 카테고리 이름 업데이트
  Future<bool> updateCategoryName(String oldCategoryName, String newCategoryName) async {
    try {
      // 새 이름이 이미 존재하는지 확인
      final existingSnapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .where('name', isEqualTo: newCategoryName)
          .get();
      
      if (existingSnapshot.docs.isNotEmpty) {
        print('❌ 새 카테고리 이름이 이미 존재함: $newCategoryName');
        return false;
      }
      
      // 기존 카테고리 찾기
      final categorySnapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .where('name', isEqualTo: oldCategoryName)
          .get();
      
      if (categorySnapshot.docs.isEmpty) {
        print('❌ 기존 카테고리를 찾을 수 없음: $oldCategoryName');
        return false;
      }
      
      // 배치 작업 시작
      final batch = _firestore!.batch();
      
      // 1. 카테고리 컬렉션에서 이름 업데이트
      final categoryDoc = categorySnapshot.docs.first;
      batch.update(categoryDoc.reference, {
        'name': newCategoryName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // 2. 해당 카테고리를 사용하는 모든 할일의 카테고리 필드 업데이트
      final todosSnapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('category', isEqualTo: oldCategoryName)
          .get();
      
      for (var todoDoc in todosSnapshot.docs) {
        batch.update(todoDoc.reference, {
          'category': newCategoryName,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
      
      // 배치 실행
      await batch.commit();
      
      print('✅ 카테고리 이름 업데이트 성공: $oldCategoryName -> $newCategoryName (할일 ${todosSnapshot.docs.length}개 업데이트)');
      return true;
    } catch (e) {
      print('❌ 카테고리 이름 업데이트 실패: $e');
      return false;
    }
  }

  // 카테고리와 색상 정보 함께 가져오기
  Stream<Map<String, int>> getCategoryColorsStream() {
    print('🔄 카테고리 색상 스트림 시작...');
    
    return _firestore!
        .collection(_categoriesCollection)
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .handleError((error) {
          print('❌ 카테고리 색상 스트림 오류: $error');
          throw error;
        })
        .map((snapshot) {
          final categoryColors = <String, int>{};
          
          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              final name = data['name'] as String;
              final color = data['color'] as int? ?? 0xFF607D8B; // 기본 색상
              categoryColors[name] = color;
            } catch (e) {
              print('❌ 카테고리 색상 문서 파싱 오류: $e');
            }
          }
          
          print('✅ 파싱된 카테고리 색상: $categoryColors');
          return categoryColors;
        });
  }

  // 카테고리 목록 가져오기
  Stream<List<String>> getCategoriesStream() {
    print('🔄 카테고리 스트림 시작...');
    
    return _firestore!
        .collection(_categoriesCollection)
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .handleError((error) {
          print('❌ 카테고리 스트림 오류: $error');
          print('❌ 오류 타입: ${error.runtimeType}');
          if (error.toString().contains('indexes')) {
            print('💡 해결방법: Firebase Console에서 복합 인덱스를 생성하거나 orderBy를 제거해야 합니다.');
          }
          throw error;
        })
        .map((snapshot) {
          print('📊 카테고리 문서 개수: ${snapshot.docs.length}');
          
          final categories = snapshot.docs.map((doc) {
            try {
              final data = doc.data();
              print('📄 카테고리 문서 데이터: $data');
              return data['name'] as String;
            } catch (e) {
              print('❌ 카테고리 문서 파싱 오류: $e');
              print('❌ 문서 ID: ${doc.id}');
              print('❌ 문서 데이터: ${doc.data()}');
              return '기본'; // 파싱 실패 시 기본값 반환
            }
          }).toList();
          
          // 클라이언트에서 정렬 (createdAt 필드가 없을 수 있으므로 이름으로 정렬)
          categories.sort();
          
          print('✅ 파싱된 카테고리 목록: $categories');
          
          return categories; // 빈 목록이어도 그대로 반환
        });
  }

  // 카테고리 삭제 (categories 컬렉션에서 삭제 + 해당 카테고리 할일들 삭제)
  Future<bool> deleteCategory(String categoryName) async {
    try {
      // 해당 카테고리의 모든 할일 삭제
      final todosWithCategory = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('category', isEqualTo: categoryName)
          .get();
      
      int deletedTodoCount = 0;
      for (var doc in todosWithCategory.docs) {
        await doc.reference.delete();
        deletedTodoCount++;
      }
      
      // categories 컬렉션에서 카테고리 삭제
      final categorySnapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .where('name', isEqualTo: categoryName)
          .get();
      
      int deletedCategoryCount = 0;
      for (var doc in categorySnapshot.docs) {
        await doc.reference.delete();
        deletedCategoryCount++;
      }
      
      print('✅ 카테고리 "$categoryName" 삭제 완료: 할일 ${deletedTodoCount}개, 카테고리 ${deletedCategoryCount}개 삭제');
      return true;
    } catch (e) {
      print('❌ 카테고리 삭제 실패: $e');
      return false;
    }
  }

  // 할일의 카테고리 업데이트
  Future<bool> updateTodoCategory(String todoId, String newCategory) async {
    try {
      await _firestore!.collection(_collection).doc(todoId).update({
        'category': newCategory,
      });
      
      print('✅ 할일 카테고리 업데이트 성공: $todoId -> $newCategory');
      return true;
    } catch (e) {
      print('❌ 할일 카테고리 업데이트 실패: $e');
      return false;
    }
  }

  // 기본 카테고리 초기화 제거 - 사용자가 직접 추가하도록 변경
  Future<void> initializeDefaultCategories() async {
    try {
      print('🔄 카테고리 시스템 초기화...');
      
      // 중복 카테고리만 정리하고 기본 카테고리는 추가하지 않음
      await cleanupDuplicateCategories();
      
      final snapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      print('📋 기존 카테고리 개수: ${snapshot.docs.length}');
      print('✅ 카테고리 시스템 초기화 완료 (사용자가 직접 추가)');
    } catch (e) {
      print('❌ 카테고리 시스템 초기화 실패: $e');
    }
  }

  // 중복 카테고리 정리
  Future<void> cleanupDuplicateCategories() async {
    try {
      print('🧹 중복 카테고리 정리 시작...');
      
      final snapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      // 카테고리 이름별로 그룹화
      Map<String, List<QueryDocumentSnapshot>> categoryGroups = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('name')) {
          final name = data['name'] as String;
          if (!categoryGroups.containsKey(name)) {
            categoryGroups[name] = [];
          }
          categoryGroups[name]!.add(doc);
        }
      }
      
      int deletedCount = 0;
      
      // 각 카테고리별로 중복 제거 (가장 오래된 것 하나만 남기고 나머지 삭제)
      for (var entry in categoryGroups.entries) {
        final categoryName = entry.key;
        final docs = entry.value;
        
        if (docs.length > 1) {
          print('🔍 중복 카테고리 발견: $categoryName (${docs.length}개)');
          
          // createdAt 기준으로 정렬 (가장 오래된 것을 남김)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aCreated = aData?['createdAt'] as Timestamp?;
            final bCreated = bData?['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return aCreated.compareTo(bCreated);
          });
          
          // 첫 번째(가장 오래된) 것을 제외하고 나머지 삭제
          for (int i = 1; i < docs.length; i++) {
            await docs[i].reference.delete();
            deletedCount++;
            print('🗑️ 중복 카테고리 삭제: $categoryName (ID: ${docs[i].id})');
          }
        }
      }
      
      print('✅ 중복 카테고리 정리 완료: ${deletedCount}개 삭제됨');
    } catch (e) {
      print('❌ 중복 카테고리 정리 실패: $e');
    }
  }

  // 모든 카테고리 삭제 (완전 초기화)
  Future<void> deleteAllCategories() async {
    try {
      print('🧹 모든 카테고리 삭제 시작...');
      
      final snapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      int deletedCount = 0;
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
        print('🗑️ 카테고리 삭제: ${doc.data()['name']} (ID: ${doc.id})');
      }
      
      print('✅ 모든 카테고리 삭제 완료: ${deletedCount}개 삭제됨');
    } catch (e) {
      print('❌ 카테고리 삭제 실패: $e');
    }
  }

  // 디버그: 현재 데이터 상태 확인
  Future<void> debugCheckData() async {
    try {
      print('🔍 === 데이터 상태 확인 ===');
      
      // categories 컬렉션 확인
      final categoriesSnapshot = await _firestore!
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      print('📁 Categories 컬렉션:');
      print('   - 문서 개수: ${categoriesSnapshot.docs.length}');
      for (var doc in categoriesSnapshot.docs) {
        print('   - ${doc.id}: ${doc.data()}');
      }
      
      // todos 컬렉션 확인
      final todosSnapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      print('📝 Todos 컬렉션:');
      print('   - 문서 개수: ${todosSnapshot.docs.length}');
      
      // todos에서 사용된 카테고리들 추출
      Set<String> usedCategories = {};
      for (var doc in todosSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('category')) {
          usedCategories.add(data['category'] as String);
        }
      }
      
      print('   - 사용된 카테고리들: $usedCategories');
      print('🔍 === 확인 완료 ===');
      
    } catch (e) {
      print('❌ 데이터 확인 실패: $e');
    }
  }

  // todos에서 사용된 카테고리 목록 가져오기 (categories 컬렉션 불필요)
  Stream<List<String>> getCategoriesFromTodos() {
    print('🔄 todos에서 카테고리 추출 시작...');
    
    return _firestore!
        .collection(_collection)
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .handleError((error) {
          print('❌ todos 스트림 오류: $error');
          throw error;
        })
        .map((snapshot) {
          print('📊 todos 문서 개수: ${snapshot.docs.length}');
          
          Set<String> categories = {};
          
          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              print('📄 문서 데이터: $data');
              if (data.containsKey('category')) {
                final category = data['category'] as String;
                print('📝 발견된 카테고리: "$category"');
                if (category.isNotEmpty) {
                  categories.add(category);
                  print('✅ 카테고리 추가됨: "$category"');
                }
              } else {
                print('⚠️ 카테고리 필드 없음: ${doc.id}');
              }
            } catch (e) {
              print('❌ 문서 파싱 오류: $e');
            }
          }
          
          final categoryList = categories.toList()..sort();
          print('✅ 최종 추출된 카테고리 목록: $categoryList');
          
          return categoryList; // 빈 목록이어도 그대로 반환
        });
  }

  // 모든 할일 삭제
  Future<bool> deleteAllTodos() async {
    try {
      print('🧹 모든 할일 삭제 시작...');
      
      final snapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      int deletedCount = 0;
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }
      
      print('✅ 모든 할일 삭제 완료: ${deletedCount}개 삭제됨');
      return true;
    } catch (e) {
      print('❌ 모든 할일 삭제 실패: $e');
      return false;
    }
  }

  // 할일 수정 - Firestore에서 직접 업데이트
  Future<bool> updateTodo({
    required String todoId,
    required String title,
    required String priority,
    required DateTime dueDate,
    required String category,
  }) async {
    try {
      // 날짜를 문자열로 저장 (YYYY-MM-DD 형식)
      final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final dateString = DateFormat('yyyy-MM-dd').format(dateOnly);
      
      await _firestore!.collection(_collection).doc(todoId).update({
        'title': title,
        'priority': priority,
        'due_date_string': dateString,
        'category': category,
      });
      
      print('✅ Firestore에서 할일 수정 성공: $todoId');
      print('📅 수정된 날짜: $dateString');
      return true;
    } catch (e) {
      print('❌ 할일 수정 실패: $e');
      return false;
    }
  }
} 