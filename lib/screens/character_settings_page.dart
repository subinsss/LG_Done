import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ai_character_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CharacterSettingsPage extends StatefulWidget {
  const CharacterSettingsPage({
    super.key,
  });

  @override
  State<CharacterSettingsPage> createState() => _CharacterSettingsPageState();
}

class _CharacterSettingsPageState extends State<CharacterSettingsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isGenerating = false;
  bool _isServerHealthy = false;
  List<AICharacter> _userCharacters = [];
  Map<String, dynamic>? _usageStats;
  Map<String, dynamic>? _selectedAICharacter;
  
  // 캐릭터 타입 선택을 위한 변수들
  String _selectedCharacterType = 'animal';
  String _selectedStyle = 'anime';
  
  final Map<String, String> _characterTypes = {
    'animal': '동물',
    'human': '사람',
    'fantasy': '판타지',
    'robot': '로봇/메카',
    'creature': '몬스터/크리처',
  };
  
  final Map<String, String> _styleTypes = {
    'anime': '애니메이션',
    'realistic': '사실적',
    'cartoon': '카툰',
    'chibi': '치비',
    'pixel': '픽셀아트',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    print('📱 CharacterSettingsPage 초기화 시작...');
    
    // Firebase 기본 테스트
    _testFirebaseConnection();
    
    _checkServerHealth();
    _loadSelectedCharacter();
    _loadUserCharacters();
    _loadUsageStats();
    print('📱 CharacterSettingsPage 초기화 완료!');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _testFirebaseConnection() async {
    try {
      print('🔥 Firebase 기본 연결 테스트...');
      final testDoc = await FirebaseFirestore.instance
          .collection('test')
          .limit(1)
          .get();
      print('✅ Firebase 기본 연결 성공!');
    } catch (e) {
      print('❌ Firebase 기본 연결 실패: $e');
    }
  }

  Future<void> _checkServerHealth() async {
    final isHealthy = await AICharacterService.checkServerHealth();
    setState(() {
      _isServerHealthy = isHealthy;
    });
  }

  Future<void> _loadUserCharacters() async {
    try {
      print('🔄 캐릭터 로딩 시작...');
      
      // 🧪 UI 테스트용 하드코딩된 데이터
      print('🧪 테스트 데이터 생성 중...');
      final testCharacters = [
        AICharacter(
          characterId: 'test1',
          userId: 'test',
          name: '테스트 고양이',
          prompt: '귀여운 흰색 고양이',
          generationType: 'prompt',
          imageUrl: 'https://via.placeholder.com/200x200/FF69B4/FFFFFF?text=Test+Cat',
          createdAt: DateTime.now(),
          type: 'custom',
        ),
        AICharacter(
          characterId: 'test2',
          userId: 'test',
          name: '테스트 강아지',
          prompt: '파란 눈의 강아지',
          generationType: 'prompt',
          imageUrl: 'https://via.placeholder.com/200x200/00BFFF/FFFFFF?text=Test+Dog',
          createdAt: DateTime.now(),
          type: 'custom',
        ),
      ];
      
      print('📊 테스트 캐릭터 ${testCharacters.length}개 생성');
      
      setState(() {
        _userCharacters = testCharacters;
      });
      
      print('✅ UI 업데이트 완료!');
      
      // 실제 Firebase 데이터도 시도
      try {
        final characters = await AICharacterService.getUserCharacters();
        print('📊 Firebase 로딩된 캐릭터 개수: ${characters.length}');
        
        if (characters.isNotEmpty) {
          print('🔄 Firebase 데이터로 교체...');
          setState(() {
            _userCharacters = characters;
          });
        }
      } catch (e) {
        print('❌ Firebase 로딩 실패, 테스트 데이터 유지: $e');
      }
      
    } catch (e) {
      print('❌ 캐릭터 로딩 실패: $e');
      _showErrorDialog('캐릭터 로딩 실패: $e');
    }
  }

  Future<void> _loadUsageStats() async {
    try {
      final stats = await AICharacterService.getUsageStats();
      setState(() {
        _usageStats = stats;
      });
    } catch (e) {
      print('사용량 통계 로딩 실패: $e');
    }
  }

  Future<void> _loadSelectedCharacter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final characterJson = prefs.getString('selected_character');
      
      if (characterJson != null) {
        final characterData = jsonDecode(characterJson);
        setState(() {
          _selectedAICharacter = characterData;
        });
        print('✅ 선택된 캐릭터 로딩: ${characterData['name']}');
      } else {
        print('📝 선택된 캐릭터 없음');
      }
    } catch (e) {
      print('❌ 선택된 캐릭터 로딩 실패: $e');
    }
  }

  Future<void> _generateFromPrompt() async {
    if (_promptController.text.trim().isEmpty) {
      _showErrorDialog('프롬프트를 입력해주세요');
      return;
    }

    if (!_isServerHealthy) {
      _showErrorDialog('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // 캐릭터 타입을 포함한 프롬프트 생성
      final characterTypeKorean = _characterTypes[_selectedCharacterType] ?? '동물';
      final enhancedPrompt = '$characterTypeKorean ${_promptController.text.trim()}';
      
      print('🎨 생성 요청: 타입=$characterTypeKorean, 스타일=$_selectedStyle, 프롬프트=${_promptController.text.trim()}');
      
      // 서버에서 이미지 생성 + Firestore 저장까지 모두 처리
      final result = await AICharacterService.generateImageFromPrompt(
        prompt: enhancedPrompt,
        style: _selectedStyle,
      );

      if (result != null) {
        _showSuccessDialog(result['message'] ?? '캐릭터가 성공적으로 생성되었습니다!');
        _promptController.clear();
        
        // UI 업데이트
        await _loadUserCharacters();
        await _loadUsageStats();
      } else {
        _showErrorDialog('캐릭터 생성에 실패했습니다');
      }
    } catch (e) {
      _showErrorDialog('캐릭터 생성 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateFromImage() async {
    if (!_isServerHealthy) {
      _showErrorDialog('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isGenerating = true;
      });

      // TODO: 이미지 기반 생성은 나중에 구현
      _showErrorDialog('이미지 기반 생성은 아직 구현되지 않았습니다');

    } catch (e) {
      _showErrorDialog('이미지 처리 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _deleteCharacter(AICharacter character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐릭터 삭제'),
        content: Text('${character.name}을(를) 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await AICharacterService.deleteCharacter(character.characterId);
      if (success) {
        _showSuccessDialog('캐릭터가 삭제되었습니다');
        await _loadUserCharacters();
        await _loadUsageStats();
      } else {
        _showErrorDialog('캐릭터 삭제에 실패했습니다');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성공'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerStatusIndicator() {
    return Row(
      children: [
        Icon(
          _isServerHealthy ? Icons.circle : Icons.error,
          color: _isServerHealthy ? Colors.green : Colors.red,
          size: 12,
        ),
        const SizedBox(width: 4),
        Text(
          _isServerHealthy ? 'AI 서버 연결됨' : 'AI 서버 연결 안됨',
          style: TextStyle(
            fontSize: 12,
            color: _isServerHealthy ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageIndicator() {
    if (_usageStats == null) return const SizedBox.shrink();

    final used = _usageStats!['used'] ?? 0;
    final limit = _usageStats!['limit'] ?? 50;
    final percentage = _usageStats!['percentage'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI 캐릭터 사용량',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '$used / $limit',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 80 ? Colors.red : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 캐릭터'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '새로 만들기'),
            Tab(text: '내 캐릭터'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAIGenerationTab(),
          _buildMyCharactersTab(),
        ],
      ),
    );
  }

  Widget _buildAIGenerationTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServerStatusIndicator(),
          const SizedBox(height: 12),
          _buildUsageIndicator(),
          const SizedBox(height: 24),
          Text(
            'AI로 캐릭터 생성하기',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          // 캐릭터 타입 및 스타일 선택
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, size: 20, color: Colors.purple.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        '캐릭터 설정',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 캐릭터 타입 선택
                  const Text('캐릭터 타입', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCharacterType,
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCharacterType = newValue;
                            });
                          }
                        },
                        items: _characterTypes.entries.map<DropdownMenuItem<String>>((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 스타일 선택
                  const Text('아트 스타일', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStyle,
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedStyle = newValue;
                            });
                          }
                        },
                        items: _styleTypes.entries.map<DropdownMenuItem<String>>((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 프롬프트 입력
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        '세부 설명',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '예: 파란 눈을 가진 귀여운 고양이\n흰색 털, 분홍색 코, 작은 체구',
                      border: const OutlineInputBorder(),
                      helperText: '위에서 선택한 타입에 맞는 세부 특징을 입력하세요',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating || !_isServerHealthy
                          ? null
                          : _generateFromPrompt,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isGenerating ? '생성 중...' : '캐릭터 생성하기'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCharactersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '내 캐릭터',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () async {
                  print('🔄 새로고침 버튼 클릭됨!');
                  
                  // 직접적인 Firebase 테스트
                  try {
                    print('🔥 직접 Firebase 테스트 시작...');
                    final snapshot = await FirebaseFirestore.instance
                        .collection('characters')
                        .get();
                    print('📊 characters 컬렉션 전체 문서 수: ${snapshot.docs.length}');
                    
                    if (snapshot.docs.isNotEmpty) {
                      final firstDoc = snapshot.docs.first;
                      print('📄 첫 번째 문서 ID: ${firstDoc.id}');
                      print('📄 첫 번째 문서 데이터: ${firstDoc.data()}');
                    }
                  } catch (e) {
                    print('❌ 직접 Firebase 테스트 실패: $e');
                  }
                  
                  _loadUserCharacters();
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildUsageIndicator(),
          const SizedBox(height: 16),
          Expanded(
            child: _userCharacters.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '아직 생성된 캐릭터가 없습니다',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _userCharacters.length,
                    itemBuilder: (context, index) {
                      final character = _userCharacters[index];
                      
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: character.characterId == _selectedAICharacter?['character_id'] ? 3 : 1,
                        color: character.characterId == _selectedAICharacter?['character_id'] 
                            ? Colors.blue.shade50 
                            : Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    child: _buildCharacterImage(character.imageUrl),
                                  ),
                                  // 선택됨 표시
                                  if (character.characterId == _selectedAICharacter?['character_id'])
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check, color: Colors.white, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              '선택됨',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: PopupMenuButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.more_vert,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          child: const Row(
                                            children: [
                                              Icon(Icons.delete, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('삭제'),
                                            ],
                                          ),
                                          onTap: () => _deleteCharacter(character),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    character.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    character.prompt,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: character.characterId == _selectedAICharacter?['character_id']
                                          ? null // 이미 선택된 캐릭터는 비활성화
                                          : () => _applyCharacter(character),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        backgroundColor: character.characterId == _selectedAICharacter?['character_id']
                                            ? Colors.grey.shade300
                                            : Colors.blue.shade600,
                                        foregroundColor: character.characterId == _selectedAICharacter?['character_id']
                                            ? Colors.grey.shade600
                                            : Colors.white,
                                      ),
                                      child: Text(
                                        character.characterId == _selectedAICharacter?['character_id']
                                            ? '현재 사용 중'
                                            : '선택하기',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterImage(String imageUrl) {
    try {
      // Base64 이미지인지 확인
      if (imageUrl.startsWith('data:image/')) {
        // Base64 데이터 추출
        final base64String = imageUrl.split(',')[1];
        final Uint8List bytes = base64Decode(base64String);
        
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Base64 이미지 로딩 오류: $error');
            return Container(
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.error,
                color: Colors.grey,
              ),
            );
          },
        );
      } else {
        // 일반 네트워크 이미지
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('네트워크 이미지 로딩 오류: $error');
            return Container(
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.error,
                color: Colors.grey,
              ),
            );
          },
        );
      }
    } catch (e) {
      print('이미지 처리 오류: $e');
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.error,
          color: Colors.grey,
        ),
      );
    }
  }

  Future<void> _applyCharacter(AICharacter character) async {
    try {
      print('🎯 캐릭터 선택: ${character.name}');
      print('📝 character_id: ${character.characterId}');
      
      // 🔥 Firestore에서 직접 is_selected 업데이트
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      // 1. 모든 캐릭터의 is_selected를 false로 설정
      final allCharacters = await firestore.collection('characters').get();
      for (var doc in allCharacters.docs) {
        batch.update(doc.reference, {'is_selected': false});
      }
      
      // 2. 선택한 캐릭터만 is_selected를 true로 설정
      final selectedDoc = firestore.collection('characters').doc(character.characterId);
      batch.update(selectedDoc, {'is_selected': true});
      
      // 3. 배치 커밋
      await batch.commit();
      
      print('✅ Firestore에서 캐릭터 선택 완료: ${character.name}');
      
      // SharedPreferences에도 저장 (백업용)
      final prefs = await SharedPreferences.getInstance();
      final characterData = {
        'character_id': character.characterId,
        'name': character.name,
        'image_url': character.imageUrl,
        'prompt': character.prompt,
        'type': 'ai_generated',
        'is_selected': true,
      };
      
      await prefs.setString('selected_character', jsonEncode(characterData));
      print('✅ 로컬 저장도 완료');
      
      // 선택된 캐릭터 정보 업데이트
      setState(() {
        _selectedAICharacter = characterData;
      });
      
      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${character.name}을(를) 선택했습니다!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // 홈화면으로 돌아가기 (실시간 스트림이 자동으로 업데이트)
      Navigator.pop(context, true);
      
    } catch (e) {
      print('❌ 캐릭터 적용 오류: $e');
      print('❌ 오류 타입: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캐릭터 적용에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 