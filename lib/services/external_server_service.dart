import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firestore_todo_service.dart';

class ExternalServerService {
  static const String _baseUrl = 'https://flask-iot-server-mqox.onrender.com';
  
  // 서버 연동 활성화/비활성화 플래그
  static bool isEnabled = false; // ESP 전용 서버이므로 기본 비활성화
  
  // 마지막 서버 연결 시도 시간
  static DateTime? lastConnectionAttempt;
  static bool lastConnectionSuccess = false;
  
  // 할일 생성 시 서버에 전송
  static Future<bool> sendTodoCreate(TodoItem todo) async {
    lastConnectionAttempt = DateTime.now();
    
    if (!isEnabled) {
      return true; // 성공으로 처리
    }
    
    try {
      print('🚀 할일 생성 서버 전송: ${todo.title}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/firebase-data'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'action': 'create',
          'title': todo.title,
          'id': todo.id,
          'isCompleted': todo.isCompleted,
          'priority': todo.priority,
          'estimatedMinutes': todo.estimatedMinutes,
          'dueDate': todo.dueDate?.toIso8601String(),
          'createdAt': todo.createdAt?.toIso8601String(),
          'updatedAt': todo.updatedAt?.toIso8601String(),
          'userId': todo.userId,
        }),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ 할일 생성 전송 성공: ${todo.title}');
        lastConnectionSuccess = true;
        return true;
      } else {
        print('❌ 할일 생성 전송 실패: ${response.statusCode}');
        lastConnectionSuccess = false;
        return false;
      }
    } catch (e) {
      print('❌ 할일 생성 전송 오류: $e');
      lastConnectionSuccess = false;
      return false;
    }
  }
  
  // 할일 업데이트 시 서버에 전송
  static Future<bool> sendTodoUpdate(TodoItem todo) async {
    if (!isEnabled) {
      return true;
    }
    
    try {
      print('🔄 할일 업데이트 서버 전송: ${todo.title}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/firebase-data'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'update',
          'id': todo.id,
          'title': todo.title,
          'isCompleted': todo.isCompleted,
          'priority': todo.priority,
          'estimatedMinutes': todo.estimatedMinutes,
          'dueDate': todo.dueDate?.toIso8601String(),
          'createdAt': todo.createdAt?.toIso8601String(),
          'updatedAt': todo.updatedAt?.toIso8601String(),
          'completedAt': todo.completedAt?.toIso8601String(),
          'userId': todo.userId,
        }),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('✅ 업데이트 전송 성공: ${todo.title}');
        return true;
      } else {
        print('❌ 업데이트 전송 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 업데이트 전송 오류: $e');
      return false;
    }
  }
  
  // 할일 삭제 시 서버에 전송
  static Future<bool> sendTodoDelete(String todoId, String title) async {
    if (!isEnabled) {
      return true;
    }
    
    try {
      print('🗑️ 할일 삭제 서버 전송: $title');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/firebase-data'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'delete',
          'id': todoId,
          'title': title,
        }),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('✅ 삭제 전송 성공: $title');
        return true;
      } else {
        print('❌ 삭제 전송 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 삭제 전송 오류: $e');
      return false;
    }
  }
  
  // 전체 할일 목록을 서버에 동기화
  static Future<bool> syncAllTodosToServer(List<TodoItem> todos) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/todos/sync'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'action': 'sync',
          'todos': todos.map((todo) => {
            'id': todo.id,
            'title': todo.title,
            'isCompleted': todo.isCompleted,
            'priority': todo.priority,
            'estimatedMinutes': todo.estimatedMinutes,
            'dueDate': todo.dueDate?.toIso8601String(),
            'createdAt': todo.createdAt?.toIso8601String(),
            'updatedAt': todo.updatedAt?.toIso8601String(),
            'completedAt': todo.completedAt?.toIso8601String(),
            'userId': todo.userId,
          }).toList(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      print('🌐 전체 동기화 서버 전송: ${response.statusCode}');
      print('📤 동기화 데이터: ${todos.length}개 할일');
      
      if (response.statusCode == 200) {
        print('✅ 서버 동기화 성공: ${todos.length}개 할일');
        return true;
      } else {
        print('❌ 서버 동기화 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ 서버 동기화 오류: $e');
      return false;
    }
  }
  
  // 서버 연결 테스트
  static Future<bool> testConnection() async {
    if (!isEnabled) {
      return false;
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('✅ 서버 연결 성공');
        lastConnectionSuccess = true;
        return true;
      } else {
        print('❌ 서버 연결 실패: ${response.statusCode}');
        lastConnectionSuccess = false;
        return false;
      }
    } catch (e) {
      print('❌ 서버 연결 오류: $e');
      lastConnectionSuccess = false;
      return false;
    }
  }
  

} 