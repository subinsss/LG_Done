import 'package:cloud_firestore/cloud_firestore.dart';
import 'external_server_service.dart';

class TodoItem {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final String priority;
  final int estimatedMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String userId;

  TodoItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.isCompleted,
    required this.priority,
    this.estimatedMinutes = 30,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    required this.userId,
  });

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TodoItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      priority: data['priority'] ?? 'medium',
      estimatedMinutes: data['estimatedMinutes'] ?? 30,
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      completedAt: data['completedAt']?.toDate(),
      userId: data['userId'] ?? 'anonymous',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'userId': userId,
    };
  }
}

class FirestoreTodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'todos';
  final String _userId = 'anonymous'; // 로그인 없이 사용

  // 할일 추가
  Future<String?> addTodo({
    required String title,
    String description = '',
    String priority = 'medium',
    int estimatedMinutes = 30,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = await _firestore.collection(_collection).add({
        'title': title,
        'description': description,
        'isCompleted': false,
        'priority': priority,
        'estimatedMinutes': estimatedMinutes,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'completedAt': null,
        'userId': _userId,
      });
      
      print('✅ 할일 추가 성공: $title (ID: ${docRef.id})');
      
      // 서버에도 전송
      final todo = TodoItem(
        id: docRef.id,
        title: title,
        description: description,
        isCompleted: false,
        priority: priority,
        estimatedMinutes: estimatedMinutes,
        createdAt: now,
        updatedAt: now,
        userId: _userId,
      );
      ExternalServerService.sendTodoCreate(todo);
      
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

  // 할일 완료 상태 토글
  Future<bool> toggleTodoCompletion(String todoId, bool isCompleted) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'isCompleted': isCompleted,
        'updatedAt': Timestamp.fromDate(now),
      };
      
      if (isCompleted) {
        updateData['completedAt'] = Timestamp.fromDate(now);
      } else {
        updateData['completedAt'] = FieldValue.delete();
      }
      
      await _firestore.collection(_collection).doc(todoId).update(updateData);
      print('✅ 할일 상태 변경 성공: $todoId -> $isCompleted');
      
      // 업데이트된 할일 정보를 서버에 전송
      try {
        final doc = await _firestore.collection(_collection).doc(todoId).get();
        if (doc.exists) {
          final todo = TodoItem.fromFirestore(doc);
          ExternalServerService.sendTodoUpdate(todo);
        }
      } catch (e) {
        print('❌ 서버 전송 중 오류: $e');
      }
      
      return true;
    } catch (e) {
      print('❌ 할일 상태 변경 실패: $e');
      return false;
    }
  }

  // 할일 삭제
  Future<bool> deleteTodo(String todoId) async {
    try {
      // 삭제 전에 할일 정보를 가져옴
      final doc = await _firestore.collection(_collection).doc(todoId).get();
      String title = '';
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        title = data['title'] ?? '';
      }
      
      await _firestore.collection(_collection).doc(todoId).delete();
      print('✅ 할일 삭제 성공: $todoId');
      
      // 서버에도 삭제 알림
      ExternalServerService.sendTodoDelete(todoId, title);
      
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
} 