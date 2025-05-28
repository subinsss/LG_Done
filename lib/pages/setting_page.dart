import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ThinQ/pages/login_page.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> with SingleTickerProviderStateMixin {
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = '한국어';
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isLoading = false;
  late ThemeMode _themeMode;

  // 지원되는 언어 목록
  final List<String> _languages = ['한국어', 'English', '日本語', '中文'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadSettings();
  }

  // 저장된 설정 불러오기
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('dark_mode') ?? false;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _selectedLanguage = prefs.getString('selected_language') ?? '한국어';
        _themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
      });
    } catch (e) {
      print('설정 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 설정 저장
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', _isDarkMode);
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setString('selected_language', _selectedLanguage);
    } catch (e) {
      print('설정 저장 오류: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F2F3),
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF1F2F3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: FadeTransition(
                opacity: _animation,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildProfileSection(),
                    const SizedBox(height: 24),
                    _buildSettingsSection(),
                    const SizedBox(height: 24),
                    _buildAccountSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '프로필',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'profile',
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey,
                        backgroundImage: _currentUser?.photoURL != null
                            ? NetworkImage(_currentUser!.photoURL!)
                            : null,
                        child: _currentUser?.photoURL == null
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser?.displayName ?? '사용자',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentUser?.email ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSettingButton(
                  '프로필 편집',
                  Icons.edit,
                  () {
                    _editProfile();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '앱 설정',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSwitchSetting(
                  '다크 모드',
                  Icons.dark_mode,
                  _isDarkMode,
                  (value) {
                    setState(() {
                      _isDarkMode = value;
                    });
                    _saveSettings();
                    _toggleDarkMode();
                    _logSettingEvent('dark_mode_changed');
                  },
                ),
                const Divider(),
                _buildSwitchSetting(
                  '알림',
                  Icons.notifications,
                  _notificationsEnabled,
                  (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveSettings();
                    _toggleNotifications();
                    _logSettingEvent('notifications_changed');
                  },
                ),
                const Divider(),
                _buildSettingButton(
                  '언어 설정',
                  Icons.language,
                  () {
                    _showLanguageDialog();
                  },
                ),
                const Divider(),
                _buildSettingButton(
                  '개인정보 보호',
                  Icons.privacy_tip,
                  () {
                    _showPrivacySettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '계정',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSettingButton(
                  '비밀번호 변경',
                  Icons.lock,
                  () {
                    _showChangePasswordDialog();
                  },
                ),
                const Divider(),
                _buildSettingButton(
                  '계정 삭제',
                  Icons.delete,
                  () {
                    _showDeleteAccountDialog();
                  },
                  textColor: Colors.red,
                ),
                const Divider(),
                _buildSettingButton(
                  '로그아웃',
                  Icons.logout,
                  () {
                    _logout(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingButton(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: textColor ?? Colors.black87),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor ?? Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchSetting(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2465D9),
          ),
        ],
      ),
    );
  }

  // 프로필 편집 기능
  void _editProfile() async {
    final TextEditingController nameController = TextEditingController(text: _currentUser?.displayName);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('프로필 편집'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: '이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '프로필 사진 변경은 아직 준비중입니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (_currentUser != null && nameController.text.isNotEmpty) {
                    await _currentUser!.updateDisplayName(nameController.text);
                    await _currentUser!.reload();
                    
                    _logSettingEvent('profile_updated');
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
                    );
                    
                    // 화면 새로고침
                    setState(() {});
                  }
                } catch (e) {
                  print('프로필 업데이트 오류: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('프로필 업데이트 오류: $e')),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  // 다크 모드 전환
  void _toggleDarkMode() {
    if (_isDarkMode) {
      // 앱 테마를 다크 모드로 변경 - 실제 구현은 앱 상위 레벨에서 이루어져야 함
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다크 모드가 활성화되었습니다. 앱을 재시작하면 적용됩니다.')),
      );
    } else {
      // 앱 테마를 라이트 모드로 변경 - 실제 구현은 앱 상위 레벨에서 이루어져야 함
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('라이트 모드가 활성화되었습니다. 앱을 재시작하면 적용됩니다.')),
      );
    }
  }

  // 알림 설정 전환
  void _toggleNotifications() {
    if (_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림이 활성화되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림이 비활성화되었습니다.')),
      );
    }
  }

  // 언어 설정 대화상자
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('언어 설정'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final language = _languages[index];
                return RadioListTile<String>(
                  title: Text(language),
                  value: language,
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    _saveSettings();
                    _logSettingEvent('language_changed');
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('언어가 $_selectedLanguage(으)로 변경되었습니다. 앱을 재시작하면 적용됩니다.')),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // 개인정보 보호 설정
  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('개인정보 보호'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('계정 공개 여부, 차단된 사용자 관리, 데이터 다운로드 등의 설정을 변경할 수 있습니다.'),
              SizedBox(height: 16),
              Text('이 기능은 현재 개발 중입니다.', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
    _logSettingEvent('privacy_settings_viewed');
  }

  // 비밀번호 변경 대화상자
  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('비밀번호 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '현재 비밀번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '새 비밀번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '비밀번호 확인',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')),
                  );
                  return;
                }
                
                try {
                  setState(() => _isLoading = true);
                  
                  // 현재 사용자 가져오기
                  final user = FirebaseAuth.instance.currentUser;
                  
                  if (user != null) {
                    // 재인증
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    
                    await user.reauthenticateWithCredential(credential);
                    
                    // 비밀번호 변경
                    await user.updatePassword(newPasswordController.text);
                    
                    _logSettingEvent('password_changed');
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호가 성공적으로 변경되었습니다.')),
                    );
                  }
                } catch (e) {
                  print('비밀번호 변경 오류: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('비밀번호 변경 오류: 현재 비밀번호를 확인해주세요.')),
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('변경'),
            ),
          ],
        );
      },
    );
  }

  // 계정 삭제 대화상자
  void _showDeleteAccountDialog() {
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('계정 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '비밀번호를 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  setState(() => _isLoading = true);
                  
                  // 현재 사용자 가져오기
                  final user = FirebaseAuth.instance.currentUser;
                  
                  if (user != null) {
                    // 재인증
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: passwordController.text,
                    );
                    
                    await user.reauthenticateWithCredential(credential);
                    
                    // 계정 삭제
                    await user.delete();
                    
                    _logSettingEvent('account_deleted');
                    Navigator.of(context).pop();
                    
                    // 로그인 화면으로 이동
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('계정이 삭제되었습니다.')),
                    );
                  }
                } catch (e) {
                  print('계정 삭제 오류: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('계정 삭제 오류: 비밀번호를 확인해주세요.')),
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child: const Text(
                '삭제',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // 로그아웃
  Future<void> _logout(BuildContext context) async {
    try {
      setState(() => _isLoading = true);
      
      // 로그아웃 처리
      await FirebaseAuth.instance.signOut();
      
      // Google Analytics 이벤트 로깅
      await FirebaseAnalytics.instance.logEvent(
        name: 'logout',
      );
      
      // 로그인 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
      
    } catch (e) {
      print('로그아웃 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Firebase Analytics 이벤트 로깅
  Future<void> _logSettingEvent(String settingName) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'setting_changed',
      parameters: {
        'setting_name': settingName,
      },
    );
  }
} 