import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firestore_todo_service.dart';

class ExternalServerService {
  static const String _baseUrl = 'https://flask-iot-server-mqox.onrender.com';
  
  // 서버 연동 활성화/비활성화 플래그
  static bool isEnabled = true; // Render 서버로 연동 활성화!
  
  // 할일 생성 시 서버에 전송
  static Future<bool> sendTodoCreate(TodoItem todo) async {
    if (!isEnabled) {
      print('📴 외부 서버 연동이 비활성화되어 있습니다.');
      return true; // 성공으로 처리
    }
    
    try {
      print('🚀 서버 전송 시작: ${todo.title}');
      print('🔗 서버 주소: $_baseUrl');
      
      // 1차 시도: 직접 연결 (CORS 설정이 되어 있다면 성공해야 함)
      try {
        print('🎯 직접 POST 시도: $_baseUrl/firebase-data');
        
        final response = await http.post(
          Uri.parse('$_baseUrl/firebase-data'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
            'User-Agent': 'Flutter-App/1.0',
          },
          body: jsonEncode({
            'title': todo.title,
            'id': todo.id,
            'isCompleted': todo.isCompleted,
            'priority': todo.priority,
          }),
        ).timeout(const Duration(seconds: 10));
        
        print('🌐 직접 POST 요청 결과: ${response.statusCode}');
        print('📄 응답: ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('✅ 직접 POST 서버 전송 성공: ${todo.title}');
          return true;
        }
      } catch (e) {
        print('❌ 직접 POST 요청 실패: $e');
      }
      
      // 2차 시도: 다른 프록시 서비스
      try {
        final proxyUrl2 = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent('$_baseUrl/firebase-data')}';
        print('🔄 대체 프록시 시도: $proxyUrl2');
        
        final response = await http.get(
          Uri.parse(proxyUrl2),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
        
        print('🌐 대체 프록시 요청 결과: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          print('✅ 대체 프록시 서버 연결 성공');
          
          // 실제 POST 요청으로 데이터 전송
          try {
            final postUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(_baseUrl + '/firebase-data')}';
            final postResponse = await http.post(
              Uri.parse(postUrl),
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'action': 'create',
                'todo': {
                  'title': todo.title,
                  'id': todo.id,
                  'isCompleted': todo.isCompleted,
                  'priority': todo.priority,
                  'description': todo.description,
                  'estimatedMinutes': todo.estimatedMinutes,
                  'createdAt': todo.createdAt?.toIso8601String(),
                  'userId': todo.userId,
                },
                'timestamp': DateTime.now().toIso8601String(),
              }),
            );
            
            print('🌐 프록시 POST 결과: ${postResponse.statusCode}');
            if (postResponse.statusCode == 200) {
              print('✅ 프록시 POST 데이터 전송 성공: ${todo.title}');
              return true;
            }
          } catch (e) {
            print('❌ 프록시 POST 실패: $e');
          }
        }
      } catch (e) {
        print('❌ 대체 프록시 요청 실패: $e');
      }
      
      // 3차 시도: 기본 연결 테스트
      try {
        final simpleUri = Uri.parse('$_baseUrl/firebase-data');
        print('🔍 기본 연결 테스트: $simpleUri');
        
        final testResponse = await http.get(
          simpleUri,
          headers: {
            'ngrok-skip-browser-warning': 'true',
            'Accept': '*/*',
            'User-Agent': 'Flutter-App/1.0',
          },
        ).timeout(const Duration(seconds: 5));
        
        print('✅ 기본 연결 성공: ${testResponse.statusCode}');
        print('📄 응답: ${testResponse.body.length > 100 ? testResponse.body.substring(0, 100) + "..." : testResponse.body}');
        
        // 기본 연결이 성공하면 POST 시도
        final postResponse = await http.post(
          simpleUri,
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
            'Accept': '*/*',
            'User-Agent': 'Flutter-App/1.0',
          },
                      body: jsonEncode({
              'title': todo.title,
              'id': todo.id,
              'isCompleted': todo.isCompleted,
              'priority': todo.priority,
            }),
        ).timeout(const Duration(seconds: 10));
        
        print('🌐 POST 요청 결과: ${postResponse.statusCode}');
        
        if (postResponse.statusCode == 200 || postResponse.statusCode == 201) {
          print('✅ 직접 POST 서버 전송 성공: ${todo.title}');
          return true;
        }
        
      } catch (e) {
        print('❌ 기본 연결 실패: $e');
        
        // ngrok 문제일 수 있으므로 추가 정보 제공
        if (e.toString().contains('Failed to fetch')) {
          print('💡 해결 방법들:');
          print('   1. ngrok 터널이 활성화되어 있는지 확인');
          print('   2. 브라우저에서 $_baseUrl 직접 접속 테스트');
          print('   3. 서버의 CORS 설정 재확인');
          print('   4. ngrok 주소가 변경되었는지 확인');
        }
        return false;
      }
      
      print('❌ 모든 서버 전송 방법 실패');
      return false;
      
    } catch (e) {
      print('❌ 일반 서버 전송 오류: $e');
      return false;
    }
  }
  
  // 할일 업데이트 시 서버에 전송
  static Future<bool> sendTodoUpdate(TodoItem todo) async {
    if (!isEnabled) {
      print('📴 외부 서버 연동이 비활성화되어 있습니다.');
      return true;
    }
    
    try {
      print('🔄 할일 업데이트 서버 전송: ${todo.title}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/firebase-data'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'id': todo.id,
          'title': todo.title,
          'isCompleted': todo.isCompleted,
          'priority': todo.priority,
        }),
      );
      
      print('🌐 할일 업데이트 서버 전송: ${response.statusCode}');
      print('📤 전송 데이터: ${todo.title} (완료: ${todo.isCompleted})');
      
      if (response.statusCode == 200) {
        print('✅ 업데이트 서버 전송 성공: ${todo.title}');
        return true;
      } else {
        print('❌ 업데이트 서버 전송 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ 업데이트 서버 전송 오류: $e');
      return false;
    }
  }
  
  // 할일 삭제 시 서버에 전송
  static Future<bool> sendTodoDelete(String todoId, String title) async {
    if (!isEnabled) {
      print('📴 외부 서버 연동이 비활성화되어 있습니다.');
      return true;
    }
    
    try {
      print('🗑️ 할일 삭제 서버 전송: $title');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/firebase-data'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'id': todoId,
          'title': title,
          'deleted': true,
        }),
      );
      
      print('🌐 할일 삭제 서버 전송: ${response.statusCode}');
      print('📤 삭제 데이터: $title (ID: $todoId)');
      
      if (response.statusCode == 200) {
        print('✅ 삭제 서버 전송 성공: $title');
        return true;
      } else {
        print('❌ 삭제 서버 전송 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ 삭제 서버 전송 오류: $e');
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
            'description': todo.description,
            'isCompleted': todo.isCompleted,
            'priority': todo.priority,
            'estimatedMinutes': todo.estimatedMinutes,
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
      print('📴 외부 서버 연동이 비활성화되어 있습니다.');
      return false;
    }
    
    try {
      print('🔍 서버 연결 테스트 시작...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/firebase-data'),
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      print('🌐 서버 연결 테스트: ${response.statusCode}');
      print('📥 서버 응답: ${response.body}');
      print('📋 응답 헤더: ${response.headers}');
      
      if (response.statusCode == 200) {
        print('✅ 서버 연결 성공');
        return true;
      } else {
        print('❌ 서버 연결 실패: ${response.statusCode}');
        return false;
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException 오류: $e');
      print('💡 해결 방법:');
      print('   1. ngrok 터널이 활성화되어 있는지 확인');
      print('   2. 브라우저에서 $_baseUrl/firebase-data 직접 접속 테스트');
      print('   3. Chrome에서 --disable-web-security 플래그로 실행');
      return false;
    } catch (e) {
      print('❌ 서버 연결 오류: $e');
      print('🔍 오류 타입: ${e.runtimeType}');
      return false;
    }
  }
  
  // CORS 우회를 위한 간단한 알림 방식
  static Future<void> notifyServerSimple(String action, String data) async {
    if (!isEnabled) {
      print('📴 외부 서버 연동이 비활성화되어 있습니다.');
      return;
    }
    
    try {
      print('📢 서버 알림 시도: $action - $data');
      
      // 가장 간단한 GET 요청
      final uri = Uri.parse('$_baseUrl/firebase-data').replace(
        queryParameters: {
          'notify': action,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 5));
      
      print('📤 간단 알림 전송: ${response.statusCode}');
      
    } catch (e) {
      print('📤 간단 알림 실패 (무시): $e');
      // 오류가 발생해도 앱 동작에는 영향 없음
    }
  }
} 