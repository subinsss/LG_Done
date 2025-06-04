import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ThinQ/data/character.dart';
import 'package:ThinQ/data/character_item.dart';
import 'package:ThinQ/pages/premium_subscription_page.dart';

class CharacterCustomizationPage extends StatefulWidget {
  final Character character;

  const CharacterCustomizationPage({super.key, required this.character});

  @override
  State<CharacterCustomizationPage> createState() => _CharacterCustomizationPageState();
}

class _CharacterCustomizationPageState extends State<CharacterCustomizationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CharacterItem> _items = [];
  Map<String, List<CharacterItem>> _itemsByCategory = {};
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, CharacterItem?> _selectedItems = {};
  Character? _customizedCharacter;
  File? _profileImage;
  bool _isUploading = false;
  bool _isSaving = false;
  bool _isGeneratingAvatar = false;
  
  final List<String> _tabTitles = ['외형', '악세서리', '배경', '캐릭터'];
  final List<String> _categoryKeys = ['outfit', 'accessory', 'background', 'avatar'];
  
  // 메모이제이션을 위한 캐시
  final Map<String, Widget> _cachedItemGrids = {};
  
  // 아바타 생성을 위한 컨트롤러
  final TextEditingController _avatarPromptController = TextEditingController();
  String _generatedAvatarUrl = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _customizedCharacter = widget.character;
    _loadCharacterItems();
    
    // 분석 이벤트 기록 - 비동기로 처리하여 UI 차단 방지
    Future.microtask(() {
      FirebaseAnalytics.instance.logEvent(
        name: 'character_customization_opened',
        parameters: {
          'character_id': widget.character.id,
          'character_type': widget.character.characterType,
        },
      );
    });
    
    // 기존 생성된 아바타 URL이 있다면 설정
    if (widget.character.networkImageUrl != null && widget.character.networkImageUrl!.isNotEmpty) {
      _generatedAvatarUrl = widget.character.networkImageUrl!;
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _avatarPromptController.dispose();
    // 캐시 정리
    _cachedItemGrids.clear();
    super.dispose();
  }
  
  // 캐릭터 아이템 로드
  Future<void> _loadCharacterItems() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      List<CharacterItem> items = [];
      // Firebase 접속 횟수 줄이기: 네트워크 상태나 기타 조건에 따라 로컬 샘플 데이터 사용
      bool useLocalData = false;
      
      if (!useLocalData) {
        try {
          // 실제 Firestore에서 데이터를 가져오는 경우
          final snapshot = await FirebaseFirestore.instance
              .collection('character_items')
              .where('compatibleCharacters', arrayContains: widget.character.id)
              .get();
              
          if (snapshot.docs.isEmpty) {
            items = CharacterItem.getSampleItems();
          } else {
            items = snapshot.docs
                .map((doc) => CharacterItem.fromMap(doc.data(), doc.id))
                .toList();
          }
        } catch (e) {
          // Firestore 접속 실패 시 샘플 데이터 사용
          items = CharacterItem.getSampleItems();
        }
      } else {
        items = CharacterItem.getSampleItems();
      }
      
      // 현재 캐릭터의 커스터마이징 정보 가져오기
      Map<String, String> currentCustomization = {};
      if (widget.character.customization.isNotEmpty) {
        widget.character.customization.forEach((key, value) {
          if (value is String) {
            currentCustomization[key] = value;
          }
        });
      }
      
      // 카테고리별로 아이템 분류 (캐시 활용)
      final Map<String, List<CharacterItem>> itemsByCategory = {};
      for (final item in items) {
        if (!itemsByCategory.containsKey(item.type)) {
          itemsByCategory[item.type] = [];
        }
        itemsByCategory[item.type]!.add(item);
      }
      
      // 현재 선택된 아이템 설정
      final Map<String, CharacterItem?> selectedItems = {};
      itemsByCategory.forEach((category, categoryItems) {
        final currentItemId = currentCustomization[category];
        if (currentItemId != null && categoryItems.isNotEmpty) {
          final matchingItems = categoryItems.where((item) => item.id == currentItemId).toList();
          selectedItems[category] = matchingItems.isNotEmpty ? matchingItems.first : categoryItems.first;
        } else if (categoryItems.isNotEmpty) {
          // 기본 아이템 선택 (첫 번째 아이템)
          selectedItems[category] = categoryItems.first;
        }
      });
      
      if (mounted) {
        setState(() {
          _items = items;
          _itemsByCategory = itemsByCategory;
          _selectedItems = selectedItems;
          _isLoading = false;
          
          // 그리드 캐시 초기화
          _cachedItemGrids.clear();
        });
      }
    } catch (e) {
      print('캐릭터 아이템 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '아이템을 불러오는 중 오류가 발생했습니다';
          
          // 오류 발생 시 샘플 데이터로 초기화
          _items = CharacterItem.getSampleItems();
          
          // 카테고리별로 아이템 분류
          _itemsByCategory = {};
          for (final item in _items) {
            if (!_itemsByCategory.containsKey(item.type)) {
              _itemsByCategory[item.type] = [];
            }
            _itemsByCategory[item.type]!.add(item);
          }
          
          // 현재 선택된 아이템 설정 (기본값)
          _selectedItems = {};
          _itemsByCategory.forEach((category, categoryItems) {
            if (categoryItems.isNotEmpty) {
              _selectedItems[category] = categoryItems.first;
            }
          });
        });
      }
    }
  }
  
  // 아이템 선택 변경 (최적화)
  void _onItemSelected(String category, CharacterItem item) {
    // 이미 선택된 아이템이면 무시
    if (_selectedItems[category]?.id == item.id) return;
    
    // 프리미엄 아이템인 경우 프리미엄 회원인지 확인
    if (item.isPremium) {
      final isPremium = widget.character.isPremium;
      if (!isPremium) {
        _showPremiumItemDialog(item);
        return;
      }
    }
    
    if (mounted) {
      setState(() {
        _selectedItems[category] = item;
        
        // 캐릭터 커스터마이징 정보 업데이트
        final newCustomization = Map<String, dynamic>.from(widget.character.customization);
        newCustomization[category] = item.id;
        
        _customizedCharacter = widget.character.copyWith(
          customization: newCustomization,
        );
        
        // 캐시 무효화 (선택한 카테고리만)
        _cachedItemGrids.remove(category);
      });
    }
    
    // 분석 이벤트 기록 (별도 스레드에서 처리)
    Future.microtask(() {
      FirebaseAnalytics.instance.logEvent(
        name: 'character_item_selected',
        parameters: {
          'character_id': widget.character.id,
          'item_id': item.id,
          'item_type': category,
        },
      );
    });
  }
  
  // 프리미엄 아이템 선택 시 안내 다이얼로그
  void _showPremiumItemDialog(CharacterItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프리미엄 아이템'),
        content: const Text('이 아이템은 프리미엄 사용자만 이용할 수 있습니다. 프리미엄으로 업그레이드하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 프리미엄 결제 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PremiumSubscriptionPage(),
                ),
              ).then((isPremium) {
                if (isPremium == true && mounted) {
                  // 구독 성공 시 아이템 선택 처리
                  _loadCharacterItems();
                }
              });
              
              // 분석 기록은 별도 스레드에서 처리
              Future.microtask(() {
                FirebaseAnalytics.instance.logEvent(
                  name: 'premium_conversion_started',
                  parameters: {
                    'source': 'character_customization',
                    'item_id': item.id,
                    'item_type': item.type,
                  },
                );
              });
            },
            child: const Text('업그레이드'),
          ),
        ],
      ),
    );
  }
  
  // 프로필 이미지 선택 (최적화)
  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 선택하는 중 오류가 발생했습니다')),
        );
      }
    }
  }
  
  // 아바타 생성 함수 (프롬프트 기반)
  Future<void> _generateAvatar(String prompt) async {
    if (prompt.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프롬프트를 입력해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isGeneratingAvatar = true;
    });
    
    try {
      String enhancedPrompt = "character, 2-head-tall chibi with big head small body, ${prompt}, cute maplestory game style, digital art, full body, white background, high quality, vibrant colors, clean lineart";
      
      // 사용자 서버 API 호출 (컴퓨터 IP 주소 사용)
      final response = await http.post(
        Uri.parse('http://172.20.10.11:5050/generate/prompt'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prompt': enhancedPrompt,
          'style': 'anime',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['image_url'] != null) {
          final String imageUrl = data['image_url'];
          final String characterId = data['character_id'] ?? '';
          final String message = data['message'] ?? '캐릭터가 생성되었습니다!';
          
          if (mounted) {
            setState(() {
              _generatedAvatarUrl = imageUrl;
              _isGeneratingAvatar = false;
              
              // 캐릭터 객체에 네트워크 이미지 URL 업데이트
              _customizedCharacter = _customizedCharacter!.copyWith(
                networkImageUrl: imageUrl,
              );
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(data['error'] ?? '캐릭터 생성에 실패했습니다');
        }
      } else {
        print('API 호출 실패: ${response.statusCode} ${response.body}');
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('캐릭터 생성 오류: $e');
      if (mounted) {
        setState(() {
          _isGeneratingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캐릭터 생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 이미지 기반 캐릭터 생성 함수 추가
  Future<void> _generateAvatarFromImage(File imageFile) async {
    setState(() {
      _isGeneratingAvatar = true;
    });
    
    try {
      // 멀티파트 요청 생성
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.20.10.11:5050/generate/image'),
      );
      
      // 이미지 파일 추가
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );
      
      // 스타일 파라미터 추가
      request.fields['style'] = 'anime';
      
      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['image_url'] != null) {
          final String imageUrl = data['image_url'];
          final String characterId = data['character_id'] ?? '';
          final String message = data['message'] ?? '이미지 기반 캐릭터가 생성되었습니다!';
          
          if (mounted) {
            setState(() {
              _generatedAvatarUrl = imageUrl;
              _isGeneratingAvatar = false;
              
              // 캐릭터 객체에 네트워크 이미지 URL 업데이트
              _customizedCharacter = _customizedCharacter!.copyWith(
                networkImageUrl: imageUrl,
              );
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(data['error'] ?? '이미지 기반 캐릭터 생성에 실패했습니다');
        }
      } else {
        print('API 호출 실패: ${response.statusCode} ${response.body}');
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('이미지 기반 캐릭터 생성 오류: $e');
      if (mounted) {
        setState(() {
          _isGeneratingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 기반 캐릭터 생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 프로필 이미지 업로드 (최적화)
  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null && _generatedAvatarUrl.isEmpty) return null;
    
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }
    
    try {
      // 스토리지 경로 설정
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');
      
      // 생성된 아바타가 있다면 해당 URL 반환
      if (_generatedAvatarUrl.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
        return _generatedAvatarUrl;
      }
      
      // 프로필 이미지가 있다면 업로드
      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);
          
      // 파일 업로드 (압축 및 최적화 적용)
      final uploadTask = storageRef.putFile(
        _profileImage!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      
      // 다운로드 URL 가져오기
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
      
      return downloadUrl;
    } catch (e) {
      print('프로필 이미지 업로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 업로드 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null;
    }
  }
  
  // 변경사항 저장 (최적화)
  Future<void> _saveChanges() async {
    if (_isSaving) return; // 중복 저장 방지
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _customizedCharacter == null) return;
    
    if (mounted) {
      setState(() {
        _isSaving = true;
        _isLoading = true;
      });
    }
    
    try {
      // 프로필 이미지가 있다면 업로드
      String? imageUrl;
      if (_profileImage != null || _generatedAvatarUrl.isNotEmpty) {
        imageUrl = await _uploadProfileImage();
      }
      
      // 커스터마이징 정보 업데이트
      final newCustomization = Map<String, dynamic>.from(_customizedCharacter!.customization);
      if (imageUrl != null) {
        newCustomization['profileImage'] = imageUrl;
      }
      
      // Firestore에 변경사항 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('characters')
          .doc(_customizedCharacter!.id)
          .update({
        'customization': newCustomization,
        'networkImageUrl': imageUrl ?? _customizedCharacter!.networkImageUrl,
      });
      
      // 업데이트된 캐릭터 정보 생성
      final updatedCharacter = _customizedCharacter!.copyWith(
        customization: newCustomization,
        imageUrl: imageUrl ?? _customizedCharacter!.imageUrl,
        networkImageUrl: imageUrl ?? _customizedCharacter!.networkImageUrl,
      );
      
      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('변경사항이 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 이전 화면으로 업데이트된 캐릭터 정보 전달
        Navigator.pop(context, updatedCharacter);
      }
      
      // 분석 이벤트 기록 (별도 스레드)
      Future.microtask(() {
        FirebaseAnalytics.instance.logEvent(
          name: 'character_customization_saved',
          parameters: {
            'character_id': widget.character.id,
          },
        );
      });
    } catch (e) {
      print('캐릭터 커스터마이징 저장 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('변경사항을 저장하는 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
      }
    }
  }
  
  // 카테고리별 아이콘 가져오기 (상수 캐싱)
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'outfit':
        return Icons.checkroom;
      case 'accessory':
        return Icons.watch;
      case 'background':
        return Icons.wallpaper;
      case 'avatar':
        return Icons.face;
      default:
        return Icons.category;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('캐릭터 커스터마이징'),
        actions: [
          // 저장 버튼
          if (_isSaving)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.all(16),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveChanges,
              tooltip: '변경사항 저장',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: _isLoading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 아바타 미리보기 영역
                Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: _buildAvatarPreview(),
                  ),
                ),
                
                // 아이템 선택 영역 - TabBarView는 많은 메모리를 소비할 수 있으므로 최적화
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: List.generate(_categoryKeys.length, (index) {
                      if (_categoryKeys[index] == 'avatar') {
                        return _buildAvatarGenerationTab();
                      }
                      return _getCachedItemsGrid(_categoryKeys[index]);
                    }),
                  ),
                ),
              ],
            ),
    );
  }
  
  // 아바타 생성 탭 UI
  Widget _buildAvatarGenerationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '캐릭터 생성',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '원하는 특성을 입력하면 캐릭터를 생성합니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          
          // 프롬프트 입력 필드
          TextField(
            controller: _avatarPromptController,
            decoration: const InputDecoration(
              labelText: '캐릭터 특징 (예: 파란머리 마법사, 빨간 모자 전사 등)',
              border: OutlineInputBorder(),
              hintText: '원하는 캐릭터의 특징을 입력하세요',
            ),
            maxLines: 3,
            enabled: !_isGeneratingAvatar,
          ),
          const SizedBox(height: 16),
          
          // 생성 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isGeneratingAvatar ? null : () => _generateAvatar(_avatarPromptController.text.trim()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child: _isGeneratingAvatar
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('아바타 생성 중...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                  : const Text('아바타 생성하기', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
          
          // 생성된 아바타 표시
          if (_generatedAvatarUrl.isNotEmpty) ...[
            const Text(
              '생성된 아바타:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _generatedAvatarUrl,
                  height: 300,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 40, color: Colors.red),
                          SizedBox(height: 8),
                          Text('이미지를 불러올 수 없습니다'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // 메모이제이션을 활용한 아이템 그리드 캐싱
  Widget _getCachedItemsGrid(String category) {
    if (!_cachedItemGrids.containsKey(category)) {
      _cachedItemGrids[category] = _buildItemsGrid(category);
    }
    return _cachedItemGrids[category]!;
  }
  
  // 아바타 미리보기 위젯
  Widget _buildAvatarPreview() {
    final selectedOutfit = _selectedItems['outfit'];
    final selectedAccessory = _selectedItems['accessory'];
    final selectedBackground = _selectedItems['background'];
    
    return RepaintBoundary(
      child: SizedBox(
        height: 180,
        width: MediaQuery.of(context).size.width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 배경
            if (selectedBackground != null)
              Positioned.fill(
                child: Image.asset(
                  selectedBackground.imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: (MediaQuery.of(context).size.width * 1.5).toInt(),
                  errorBuilder: (context, error, stackTrace) {
                    print('배경 이미지 로드 오류: $error');
                    return Container(
                      color: widget.character.getAvatarBackgroundColor().withOpacity(0.3),
                    );
                  },
                ),
              )
            else 
              Positioned.fill(
                child: Container(
                  color: widget.character.getAvatarBackgroundColor().withOpacity(0.3),
                ),
              ),
            
            // 생성된 아바타 이미지가 있다면 표시
            if (_generatedAvatarUrl.isNotEmpty)
              Positioned(
                child: Container(
                  height: 160,
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    _generatedAvatarUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              )
            // 프로필 이미지나 아이콘 표시
            else if (_profileImage != null) 
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.character.getAvatarBackgroundColor(),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  image: DecorationImage(
                    image: FileImage(_profileImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (widget.character.customization.containsKey('profileImage') &&
                    widget.character.customization['profileImage'] is String &&
                    widget.character.customization['profileImage'].isNotEmpty)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.character.getAvatarBackgroundColor(),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(widget.character.customization['profileImage']),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              )
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.character.getAvatarBackgroundColor(),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.character.getAvatarIcon(),
                  size: 60,
                  color: Colors.white,
                ),
              ),
            
            // 의상 (오버레이) - 이미지 캐싱 사용
            if (_generatedAvatarUrl.isEmpty && selectedOutfit != null)
              Positioned(
                child: Image.asset(
                  selectedOutfit.imageUrl,
                  width: 140,
                  height: 140,
                  cacheWidth: 280, // 고해상도 디스플레이 대응
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) {
                    print('의상 이미지 로드 오류: $error');
                    return const SizedBox.shrink();
                  },
                ),
              ),
            
            // 악세서리 (오버레이) - 이미지 캐싱 사용
            if (_generatedAvatarUrl.isEmpty && selectedAccessory != null)
              Positioned(
                child: Image.asset(
                  selectedAccessory.imageUrl,
                  width: 60,
                  height: 60,
                  cacheWidth: 120, // 고해상도 디스플레이 대응
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) {
                    print('악세서리 이미지 로드 오류: $error');
                    return const SizedBox.shrink();
                  },
                ),
              ),
            
            // 사진 변경 또는 아바타 탭으로 이동 버튼
            Positioned(
              bottom: 10,
              right: 10,
              child: FloatingActionButton.small(
                heroTag: "avatar_photo_btn", // 중복 hero 태그 방지
                onPressed: _generatedAvatarUrl.isNotEmpty
                    ? () => _tabController.animateTo(3) // 아바타 탭으로 이동
                    : _isUploading ? null : _pickProfileImage,
                tooltip: _generatedAvatarUrl.isNotEmpty ? "아바타 변경" : "프로필 사진 변경",
                child: _isUploading 
                    ? const SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : Icon(_generatedAvatarUrl.isNotEmpty ? Icons.face : Icons.photo_camera),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 아이템 그리드 위젯 (최적화)
  Widget _buildItemsGrid(String category) {
    final categoryItems = _itemsByCategory[category] ?? [];
    
    if (categoryItems.isEmpty) {
      return const Center(
        child: Text('사용 가능한 아이템이 없습니다'),
      );
    }
    
    // 불필요한 빌드를 피하기 위해 ListView 대신 GridView.builder 사용
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: categoryItems.length,
      itemBuilder: (context, index) {
        final item = categoryItems[index];
        final isSelected = _selectedItems[category]?.id == item.id;
        
        // 이미지와 같은 무거운 위젯을 위해 RepaintBoundary 사용
        return RepaintBoundary(
          child: GestureDetector(
            onTap: () => _onItemSelected(category, item),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? Colors.blue.shade50 : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 아이템 이미지
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 아이템 이미지 (캐시 활용)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            item.imageUrl,
                            fit: BoxFit.contain,
                            // 캐싱 활용
                            cacheWidth: 100,
                            cacheHeight: 100,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                _getCategoryIcon(category),
                                size: 40,
                                color: Colors.grey,
                              );
                            },
                          ),
                        ),
                        
                        // 프리미엄 배지
                        if (item.isPremium)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        
                        // 선택 마크
                        if (isSelected)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // 아이템 정보
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (item.price > 0)
                          Text(
                            '${item.price} 포인트',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 