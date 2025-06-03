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
            Tab(icon: Icon(Icons.emoji_emotions), text: '기본'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'AI 생성'),
            Tab(icon: Icon(Icons.photo_library), text: '내 캐릭터'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 기본 캐릭터 탭
          _buildBasicCharactersTab(),
          
          // AI 캐릭터 생성 탭
          _buildAIGenerationTab(),
          
          // 내 캐릭터 탭
          _buildMyCharactersTab(),
        ],
      ),
    );
  }

  Widget _buildBasicCharactersTab() {
    final basicCharacters = widget.availableCharacters.entries
        .where((entry) => entry.value['type'] == 'emoji')
        .toMap();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 현재 선택된 캐릭터 미리보기
          _buildCurrentCharacterPreview(),
          
          const SizedBox(height: 30),
          
          Text(
            '기본 캐릭터',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '모든 사용자가 무료로 사용할 수 있는 기본 캐릭터입니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 기본 캐릭터 그리드
          _buildCharacterGrid(basicCharacters),
        ],
      ),
    );
  }

  Widget _buildAIGenerationTab() {
    if (!widget.isPremiumUser) {
      return _buildPremiumUpgradePrompt();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 생성 제한 표시
          _buildGenerationLimitCard(),
          
          const SizedBox(height: 20),
          
          // 프롬프트로 생성
          _buildPromptGenerationSection(),
          
          const SizedBox(height: 30),
          
          // 이미지로 생성
          _buildImageGenerationSection(),
          
          const SizedBox(height: 30),
          
          // 안내 정보
          _buildAIInfoCard(),
        ],
      ),
    );
  }

  Widget _buildMyCharactersTab() {
    final customCharacters = widget.availableCharacters.entries
        .where((entry) => entry.value['type'] == 'custom')
        .toMap();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '내 캐릭터',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade600,
                ),
              ),
              Text(
                '$_currentCustomCharacterCount/$_maxCustomCharacters',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (customCharacters.isEmpty)
            _buildEmptyCustomCharactersPrompt()
          else
            _buildCharacterGrid(customCharacters, showDeleteButton: true),
        ],
      ),
    );
  }

  Widget _buildPremiumUpgradePrompt() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 100,
            color: Colors.amber.shade300,
          ),
          
          const SizedBox(height: 30),
          
          Text(
            'AI 캐릭터 생성',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Premium 사용자만 이용 가능한 기능입니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 30),
          
          Container(
            padding: const EdgeInsets.all(24),
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
                Text(
                  'Premium으로 업그레이드하면',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                _buildFeatureItem('✨', '프롬프트로 캐릭터 생성'),
                _buildFeatureItem('📸', '사진으로 캐릭터 생성'),
                _buildFeatureItem('🎨', '최대 50개 커스텀 캐릭터'),
                _buildFeatureItem('⚡', '빠른 AI 생성 속도'),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Premium 업그레이드 페이지로 이동
                    _showPremiumUpgradeDialog();
                  },
                  icon: const Icon(Icons.star, color: Colors.white),
                  label: const Text(
                    'Premium 업그레이드',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationLimitCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '남은 생성 횟수: ${_maxCustomCharacters - _currentCustomCharacterCount}회',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptGenerationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit, color: Colors.pink.shade400),
              const SizedBox(width: 8),
              Text(
                '프롬프트로 생성',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _promptController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '예: 귀여운 고양이 캐릭터, 파란색 머리, 큰 눈\n또는: cute anime girl with pink hair',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              labelText: '캐릭터 설명',
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateFromPrompt,
                  icon: _isGenerating 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? '생성 중...' : '캐릭터 생성'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageGenerationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera, color: Colors.pink.shade400),
              const SizedBox(width: 8),
              Text(
                '이미지로 생성',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_uploadedImage != null) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _uploadedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: Text(_uploadedImage != null ? '다른 이미지 선택' : '이미지 선택'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.pink.shade400,
                    side: BorderSide(color: Colors.pink.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_uploadedImage != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateFromImage,
                    icon: _isGenerating 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isGenerating ? '생성 중...' : '캐릭터 생성'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCharacterPreview() {
    final characterData = widget.availableCharacters[_selectedCharacter]!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '현재 선택된 캐릭터',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade600,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 현재 캐릭터 대형 미리보기
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              color: Colors.pink.shade50,
              border: Border.all(
                color: Colors.pink.shade200,
                width: 3,
              ),
            ),
            child: characterData['type'] == 'emoji'
                ? Center(
                    child: Text(
                      characterData['normal'],
                      style: const TextStyle(fontSize: 60),
                    ),
                  )
                : characterData['type'] == 'custom'
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(57),
                        child: Image.network(
                          characterData['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            characterData['name'],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          
          if (characterData['type'] == 'emoji') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEmotionPreview('기본', characterData['normal']),
                _buildEmotionPreview('시작', characterData['starting']),
                _buildEmotionPreview('열심히', characterData['working']),
                _buildEmotionPreview('완벽', characterData['happy']),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmotionPreview(String label, String emoji) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
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

  Widget _buildAIInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.blue.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'AI 생성 팁',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 구체적인 설명을 입력하면 더 좋은 결과를 얻을 수 있어요\n'
            '• 색상, 스타일, 특징을 명확히 적어보세요\n'
            '• 영어와 한국어 모두 지원합니다\n'
            '• 생성된 캐릭터는 자동으로 저장됩니다',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 14,
              height: 1.5,
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

    setState(() {
      _isGenerating = true;
    });

    try {
      // TODO: 실제 AI API 호출 구현
      // final imageUrl = await AIImageService.generateFromPrompt(_promptController.text);
      
      // 임시로 시뮬레이션
      await Future.delayed(const Duration(seconds: 3));
      final mockImageUrl = 'https://via.placeholder.com/200x200/FF69B4/FFFFFF?text=AI+Character';
      
      // 새 커스텀 캐릭터 추가
      final newCharacterId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      // TODO: widget.availableCharacters에 추가하는 로직 구현
      
      _promptController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('캐릭터가 성공적으로 생성되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 내 캐릭터 탭으로 이동
      _tabController.animateTo(2);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('생성 실패: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
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

    setState(() {
      _isGenerating = true;
    });

    try {
      // TODO: 실제 AI API 호출 구현
      // final imageUrl = await AIImageService.generateFromImage(_uploadedImage!);
      
      // 임시로 시뮬레이션
      await Future.delayed(const Duration(seconds: 3));
      
      setState(() {
        _uploadedImage = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미지 기반 캐릭터가 생성되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 내 캐릭터 탭으로 이동
      _tabController.animateTo(2);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('생성 실패: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
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