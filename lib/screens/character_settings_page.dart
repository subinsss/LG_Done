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
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isGenerating = false;
  bool _isServerHealthy = false;
  List<AICharacter> _userCharacters = [];
  Map<String, dynamic>? _usageStats;
  Map<String, dynamic>? _selectedAICharacter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 최적화된 초기화 (로그 제거)
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 병렬 로딩으로 성능 개선
    await Future.wait([
      _checkServerHealth(),
      _loadUserCharacters(),
      _loadUsageStats(),
      _loadSelectedCharacter(),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkServerHealth() async {
    final isHealthy = await AICharacterService.checkServerHealth();
    if (mounted) {
      setState(() {
        _isServerHealthy = isHealthy;
      });
    }
  }

  Future<void> _loadUserCharacters() async {
    try {
      final characters = await AICharacterService.getUserCharacters();
      
      if (mounted) {
        setState(() {
          _userCharacters = characters;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('캐릭터 로딩 실패: $e');
      }
    }
  }

  Future<void> _loadUsageStats() async {
    try {
      final stats = await AICharacterService.getUsageStats();
      if (mounted) {
        setState(() {
          _usageStats = stats;
        });
      }
    } catch (e) {
      // 로그 제거 - 통계는 선택사항
    }
  }

  Future<void> _loadSelectedCharacter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final characterJson = prefs.getString('selected_character');
      
      if (characterJson != null) {
        final characterData = jsonDecode(characterJson);
        if (mounted) {
          setState(() {
            _selectedAICharacter = characterData;
          });
        }
      }
    } catch (e) {
      // 로그 제거 - 선택된 캐릭터는 선택사항
    }
  }

  Future<void> _selectCharacter(AICharacter character) async {
    try {
      // 1. 먼저 모든 캐릭터의 is_selected를 false로 변경
      final allCharacters = await FirebaseFirestore.instance
          .collection('characters')
          .where('is_selected', isEqualTo: true)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in allCharacters.docs) {
        batch.update(doc.reference, {'is_selected': false});
      }
      
      // 2. 선택된 캐릭터의 is_selected를 true로 변경
      final selectedCharacterRef = FirebaseFirestore.instance
          .collection('characters')
          .doc(character.characterId);
      
      batch.update(selectedCharacterRef, {'is_selected': true});
      
      // 배치 커밋
      await batch.commit();
      
      final characterData = {
        'character_id': character.characterId,
        'name': character.name,
        'prompt': character.prompt,
        'image_url': character.imageUrl,
        'selected_at': DateTime.now().toIso8601String(),
      };

      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_character', jsonEncode(characterData));

      // Firestore users 컬렉션에도 저장 (홈화면 실시간 업데이트용)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc('anonymous_user')
            .set({
          'selected_character': characterData,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        // Firestore 저장 실패는 무시
      }

      // UI 업데이트
      if (mounted) {
        setState(() {
          _selectedAICharacter = characterData;
        });
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${character.name} 캐릭터가 선택되었습니다!'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // 홈화면으로 돌아가기
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캐릭터 선택에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(AICharacter character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text(
              '캐릭터 삭제',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '\'${character.name}\' 캐릭터를 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCharacter(character);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '삭제',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _generateFromPrompt() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorDialog('캐릭터 이름을 입력해주세요');
      return;
    }
    
    if (_promptController.text.trim().isEmpty) {
      _showErrorDialog('프롬프트를 입력해주세요');
      return;
    }

    if (!_isServerHealthy) {
      _showErrorDialog('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    if (mounted) {
      setState(() {
        _isGenerating = true;
      });
    }

    try {
      final prompt = _promptController.text.trim();
      
      print('🎨 생성 요청: 프롬프트=$prompt');
      
      // 서버에서 이미지 생성 + Firestore 저장까지 모두 처리
      final result = await AICharacterService.generateImageFromPrompt(
        prompt: prompt,
        name: _nameController.text.trim(),
        style: 'anime', // 기본 스타일을 anime로 고정
      );

      if (result != null) {
        // 생성된 캐릭터의 name 필드를 확실히 업데이트
        try {
          final characterId = result['character_id'];
          if (characterId != null) {
            await FirebaseFirestore.instance
                .collection('characters')
                .doc(characterId)
                .update({
              'name': _nameController.text.trim(),
            });
            print('✅ 캐릭터 이름 업데이트 완료: ${_nameController.text.trim()}');
          }
        } catch (e) {
          print('❌ 캐릭터 이름 업데이트 실패: $e');
        }
        
        _showSuccessDialog(result['message'] ?? '캐릭터가 성공적으로 생성되었습니다!');
        _promptController.clear();
        _nameController.clear();
        
        // UI 업데이트
        await _loadUserCharacters();
        await _loadUsageStats();
      } else {
        _showErrorDialog('캐릭터 생성에 실패했습니다');
      }
    } catch (e) {
      _showErrorDialog('캐릭터 생성 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
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

      if (mounted) {
        setState(() {
          _isGenerating = true;
        });
      }

      // TODO: 이미지 기반 생성은 나중에 구현
      _showErrorDialog('이미지 기반 생성은 아직 구현되지 않았습니다');

    } catch (e) {
      _showErrorDialog('이미지 처리 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _deleteCharacter(AICharacter character) async {
    try {
      // 삭제되는 캐릭터가 선택된 캐릭터인지 확인
      final isSelectedCharacter = character.isSelected || 
          _selectedAICharacter?['character_id'] == character.characterId;
      
      final success = await AICharacterService.deleteCharacter(character.characterId);
      
      if (success) {
        // 선택된 캐릭터가 삭제된 경우 선택 해제
        if (isSelectedCharacter) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('selected_character');
          
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc('anonymous_user')
                .update({
              'selected_character': FieldValue.delete(),
            });
          } catch (e) {
            // Firestore 업데이트 실패는 무시
          }
          
          setState(() {
            _selectedAICharacter = null;
          });
        }
        
        // 캐릭터 목록 새로고침
        await _loadUserCharacters();
        await _loadUsageStats();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${character.name} 캐릭터가 삭제되었습니다'),
              backgroundColor: Colors.black,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('캐릭터 삭제에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캐릭터 삭제 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('AI 캐릭터', 
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          )
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '내 캐릭터'),
            Tab(text: '캐릭터 만들기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCharactersTab(),
          _buildCreateCharacterTab(),
        ],
      ),
    );
  }

  Widget _buildMyCharactersTab() {
    return Container(
      color: Colors.white,
      child: _userCharacters.isEmpty
          ? Center(
              child: Text(
                '생성된 캐릭터가 없습니다\n새로운 캐릭터를 만들어보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _userCharacters.length,
              itemBuilder: (context, index) {
                final character = _userCharacters[index];
                return _buildCharacterCard(character);
              },
            ),
    );
  }

  Widget _buildCharacterCard(AICharacter character) {
    final isSelected = _selectedAICharacter?['character_id'] == character.characterId;
    
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.black : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: _buildCharacterImage(character),
                  ),
                ),
                // 삭제 버튼 (우상단)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showDeleteConfirmDialog(character),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name.isEmpty ? '이름 없는 캐릭터' : character.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // 선택 버튼 추가
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _selectCharacter(character);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.black : Colors.white,
                      foregroundColor: isSelected ? Colors.white : Colors.black,
                      side: BorderSide(
                        color: Colors.black,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    child: Text(
                      isSelected ? '✓ 선택됨' : '선택하기',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 캐릭터 이미지 빌더 (Base64/네트워크 이미지 구분 처리)
  Widget _buildCharacterImage(AICharacter character) {
    final imageUrl = character.imageUrl;
    
    // Base64 이미지인지 확인
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',')[1];
        final Uint8List bytes = base64Decode(base64String);
        
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 400, // 메모리 사용량 최적화
          cacheHeight: 400,
          errorBuilder: (context, error, stackTrace) {
            print('Base64 이미지 로딩 오류: $error');
            return _buildErrorImage();
          },
        );
      } catch (e) {
        print('Base64 디코딩 오류: $e');
        return _buildErrorImage();
      }
    } else {
      // 네트워크 이미지
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 400, // 메모리 사용량 최적화
        cacheHeight: 400,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: Colors.black,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('네트워크 이미지 로딩 오류: $error');
          return _buildErrorImage();
        },
      );
    }
  }

  // 에러 시 표시할 기본 이미지
  Widget _buildErrorImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            '이미지 로딩 실패',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCharacterTab() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('캐릭터 이름'),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: '캐릭터 이름을 입력해주세요',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
              ),
              maxLength: 20,
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle('프롬프트'),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: '원하는 캐릭터를 설명해주세요',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateFromPrompt,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isGenerating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '캐릭터 생성하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }



  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('오류', style: TextStyle(color: Colors.black)),
        content: Text(message, style: TextStyle(color: Colors.grey[800])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('성공', style: TextStyle(color: Colors.black)),
        content: Text(message, style: TextStyle(color: Colors.grey[800])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Colors.black)),
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
        color: Colors.pink.shade50,
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
              percentage > 80 ? Colors.red : Colors.pink,
            ),
          ),
        ],
      ),
    );
  }
} 