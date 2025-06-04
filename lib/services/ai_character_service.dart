import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AICharacterService {
  static const String baseUrl = 'http://localhost:5050'; // 5050 포트로 변경
  // 프로덕션에서는 실제 서버 URL로 변경 필요
  
  // 익명 사용자 ID (로그인 없이 사용)
  static const String anonymousUserId = 'anonymous_user';

  
  // 서버 상태 확인
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('서버 연결 실패: $e');
      return false;
    }
  }
  
  // 프롬프트로 이미지 생성 (서버에서 이미지 생성 + Firebase 저장까지 처리)
  static Future<Map<String, dynamic>?> generateImageFromPrompt({
    required String prompt,
    String style = 'anime',
  }) async {
    try {
      print('🎨 이미지 생성 요청...');
      print('📝 프롬프트: $prompt');
      print('🎭 스타일: $style');
      print('🌐 서버 URL: $baseUrl/generate/prompt');
      
      final response = await http.post(
        Uri.parse('$baseUrl/generate/prompt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'style': style,
        }),
      ).timeout(const Duration(seconds: 90));
      
      print('📡 서버 응답 상태 코드: ${response.statusCode}');
      
      final data = jsonDecode(response.body);
      print('📊 서버 응답 데이터: $data');
      
      if (response.statusCode == 200) {
        print('✅ 캐릭터 생성 및 저장 완료!');
        return {
          'character_id': data['character_id'],
          'image_url': data['image_url'],
          'message': data['message']
        };
      } else {
        print('❌ 생성 실패: ${response.statusCode}');
        throw Exception(data['error'] ?? '캐릭터 생성에 실패했습니다');
      }
    } catch (e) {
      print('❌ 캐릭터 생성 오류: $e');
      rethrow;
    }
  }
  
  // 디버그: Firebase에 저장된 모든 캐릭터 조회
  static Future<void> debugPrintAllCharacters() async {
    try {
      print('🔍 Firebase 캐릭터 디버그 조회 시작...');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('characters')
          .get();
      
      print('📊 총 캐릭터 개수: ${querySnapshot.docs.length}');
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        print('📄 캐릭터 ID: ${doc.id}');
        print('   - user_id: ${data['user_id']}');
        print('   - name: ${data['name']}');
        print('   - prompt: ${data['prompt']}');
        print('   - image_url: ${data['image_url']}');
        print('   - created_at: ${data['created_at']}');
        print('   ---');
      }
      
      // 익명 사용자 캐릭터만 조회
      final anonymousQuery = await FirebaseFirestore.instance
          .collection('characters')
          .where('user_id', isEqualTo: anonymousUserId)
          .get();
      
      print('👤 익명 사용자 캐릭터 개수: ${anonymousQuery.docs.length}');
      
    } catch (e) {
      print('❌ 디버그 조회 오류: $e');
    }
  }

  // 사용자의 모든 캐릭터 조회 (Flutter에서 직접 Firebase 조회)
  static Future<List<AICharacter>> getUserCharacters() async {
    try {
      print('🔄 캐릭터 조회 시작...');
      
      // Firebase 연결 테스트
      try {
        final testQuery = await FirebaseFirestore.instance
            .collection('characters')
            .limit(1)
            .get();
        print('✅ Firebase 연결 성공! 테스트 쿼리 결과: ${testQuery.docs.length}개 문서');
      } catch (e) {
        print('❌ Firebase 연결 실패: $e');
        throw Exception('Firebase에 연결할 수 없습니다: $e');
      }
      
      // 임시로 모든 캐릭터 조회 (user_id 필터 제거)
      print('📊 모든 캐릭터 조회 시작...');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('characters')
          .orderBy('created_at', descending: true)
          .get();
      
      print('✅ 조회 완료! 결과: ${querySnapshot.docs.length}개');
      
      if (querySnapshot.docs.isEmpty) {
        print('❌ 캐릭터가 아예 없습니다!');
        return [];
      }
      
      // 각 문서의 user_id 확인
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        print('📄 문서 ${doc.id}: user_id = "${data['user_id']}"');
      }
      
      final characters = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['character_id'] = doc.id;
        print('📄 캐릭터 변환: ${data['name']} (${doc.id})');
        return AICharacter.fromJson(data);
      }).toList();
      
      print('🎉 최종 반환: ${characters.length}개 캐릭터');
      return characters;
    } catch (e) {
      print('❌❌❌ 캐릭터 조회 치명적 오류: $e');
      print('오류 타입: ${e.runtimeType}');
      print('스택 트레이스: ${StackTrace.current}');
      return [];
    }
  }
  
  // 캐릭터 삭제 (Flutter에서 직접 Firebase 삭제)
  static Future<bool> deleteCharacter(String characterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('characters')
          .doc(characterId)
          .delete();
      
      return true;
    } catch (e) {
      print('캐릭터 삭제 오류: $e');
      return false;
    }
  }
  
  // 사용량 통계 (Flutter에서 직접 계산)
  static Future<Map<String, dynamic>?> getUsageStats() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('characters')
          .where('user_id', isEqualTo: anonymousUserId) // 익명 사용자 ID로 조회
          .where('type', isEqualTo: 'custom')
          .get();
      
      final used = querySnapshot.docs.length;
      const limit = 999999; // 사실상 무제한
      
      return {
        'used': used,
        'limit': limit,
        'remaining': limit - used,
        'percentage': (used / limit) * 100,
      };
    } catch (e) {
      print('사용량 조회 오류: $e');
      return null;
    }
  }
}

// AI 캐릭터 데이터 모델 (간단하게)
class AICharacter {
  final String characterId;
  final String userId;
  final String name;
  final String prompt;
  final String generationType;
  final String imageUrl; // 단일 이미지 URL
  final DateTime? createdAt;
  final String type;
  
  AICharacter({
    required this.characterId,
    required this.userId,
    required this.name,
    required this.prompt,
    required this.generationType,
    required this.imageUrl,
    this.createdAt,
    required this.type,
  });
  
  factory AICharacter.fromJson(Map<String, dynamic> json) {
    return AICharacter(
      characterId: json['character_id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      prompt: json['prompt'] ?? '',
      generationType: json['generation_type'] ?? '',
      imageUrl: json['image_url'] ?? '',
      createdAt: json['created_at'] != null 
          ? (json['created_at'] as Timestamp).toDate()
          : null,
      type: json['type'] ?? 'custom',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'character_id': characterId,
      'user_id': userId,
      'name': name,
      'prompt': prompt,
      'generation_type': generationType,
      'image_url': imageUrl,
      'created_at': createdAt,
      'type': type,
    };
  }
} 