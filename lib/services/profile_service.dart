import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'user_profiles';
  static const String _defaultUserId = 'default_user'; // 시연용 고정 ID

  // 프로필 정보 저장
  static Future<bool> saveProfile({
    required String name,
    required String email,
    String? phone,
    String? profileImageUrl,
  }) async {
    try {
      final profileData = {
        'name': name,
        'email': email,
        'phone': phone ?? '',
        'profileImageUrl': profileImageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_collectionName)
          .doc(_defaultUserId)
          .set(profileData, SetOptions(merge: true));
      
      print('✅ 프로필 저장 성공');
      return true;
    } catch (e) {
      print('❌ 프로필 저장 오류: $e');
      return false;
    }
  }

  // 프로필 정보 불러오기
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(_defaultUserId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        
        DateTime? birthDate;
        if (data['birthDate'] != null) {
          try {
            birthDate = DateTime.parse(data['birthDate']);
          } catch (e) {
            birthDate = null;
          }
        }
        
        return {
          'name': data['name'] ?? '사용자',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'profileImageUrl': data['profileImageUrl'] ?? '',
        };
      } else {
        // 기본 프로필 생성
        await _createDefaultProfile();
        return await getProfile(); // 재귀 호출로 생성된 프로필 반환
      }
    } catch (e) {
      print('❌ 프로필 불러오기 오류: $e');
      return {
        'name': '사용자',
        'email': '',
        'phone': '',
        'profileImageUrl': '',
      };
    }
  }

  // 기본 프로필 생성 (시연용)
  static Future<void> _createDefaultProfile() async {
    await saveProfile(
      name: '김철수',
      email: 'user@example.com',
      phone: '010-1234-5678',
    );
    print('✅ 기본 프로필 생성 완료');
  }

  // 사용자 이름만 불러오기
  static Future<String> getUserName() async {
    final profile = await getProfile();
    return profile['name'] as String;
  }

  // 프로필 이미지 URL만 불러오기
  static Future<String> getProfileImageUrl() async {
    final profile = await getProfile();
    return profile['profileImageUrl'] as String;
  }

  // 프로필 실시간 스트림 (실시간 업데이트용)
  static Stream<Map<String, dynamic>> getProfileStream() {
    try {
      return _firestore
          .collection(_collectionName)
          .doc(_defaultUserId)
          .snapshots()
          .handleError((error) {
            print('❌ 프로필 스트림 오류: $error');
            throw error;
          })
          .map((doc) {
        if (doc.exists) {
          final data = doc.data()!;
          
          return {
            'name': data['name'] ?? '사용자',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'profileImageUrl': data['profileImageUrl'] ?? '',
          };
        } else {
          return {
            'name': '사용자',
            'email': '',
            'phone': '',
            'profileImageUrl': '',
          };
        }
      });
    } catch (e) {
      print('❌ 프로필 스트림 초기화 오류: $e');
      // 에러 발생 시 기본값 스트림 반환
      return Stream.value({
        'name': '사용자',
        'email': '',
        'phone': '',
        'profileImageUrl': '',
      });
    }
  }
} 