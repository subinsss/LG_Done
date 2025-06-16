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
          // 현재 선택된 캐릭터 ID 확인
          final selectedCharacterId = _selectedAICharacter?['character_id'];
          
          // 각 캐릭터의 선택 상태 업데이트
          _userCharacters = characters.map((character) {
            if (selectedCharacterId != null && character.characterId == selectedCharacterId) {
              // 선택된 캐릭터인 경우 isSelected를 true로 설정
              return AICharacter(
                characterId: character.characterId,
                userId: character.userId,
                name: character.name,
                prompt: character.prompt,
                generationType: character.generationType,
                imageUrl: character.imageUrl,
                type: character.type,
                isSelected: true,
              );
            } else {
              // 선택되지 않은 캐릭터인 경우 isSelected를 false로 설정
              return AICharacter(
                characterId: character.characterId,
                userId: character.userId,
                name: character.name,
                prompt: character.prompt,
                generationType: character.generationType,
                imageUrl: character.imageUrl,
                type: character.type,
                isSelected: false,
              );
            }
          }).toList();
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
      final batch = FirebaseFirestore.instance.batch();
      
      final allCharacters = await FirebaseFirestore.instance
          .collection('characters')
          .where('is_selected', isEqualTo: true)
          .get();
      
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

      // Firestore users 컬렉션에도 저장
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
          
          // 모든 캐릭터의 선택 상태 업데이트
          for (int i = 0; i < _userCharacters.length; i++) {
            final currentCharacter = _userCharacters[i];
            _userCharacters[i] = AICharacter(
              characterId: currentCharacter.characterId,
              userId: currentCharacter.userId,
              name: currentCharacter.name,
              prompt: currentCharacter.prompt,
              generationType: currentCharacter.generationType,
              imageUrl: currentCharacter.imageUrl,
              type: currentCharacter.type,
              isSelected: currentCharacter.characterId == character.characterId,
            );
          }
        });
        
        // 선택 완료 메시지 표시 후 홈 화면으로 이동
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${character.name} 캐릭터가 선택되었습니다'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 1),
          ),
        );

        // 잠시 후 홈 화면으로 이동
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pop(context);
        });
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

  void _showEditDialog(AICharacter character) {
    final TextEditingController nameController = TextEditingController(text: character.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue.shade400),
            const SizedBox(width: 8),
            const Text(
              '캐릭터 수정',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '이름',
            hintText: '캐릭터 이름을 입력하세요',
          ),
          autofocus: true,
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
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('이름을 입력해주세요'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _updateCharacter(character, newName, character.prompt);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '저장',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCharacter(AICharacter character, String newName, String newPrompt) async {
    try {
      // Firestore에서 캐릭터 정보 업데이트
      await FirebaseFirestore.instance
          .collection('characters')
          .doc(character.characterId)
          .update({
        'name': newName,
        'prompt': newPrompt,
      });

      // UI 즉시 업데이트를 위해 현재 캐릭터 목록 수정
      if (mounted) {
        setState(() {
          final index = _userCharacters.indexWhere((c) => c.characterId == character.characterId);
          if (index != -1) {
            _userCharacters[index] = AICharacter(
              characterId: character.characterId,
              userId: character.userId,
              name: newName,
              prompt: newPrompt,
              generationType: character.generationType,
              imageUrl: character.imageUrl,
              type: character.type,
              isSelected: character.isSelected,
            );
          }
        });
      }

      // 선택된 캐릭터인 경우 SharedPreferences와 users 컬렉션도 업데이트
      if (character.isSelected || 
          _selectedAICharacter?['character_id'] == character.characterId) {
        final characterData = {
          ..._selectedAICharacter!,
          'name': newName,
          'prompt': newPrompt,
          'updated_at': DateTime.now().toIso8601String(),
        };

        // SharedPreferences 업데이트
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_character', jsonEncode(characterData));

        // Firestore users 컬렉션 업데이트
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

        setState(() {
          _selectedAICharacter = characterData;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('캐릭터 정보가 수정되었습니다'),
            backgroundColor: Colors.black,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수정에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                childAspectRatio: 0.65,
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
    final isSelected = character.isSelected || 
        _selectedAICharacter?['character_id'] == character.characterId;

    // base64 이미지 처리
    Widget buildImage() {
      if (character.imageUrl.startsWith('data:image')) {
        try {
          // base64 문자열 추출
          final base64String = character.imageUrl.split(',')[1];
          final Uint8List bytes = base64Decode(base64String);
          
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('이미지 로딩 오류: $error');
              return Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.error_outline, size: 48),
              );
            },
          );
        } catch (e) {
          print('base64 이미지 처리 오류: $e');
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.error_outline, size: 48),
          );
        }
      } else {
        // 일반 URL 이미지
        return Image.network(
          character.imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('이미지 로딩 오류: $error');
            return Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.error_outline, size: 48),
            );
          },
        );
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: buildImage(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? Colors.blue.shade400 : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          character.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        color: Colors.white,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditDialog(character);
                          } else if (value == 'delete') {
                            _showDeleteConfirmDialog(character);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.grey[800]),
                                const SizedBox(width: 8),
                                Text(
                                  '수정',
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.grey[800]),
                                const SizedBox(width: 8),
                                Text(
                                  '삭제',
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  if (!isSelected) {
                    _selectCharacter(character);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue.shade400 : Colors.white,
                  foregroundColor: isSelected ? Colors.white : Colors.grey.shade600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                    ),
                  ),
                ),
                child: Text(
                  isSelected ? '선택됨' : '선택하기',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
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