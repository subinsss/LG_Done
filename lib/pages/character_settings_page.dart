import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CharacterSettingsPage extends StatefulWidget {
  final String currentCharacter;
  final Map<String, Map<String, dynamic>> availableCharacters;
  final Function(String) onCharacterSelected;
  final bool isPremiumUser; // 프리미엄 사용자 여부

  const CharacterSettingsPage({
    super.key,
    required this.currentCharacter,
    required this.availableCharacters,
    required this.onCharacterSelected,
    this.isPremiumUser = false, // 기본값은 무료 사용자
  });

  @override
  State<CharacterSettingsPage> createState() => _CharacterSettingsPageState();
}

class _CharacterSettingsPageState extends State<CharacterSettingsPage> with TickerProviderStateMixin {
  late String _selectedCharacter;
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();
  File? _uploadedImage;
  bool _isGenerating = false;
  
  // 사용자별 캐릭터 제한
  int get _maxCustomCharacters => widget.isPremiumUser ? 50 : 0;
  int get _currentCustomCharacterCount => widget.availableCharacters.values
      .where((char) => char['type'] == 'custom').length;

  @override
  void initState() {
    super.initState();
    _selectedCharacter = widget.currentCharacter;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              '캐릭터 설정',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Text(
              widget.isPremiumUser ? 'Premium' : 'Free',
              style: TextStyle(
                color: widget.isPremiumUser ? Colors.yellow.shade200 : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.pink.shade400,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _selectedCharacter != widget.currentCharacter
                ? () {
                    widget.onCharacterSelected(_selectedCharacter);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.availableCharacters[_selectedCharacter]!['name']} 캐릭터로 변경되었습니다!',
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.pink.shade400,
                      ),
                    );
                  }
                : null,
            child: Text(
              '적용',
              style: TextStyle(
                color: _selectedCharacter != widget.currentCharacter 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '기본'),
            Tab(text: 'AI 생성'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 기본 캐릭터 탭
          SingleChildScrollView(
            child: Column(
              children: [
                // 현재 선택된 캐릭터 미리보기
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.pink.shade50,
                          border: Border.all(
                            color: Colors.pink.shade200,
                            width: 3,
                          ),
                        ),
                        child: _buildCharacterPreview(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.availableCharacters[_selectedCharacter]!['name'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 캐릭터 선택 옵션
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '기본 캐릭터',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCharacterGrid(
                        widget.availableCharacters.entries
                            .where((entry) => entry.value['type'] == 'emoji')
                            .toMap(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // AI 캐릭터 생성 탭
          if (widget.isPremiumUser)
            SingleChildScrollView(
              child: Column(
                children: [
                  // 캐릭터 미리보기
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            color: Colors.pink.shade50,
                            border: Border.all(
                              color: Colors.pink.shade200,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.auto_awesome,
                              size: 80,
                              color: Colors.pink.shade200,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '새로운 캐릭터 생성',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 간단한 프롬프트 입력
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _promptController,
                          decoration: InputDecoration(
                            hintText: '원하는 캐릭터를 간단히 설명해주세요',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.edit),
                            suffixIcon: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.auto_awesome),
                                  onPressed: () {
                                    if (_promptController.text.isNotEmpty) {
                                      _generateFromPrompt();
                                    }
                                  },
                                ),
                          ),
                          enabled: !_isGenerating,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _generateFromPrompt();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '예시: 귀여운 고양이, 파란 머리 마법사, 웃는 로봇',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Premium 사용자만 이용 가능합니다',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacterPreview() {
    final characterData = widget.availableCharacters[_selectedCharacter]!;
    
    if (characterData['type'] == 'emoji') {
      return Center(
        child: Text(
          characterData['normal'],
          style: const TextStyle(fontSize: 100),
        ),
      );
    } else if (characterData['type'] == 'custom' && characterData['imageUrl'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(97),
        child: Image.network(
          characterData['imageUrl'],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person,
            size: 80,
            color: Colors.grey.shade400,
          ),
        ),
      );
    } else {
      return Icon(
        Icons.person,
        size: 80,
        color: Colors.grey.shade400,
      );
    }
  }

  Widget _buildCharacterGrid(Map<String, Map<String, dynamic>> characters, {bool showDeleteButton = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final characterId = characters.keys.elementAt(index);
        final characterData = characters[characterId]!;
        final isSelected = characterId == _selectedCharacter;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCharacter = characterId;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? Colors.pink.shade400 
                    : Colors.grey.shade200,
                width: isSelected ? 3 : 1,
              ),
              color: isSelected 
                  ? Colors.pink.shade50 
                  : Colors.white,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                else
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 캐릭터 이미지/이모지
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        color: isSelected 
                            ? Colors.white 
                            : Colors.grey.shade50,
                      ),
                      child: characterData['type'] == 'emoji'
                          ? Center(
                              child: Text(
                                characterData['normal'],
                                style: const TextStyle(fontSize: 40),
                              ),
                            )
                          : characterData['type'] == 'custom'
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.network(
                                    characterData['imageUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 캐릭터 이름
                    Text(
                      characterData['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? Colors.pink.shade600 
                            : Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 선택 표시
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, 
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade400,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Text(
                          '선택됨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, 
                          vertical: 6,
                        ),
                        child: Text(
                          '선택하기',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                
                // 삭제 버튼 (커스텀 캐릭터만)
                if (showDeleteButton && characterData['type'] == 'custom')
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _deleteCustomCharacter(characterId),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCustomCharactersPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            '커스텀 캐릭터가 없습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'AI 생성 탭에서 나만의 캐릭터를\n만들어보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI 생성하러 가기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // AI 생성 관련 메서드들
  Future<void> _generateFromPrompt() async {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프롬프트를 입력해주세요')),
      );
      return;
    }

    if (_currentCustomCharacterCount >= _maxCustomCharacters) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 생성 개수에 도달했습니다')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isGenerating = true;
      });
    }

    try {
      // AI 서버가 연결되지 않았으므로 기능 안내
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 캐릭터 생성은 하단 네비게이션의 "캐릭터" 탭을 이용해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _generateFromImage() async {
    if (_uploadedImage == null) return;

    if (_currentCustomCharacterCount >= _maxCustomCharacters) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 생성 개수에 도달했습니다')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isGenerating = true;
      });
    }

    try {
      // AI 서버가 연결되지 않았으므로 기능 안내
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 캐릭터 생성은 하단 네비게이션의 "캐릭터" 탭을 이용해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      
      if (mounted) {
        setState(() {
          _uploadedImage = null;
        });
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        _uploadedImage = File(image.path);
      });
    }
  }

  void _deleteCustomCharacter(String characterId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐릭터 삭제'),
        content: const Text('이 캐릭터를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 캐릭터 삭제 로직 구현
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('캐릭터가 삭제되었습니다')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber.shade400),
            const SizedBox(width: 8),
            const Text('Premium 업그레이드'),
          ],
        ),
        content: const Text(
          'Premium으로 업그레이드하여 AI 캐릭터 생성 기능을 이용해보세요!\n\n'
          '• 무제한 AI 캐릭터 생성\n'
          '• 고품질 이미지 생성\n'
          '• 빠른 처리 속도\n'
          '• 우선 지원',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 결제 페이지로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('결제 페이지로 이동합니다')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade400),
            child: const Text('업그레이드', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

extension MapExtension<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() => Map.fromEntries(this);
} 