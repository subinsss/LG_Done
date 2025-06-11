import 'package:flutter/material.dart';
import 'profile_edit_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '환경설정',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 계정 관리
            _buildSectionCard(
              title: '계정 관리',
              icon: Icons.account_circle_outlined,
              children: [
                _buildSettingItem(
                  icon: Icons.person_outline,
                  title: '프로필 수정',
                  subtitle: '이름, 이메일 등 기본 정보 수정',
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    _showProfileDialog();
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.lock_outline,
                  title: '비밀번호 변경',
                  subtitle: '계정 보안을 위한 비밀번호 변경',
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    _showPasswordDialog();
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.logout,
                  title: '로그아웃',
                  subtitle: '현재 계정에서 로그아웃',
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    _showLogoutDialog();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 알림 설정
            _buildSectionCard(
              title: '알림 설정',
              icon: Icons.notifications_outlined,
              children: [
                _buildSettingItem(
                  icon: Icons.notifications_active_outlined,
                  title: '푸시 알림',
                  subtitle: '할일 알림 및 목표 달성 알림',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                    activeColor: Colors.black,
                    activeTrackColor: Colors.grey.shade300,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade300,
                    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                    thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Icon(Icons.circle, color: Colors.black, size: 16);
                      }
                      return const Icon(Icons.circle, color: Colors.white, size: 16);
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.schedule_outlined,
                  title: '알림 시간 설정',
                  subtitle: '일일 목표 알림 시간 설정',
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    _showNotificationTimeDialog();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 테마 설정
            _buildSectionCard(
              title: '테마 설정',
              icon: Icons.palette_outlined,
              children: [
                _buildSettingItem(
                  icon: Icons.dark_mode_outlined,
                  title: '다크 모드',
                  subtitle: '어두운 테마 사용',
                  trailing: Switch(
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() {
                        _darkModeEnabled = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? '다크 모드는 향후 업데이트에서 지원될 예정입니다.' : '라이트 모드로 설정되었습니다.'),
                          backgroundColor: value ? Colors.orange : Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    activeColor: Colors.black,
                    activeTrackColor: Colors.grey.shade300,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade300,
                    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                    thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Icon(Icons.circle, color: Colors.black, size: 16);
                      }
                      return const Icon(Icons.circle, color: Colors.white, size: 16);
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 데이터 관리
            _buildSectionCard(
              title: '데이터 관리',
              icon: Icons.storage_outlined,
              children: [
                _buildSettingItem(
                  icon: Icons.backup_outlined,
                  title: '데이터 백업',
                  subtitle: '클라우드에 데이터 백업',
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    _showBackupDialog();
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.restore_outlined,
                  title: '데이터 복원',
                  subtitle: '백업된 데이터에서 복원',
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    _showRestoreDialog();
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.delete_outline,
                  title: '모든 데이터 삭제',
                  subtitle: '앱의 모든 데이터를 삭제',
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    _showDeleteAllDialog();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: Colors.black, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: Colors.grey.shade200,
        height: 1,
      ),
    );
  }

  // 계정 관리 다이얼로그들
  void _showProfileDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileEditPage(),
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: AlertDialog(
          title: const Text('비밀번호 변경'),
          content: const Text('비밀번호 변경 기능은 향후 업데이트에서 제공될 예정입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말로 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그아웃되었습니다.'),
                    backgroundColor: Colors.black,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }

  // 알림 설정 다이얼로그
  void _showNotificationTimeDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: AlertDialog(
          title: const Text('알림 시간 설정'),
          content: const Text('알림 시간은 오후 8시로 기본 설정되어 있습니다.\n시간 변경 기능은 향후 업데이트에서 제공될 예정입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  // 데이터 관리 다이얼로그들
  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: AlertDialog(
          title: const Text('데이터 백업'),
          content: const Text('모든 할일과 설정 데이터를 클라우드에 백업하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('데이터 백업이 완료되었습니다.'),
                    backgroundColor: Colors.black,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('백업'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: AlertDialog(
          title: const Text('데이터 복원'),
          content: const Text('백업된 데이터로 복원하시겠습니까? 현재 데이터는 덮어쓰기됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('데이터 복원이 완료되었습니다.'),
                    backgroundColor: Colors.black,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('복원'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: AlertDialog(
          title: const Text('모든 데이터 삭제'),
          content: const Text('정말로 모든 데이터를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('모든 데이터가 삭제되었습니다.'),
                    backgroundColor: Colors.black,
                  ),
                );
              },
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
  }
} 