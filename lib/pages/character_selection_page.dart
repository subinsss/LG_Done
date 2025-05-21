import 'package:flutter/material.dart';
import 'package:ThinQ/data/character.dart';
import 'package:ThinQ/pages/chat_page.dart';
import 'package:ThinQ/pages/character_customization_page.dart';
import 'package:ThinQ/pages/premium_subscription_page.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CharacterSelectionPage extends StatefulWidget {
  final bool isPremium;
  final bool isCustomizationMode;
  
  const CharacterSelectionPage({
    super.key, 
    this.isPremium = false,
    this.isCustomizationMode = false,
  });

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> with SingleTickerProviderStateMixin {
  late List<Character> _allCharacters;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagLineController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _infoController = TextEditingController();
  
  Character? _selectedCharacter;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  
  // 로딩 상태 추가
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  // 사용자 정보 변수
  String _userName = '';
  String _userInitial = '';
  bool _isLoggedIn = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }
  
  // 데이터 로딩 함수
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    // 비동기 작업을 시뮬레이션하기 위한 지연
    await Future.delayed(const Duration(milliseconds: 800));
    
    _initializeCharacters();
    _loadUserInfo();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 데이터 새로고침 함수
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    // 비동기 작업을 시뮬레이션하기 위한 지연
    await Future.delayed(const Duration(milliseconds: 800));
    
    _initializeCharacters();
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }
  
  void _initializeCharacters() {
    // 모든 캐릭터 목록 가져오기
    _allCharacters = Character.getRandomCharacters();
  }
  
  void _loadUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoggedIn = true;
        // 사용자 이름 설정 (displayName이 없으면 이메일의 @ 앞부분 사용)
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          _userName = user.displayName!;
        } else if (user.email != null && user.email!.isNotEmpty) {
          _userName = user.email!.split('@')[0];
        } else {
          _userName = '사용자_${user.uid.substring(0, 5)}';
        }
        
        // 이니셜 설정 (이름의 첫 글자)
        _userInitial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
      });
    } else {
      setState(() {
        _isLoggedIn = false;
        _userName = '익명 사용자';
        _userInitial = '?';
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _tagLineController.dispose();
    _descriptionController.dispose();
    _infoController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  void _selectCharacter(Character character) {
    setState(() {
      _selectedCharacter = character;
    });
  }

  void _startChatWithSelectedCharacter() {
    if (_selectedCharacter == null) return;
    
    // 사용자가 입력한 프롬프트 정보를 가져옴
    String customPersona = '';
    if (_infoController.text.isNotEmpty) {
      customPersona = _infoController.text;
    }
    
    // 커스텀 페르소나가 있으면 Character 객체를 업데이트
    Character characterToChat = _selectedCharacter!;
    if (customPersona.isNotEmpty) {
      characterToChat = _selectedCharacter!.copyWith(
        persona: customPersona,
      );
    }
    
    // 채팅 페이지로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          character: characterToChat,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AI 캐릭터 채팅',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : Column(
              children: [
                _buildCharacterSelectionTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecommendedTabView(),
                      _buildCustomTabView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildCharacterSelectionTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        indicatorSize: TabBarIndicatorSize.label,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: const [
          Tab(text: '캐릭터 목록'),
          Tab(text: '커스텀 채팅'),
        ],
      ),
    );
  }

  Widget _buildRecommendedTabView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildCharacterCardGrid(_allCharacters),
      ),
    );
  }

  Widget _buildCustomTabView() {
    return _selectedCharacter == null 
        ? Center(child: const Text('왼쪽 탭에서 캐릭터를 선택해주세요'))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프롬프트 입력 필드들
                _buildPromptInputSection(),
                
                // 채팅 시작 버튼
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 24, bottom: 32),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _startChatWithSelectedCharacter,
                    child: const Text(
                      '대화 시작하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildPromptInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '캐릭터 이름',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        _buildTextField(_nameController, '0/20', hint: '예: 앨버트 아인슈타인'),
        const SizedBox(height: 16),

        const Text(
          '태그라인',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        _buildTextField(_tagLineController, '0/50', hint: '캐릭터의 짧은 태그라인 추가'),
        const SizedBox(height: 16),

        const Text(
          '설명',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        _buildTextField(_descriptionController, '0/500', maxLines: 4, hint: '캐릭터는 자신을 어떻게 묘사하나요?'),
        const SizedBox(height: 16),

        const Text(
          '인사',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        _buildTextField(_infoController, '0/4096', maxLines: 6, hint: '예: 안녕하세요. 저는 앨버트입니다. 제 과학적 기여에 대해 무엇이든 물어보세요.'),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String counter, {int maxLines = 1, String? hint}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        suffixText: counter,
        suffixStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildCharacterCardGrid(List<Character> characters) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        final bool isSelected = _selectedCharacter?.id == character.id;
        
        return GestureDetector(
          onTap: () => _selectCharacter(character),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? character.getAvatarBackgroundColor() : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 캐릭터 이미지
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: character.getAvatarBackgroundColor().withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: character.networkImageUrl != null && character.networkImageUrl!.isNotEmpty
                        ? Container(
                            width: 50,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: character.getAvatarBackgroundColor().withOpacity(0.1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              character.networkImageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                character.getAvatarIcon(),
                                size: 24,
                                color: character.getAvatarBackgroundColor(),
                              ),
                            ),
                          )
                        : Icon(
                            character.getAvatarIcon(),
                            size: 24,
                            color: character.getAvatarBackgroundColor(),
                          ),
                    ),
                  ),
                ),
                
                // 캐릭터 정보
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    children: [
                      Text(
                        character.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${character.characterType.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 