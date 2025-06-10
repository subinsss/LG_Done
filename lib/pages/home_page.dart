import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dx_project/data/task.dart';
import 'package:dx_project/data/character.dart';
import 'package:dx_project/pages/setting_page.dart';
import 'package:dx_project/pages/character_selection_page.dart';
import 'package:dx_project/pages/character_customization_page.dart';
import 'package:dx_project/pages/thinq_hub_page.dart';
import 'package:dx_project/pages/premium_subscription_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> _tasks = [];
  List<String> _activeUsers = [];
  int _currentIndex = 0;
  int _totalMinutes = 0;
  bool _isPremium = false;
  bool _isLoading = true;
  
  // 서비스 분류
  String _selectedCategory = 'character';
  
  // 서비스 목록 정의 - const로 선언하여 불필요한 재생성 방지
  final List<Map<String, dynamic>> _characterServices = [
    {
      'title': 'AI 캐릭터 채팅',
      'description': 'MBTI 기반 페르소나가 있는 AI 캐릭터와 채팅하고 할일 피드백과 추천을 받으세요.',
      'icon': Icons.chat,
      'color': Colors.purple,
      'isPremium': false,
    },
    {
      'title': '캐릭터 커스터마이징',
      'description': '당신만의 AI 캐릭터를 의상, 액세서리, 배경으로 꾸미고 커스터마이징 해보세요.',
      'icon': Icons.style,
      'color': Colors.blue,
      'customAction': true,
      'isPremium': false,
      'premiumFeatures': true,
    },
  ];
  
  final List<Map<String, dynamic>> _hubServices = [
    {
      'title': 'LG ThinQ 허브',
      'description': 'LG ThinQ 기기를 관리하고 원격으로 제어하는 스마트 허브입니다.',
      'icon': Icons.home,
      'color': Colors.green,
      'isPremium': false,
    }
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await Future.wait([
        _loadTasks(),
        _loadUserStatus(),
      ]);
      
      _setupActiveUsersListener();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // 로딩 완료 후 비동기적으로 공지사항 로드
      if (mounted) {
        _loadNotice();
      }
    } catch (e) {
      print('데이터 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF1F2F3),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _handleNavigationTap,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: '관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '통계',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }

  void _handleNavigationTap(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingPage(),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _currentIndex = 0;
          });
        }
      });
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _navigateToServicePage(Map<String, dynamic> service) {
    if (service['isPremium'] == true && !_isPremium) {
      _showPremiumDialog();
      return;
    }
    
    if (service['customAction'] == true) {
      _navigateToCustomization();
    } else if (service['title'] == 'AI 캐릭터 채팅') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CharacterSelectionPage(isPremium: _isPremium),
        ),
      );
    } else if (service['title'] == 'LG ThinQ 허브') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ThinQHubPage(),
        ),
      );
    }
    
    FirebaseAnalytics.instance.logEvent(
      name: 'service_opened',
      parameters: {
        'service_name': service['title'],
      },
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildManagementPage();
      case 1:
        return const Center(child: Text('통계 페이지 (준비 중)'));
      default:
        return _buildManagementPage();
    }
  }
  
  Widget _buildManagementPage() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      '오늘의 집중 시간',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('${_totalMinutes ~/ 60}분', '총 시간', Theme.of(context).colorScheme.primary),
                      _buildStatItem('${_tasks.where((t) => t.isCompleted).length}개', '완료한 작업', Theme.of(context).colorScheme.primary),
                      _buildStatItem('${_tasks.where((t) => !t.isCompleted).length}개', '진행 중', Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildCategoryButton('캐릭터', 'character'),
                    const SizedBox(width: 16),
                    _buildCategoryButton('허브', 'hub'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final List<Map<String, dynamic>> services = 
                    _selectedCategory == 'character' ? _characterServices : _hubServices;
                
                if (index >= services.length) return null;
                final service = services[index];
                
                final bool requiresPremium = service['isPremium'] == true;
                final bool hasPremiumFeatures = service['premiumFeatures'] == true;
                
                return _buildServiceCard(service, requiresPremium, hasPremiumFeatures);
              },
              childCount: _selectedCategory == 'character' 
                  ? _characterServices.length 
                  : _hubServices.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, bool requiresPremium, bool hasPremiumFeatures) {
    return GestureDetector(
      onTap: () => _navigateToServicePage(service),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: service['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      service['icon'],
                      color: service['color'],
                      size: 22,
                    ),
                  ),
                  if (requiresPremium && !_isPremium)
                    const Padding(
                      padding: EdgeInsets.only(left: 6.0),
                      child: Icon(
                        Icons.workspace_premium,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                  if (hasPremiumFeatures)
                    const Padding(
                      padding: EdgeInsets.only(left: 6.0),
                      child: Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                service['title'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  service['description'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasPremiumFeatures)
                const Text(
                  '프리미엄 기능 포함',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String title, String category) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedCategory = category;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected 
              ? Colors.transparent 
              : Colors.grey[200],
          foregroundColor: isSelected 
              ? Colors.black 
              : Colors.grey[800],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isSelected 
                ? BorderSide(color: Colors.grey.shade400, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Text(title),
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label, Color primaryColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _setupActiveUsersListener() {
    FirebaseDatabase.instance.ref().child('active_users').onValue.listen(
      (event) {
        if (mounted) {
          final dynamic data = event.snapshot.value;
          setState(() {
            _activeUsers = data == null ? [] : List<String>.from(data);
          });
        }
      },
    );
  }

  Future<void> _loadTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection("tasks")
          .where("uid", isEqualTo: user.uid)
          .orderBy("createdAt", descending: true)
          .get();
      
      if (!mounted) return;
          
      final documents = snapshot.docs;
      List<Task> tasks = [];
      int totalMinutes = 0;

      for (final doc in documents) {
        final data = doc.data();
        final id = doc.id;
        final uid = data['uid'];
        final title = data['title'];
        final description = data['description'] ?? '';
        final int duration = (data['duration'] is int) ? data['duration'] : ((data['duration'] ?? 0) as num).toInt();
        final isCompleted = data['isCompleted'] ?? false;
        final createdAt = data['createdAt'];
        
        if (isCompleted) {
          totalMinutes += duration;
        }
        
        tasks.add(
          Task(
            id: id,
            uid: uid,
            title: title,
            description: description,
            duration: duration,
            isCompleted: isCompleted,
            createdAt: createdAt,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _totalMinutes = totalMinutes;
        });
      }
    } catch (e) {
      print('태스크 로딩 오류: $e');
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Text(
            'LG:Done',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
      title: Text(
        'ThinQ',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      actions: [
        if (_isPremium)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadUserStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _isPremium = data['isPremium'] ?? false;
          });
        }
      }
    } catch (e) {
      print('사용자 상태 로딩 오류: $e');
    }
  }

  Future<void> _loadNotice() async {
    try {
      final notice = FirebaseRemoteConfig.instance.getString('notice');
      if (notice.isEmpty || !mounted) {
        return;
      }
      
      showDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('공지사항'),
            content: Container(
              margin: const EdgeInsets.only(top: 10),
              child: Text(notice),
            ),
            actions: [
              CupertinoButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('공지사항 로딩 오류: $e');
    }
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프리미엄 기능'),
        content: const Text('이 기능은 프리미엄 사용자만 이용할 수 있습니다. 프리미엄으로 업그레이드하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PremiumSubscriptionPage(),
                ),
              ).then((isPremium) {
                if (isPremium == true && mounted) {
                  _loadUserStatus();
                }
              });
              
              FirebaseAnalytics.instance.logEvent(
                name: 'premium_conversion_started',
              );
            },
            child: const Text('업그레이드'),
          ),
        ],
      ),
    );
  }

  void _navigateToCustomization() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('characters')
          .limit(1)
          .get();
      
      if (!mounted) return;
      
      Character character;
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        character = Character.fromMap(data, snapshot.docs.first.id);
      } else {
        character = Character.getDefaultCharacter();
      }
      
      setState(() {
        _isLoading = false;
      });
      
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => CharacterCustomizationPage(character: character),
        ),
      );
    } catch (e) {
      print('캐릭터 정보 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('캐릭터 정보를 로드하는 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 