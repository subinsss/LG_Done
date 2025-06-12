import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AICharacterService {
  static const String baseUrl = 'http://192.168.0.12:5050'; // 실제 PC IP 주소로 변경
  // 폰에서 PC의 Flask 서버에 접근하기 위해 로컬 네트워크 IP 사용
  
  // 익명 사용자 ID (로그인 없이 사용)
  static const String anonymousUserId = 'anonymous_user';

  
  // 캐시 추가
  static List<AICharacter>? _cachedCharacters;
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // 서버 상태 확인 (최적화)
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3)); // 타임아웃 단축
      
      return response.statusCode == 200;
    } catch (e) {
      return false; // 로그 제거
    }
  }
  
  // 프롬프트로 이미지 생성 (로그 최소화)
  static Future<Map<String, dynamic>?> generateImageFromPrompt({
    required String prompt,
    String? name,
    String style = 'anime',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate/prompt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'name': name,
          'style': style,
          'is_selected': false, // 기본값으로 선택되지 않은 상태
        }),
      ).timeout(const Duration(minutes: 5)); // 타임아웃 5분으로 늘리기
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        // 캐시 무효화
        _cachedCharacters = null;
        return {
          'character_id': data['character_id'],
          'image_url': data['image_url'],
          'message': data['message']
        };
      } else {
        throw Exception(data['error'] ?? '캐릭터 생성 실패');
      }
    } catch (e) {
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

  // 캐시된 캐릭터 조회 (성능 최적화)
  static Future<List<AICharacter>> getUserCharacters() async {
    try {
      // 캐시 확인
      if (_cachedCharacters != null && 
          _lastCacheTime != null && 
          DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
        return _cachedCharacters!;
      }
      
      // 최적화된 쿼리: 최신 10개만 조회 (20개 → 10개로 감소)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('characters')
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return [];
      }
      
      final characters = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['character_id'] = doc.id;
        return AICharacter.fromJson(data);
      }).toList();
      
      // 캐시 저장
      _cachedCharacters = characters;
      _lastCacheTime = DateTime.now();
      
      return characters;
    } catch (e) {
      return [];
    }
  }
  
  // 캐릭터 삭제 (캐시 무효화 추가)
  static Future<bool> deleteCharacter(String characterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('characters')
          .doc(characterId)
          .delete();
      
      // 캐시 무효화
      _cachedCharacters = null;
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // 사용량 통계 (최적화)
  static Future<Map<String, dynamic>?> getUsageStats() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('characters')
          .where('user_id', isEqualTo: anonymousUserId)
          .where('type', isEqualTo: 'custom')
          .get();
      
      final used = querySnapshot.docs.length;
      const limit = 999999;
      
      return {
        'used': used,
        'limit': limit,
        'remaining': limit - used,
        'percentage': (used / limit) * 100,
      };
    } catch (e) {
      return null;
    }
  }
  
  // 캐시 수동 새로고침
  static void refreshCache() {
    _cachedCharacters = null;
    _lastCacheTime = null;
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
  final bool isSelected;
  
  AICharacter({
    required this.characterId,
    required this.userId,
    required this.name,
    required this.prompt,
    required this.generationType,
    required this.imageUrl,
    this.createdAt,
    required this.type,
    this.isSelected = false,
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
      isSelected: json['is_selected'] ?? false,
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
      'is_selected': isSelected,
    };
  }
} 