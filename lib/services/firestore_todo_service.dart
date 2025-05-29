import 'package:cloud_firestore/cloud_firestore.dart';

class TodoItem {
  final String id;
  final String title;
  final bool isCompleted;
  final String priority;
  final DateTime? dueDate;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String userId;
  final String category;

  TodoItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.priority,
    this.dueDate,
    this.updatedAt,
    this.completedAt,
    required this.userId,
    required this.category,
  });

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TodoItem(
      id: doc.id,
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      priority: data['priority'] ?? 'medium',
      dueDate: data['dueDate']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      completedAt: data['completedAt']?.toDate(),
      userId: data['userId'] ?? 'anonymous',
      category: data['category'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'priority': priority,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'userId': userId,
      'category': category,
    };
  }
}

class FirestoreTodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'todos';
  final String _categoriesCollection = 'categories';
  final String _userId = 'anonymous'; // 로그인 없이 사용

  // 할일 추가 - Firestore에 직접 저장
  Future<String?> addTodo({
    required String title,
    String priority = 'medium',
    DateTime? dueDate,
    required String category,
  }) async {
    try {
      final now = DateTime.now();
      final defaultDueDate = dueDate ?? DateTime(now.year, now.month, now.day);
      
      final docRef = await _firestore.collection(_collection).add({
        'title': title,
        'isCompleted': false,
        'priority': priority,
        'dueDate': Timestamp.fromDate(defaultDueDate),
        'updatedAt': Timestamp.fromDate(now),
        'completedAt': null,
        'userId': _userId,
        'category': category,
      });
      
      print('✅ Firestore에 할일 추가 성공: $title (ID: ${docRef.id})');
      return docRef.id;
    } catch (e) {
      print('❌ 할일 추가 실패: $e');
      return null;
    }
  }

  // 할일 목록 실시간 스트림
  Stream<List<TodoItem>> getTodosStream() {
    print('🔄 Firestore 스트림 시작...');
    
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .handleError((error) {
          print('❌ Firestore 스트림 오류: $error');
          print('❌ 오류 타입: ${error.runtimeType}');
          if (error.toString().contains('indexes')) {
            print('💡 해결방법: Firebase Console에서 복합 인덱스를 생성해야 합니다.');
          }
          throw error;
        })
        .map((snapshot) {
      print('📊 전체 문서 개수: ${snapshot.docs.length}');
      
      final todos = snapshot.docs.map((doc) {
        try {
          print('📄 문서 데이터: ${doc.data()}');
          return TodoItem.fromFirestore(doc);
        } catch (e) {
          print('❌ 문서 파싱 오류: $e');
          print('❌ 문서 ID: ${doc.id}');
          print('❌ 문서 데이터: ${doc.data()}');
          rethrow;
        }
      }).toList();
      
      print('✅ 필터링된 할일 개수: ${todos.length}');
      print('📦 Firestore에서 받은 할일 개수: ${todos.length}');
      
      for (var todo in todos) {
        print('📝 할일: ${todo.title} (완료: ${todo.isCompleted})');
      }
      
      return todos;
    });
  }

  // 할일 완료 상태 토글 - Firestore에 직접 업데이트
  Future<bool> toggleTodoCompletion(String todoId, bool isCompleted) async {
    try {
      final now = DateTime.now();
      
      await _firestore.collection(_collection).doc(todoId).update({
        'isCompleted': isCompleted,
        'updatedAt': Timestamp.fromDate(now),
        'completedAt': isCompleted ? Timestamp.fromDate(now) : null,
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
      await _firestore.collection(_collection).doc(todoId).delete();
      print('✅ Firestore에서 할일 삭제 성공: $todoId');
      return true;
    } catch (e) {
      print('❌ 할일 삭제 실패: $e');
      return false;
    }
  }

  // 완료된 할일 목록
  Future<List<TodoItem>> getCompletedTodos() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
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
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: false)
          .orderBy('createdAt', descending: false)
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
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      int total = snapshot.docs.length;
      int completed = snapshot.docs.where((doc) => doc.data()['isCompleted'] == true).length;
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
      final snapshot = await _firestore
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
      
      final snapshot = await _firestore
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
          await _firestore.collection(_collection).doc(doc.id).delete();
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
  Future<String?> addCategory(String categoryName) async {
    try {
      // 먼저 중복 체크
      final existingSnapshot = await _firestore
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .where('name', isEqualTo: categoryName)
          .get();
      
      if (existingSnapshot.docs.isNotEmpty) {
        print('⚠️ 카테고리 이미 존재함: $categoryName');
        return existingSnapshot.docs.first.id;
      }
      
      final docRef = await _firestore.collection(_categoriesCollection).add({
        'name': categoryName,
        'userId': _userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      
      print('✅ 카테고리 추가 성공: $categoryName (ID: ${docRef.id})');
      return docRef.id;
    } catch (e) {
      print('❌ 카테고리 추가 실패: $e');
      return null;
    }
  }

  // 카테고리 목록 가져오기
  Stream<List<String>> getCategoriesStream() {
    print('🔄 카테고리 스트림 시작...');
    
    return _firestore
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
      final todosWithCategory = await _firestore
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
      final categorySnapshot = await _firestore
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
      await _firestore.collection(_collection).doc(todoId).update({
        'category': newCategory,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
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
      
      final snapshot = await _firestore
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
      
      final snapshot = await _firestore
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
      
      final snapshot = await _firestore
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
      final categoriesSnapshot = await _firestore
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: _userId)
          .get();
      
      print('📁 Categories 컬렉션:');
      print('   - 문서 개수: ${categoriesSnapshot.docs.length}');
      for (var doc in categoriesSnapshot.docs) {
        print('   - ${doc.id}: ${doc.data()}');
      }
      
      // todos 컬렉션 확인
      final todosSnapshot = await _firestore
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
    
    return _firestore
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
      
      final snapshot = await _firestore
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
      final now = DateTime.now();
      
      await _firestore.collection(_collection).doc(todoId).update({
        'title': title,
        'priority': priority,
        'dueDate': Timestamp.fromDate(dueDate),
        'category': category,
        'updatedAt': Timestamp.fromDate(now),
      });
      
      print('✅ Firestore에서 할일 수정 성공: $todoId');
      return true;
    } catch (e) {
      print('❌ 할일 수정 실패: $e');
      return false;
    }
  }
} 