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

  Future<void> _generateFromPrompt() async {
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
            Tab(text: '새로 만들기'),
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
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                character.imageUrl,
                fit: BoxFit.cover,
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
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  character.prompt,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
            _buildSectionTitle('캐릭터 타입'),
            const SizedBox(height: 12),
            _buildCharacterTypeSelector(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('스타일'),
            const SizedBox(height: 12),
            _buildStyleSelector(),
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
            
            if (_usageStats != null) ...[
              const SizedBox(height: 24),
              Text(
                '오늘 생성 가능: ${_usageStats!['remaining_today'] ?? 0}회',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
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

  Widget _buildCharacterTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _characterTypes.entries.map((entry) {
        final isSelected = _selectedCharacterType == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedCharacterType = entry.key;
              });
            }
          },
          backgroundColor: Colors.grey[50],
          selectedColor: Colors.black,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStyleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _styleTypes.entries.map((entry) {
        final isSelected = _selectedStyle == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedStyle = entry.key;
              });
            }
          },
          backgroundColor: Colors.grey[50],
          selectedColor: Colors.black,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
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