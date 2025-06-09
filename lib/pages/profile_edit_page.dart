import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    final profile = await ProfileService.getProfile();
    setState(() {
      _nameController.text = profile['name'] ?? '김철수';
      _emailController.text = profile['email'] ?? 'user@example.com';
      _phoneController.text = profile['phone'] ?? '010-1234-5678';
      _profileImageUrl = profile['profileImageUrl'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '프로필 수정',
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
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 프로필 사진 섹션
              _buildProfileImageSection(),
              
              const SizedBox(height: 24),
              
              // 기본 정보 섹션
              _buildSectionCard(
                title: '기본 정보',
                icon: Icons.person_outline,
                children: [
                  _buildTextFormField(
                    controller: _nameController,
                    label: '이름',
                    icon: Icons.badge_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이름을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _emailController,
                    label: '이메일',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이메일을 입력해주세요';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return '올바른 이메일 형식을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _phoneController,
                    label: '전화번호',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: _profileImageUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey.shade600,
                      )
                    : ClipOval(
                        child: Image.network(
                          _profileImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey.shade600,
                            );
                          },
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: InkWell(
                    onTap: _showImageOptions,
                    borderRadius: BorderRadius.circular(16),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '프로필 사진',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '사진을 탭하여 변경하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
    );
  }



  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '프로필 사진 변경',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.black),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('카메라 기능은 향후 구현될 예정입니다.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('갤러리 기능은 향후 구현될 예정입니다.')),
                );
              },
            ),
            if (_profileImageUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('사진 삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  setState(() {
                    _profileImageUrl = '';
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final success = await ProfileService.saveProfile(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        profileImageUrl: _profileImageUrl.isNotEmpty ? _profileImageUrl : null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필이 저장되었습니다.'),
            backgroundColor: Colors.black,
          ),
        );
        Navigator.pop(context, true); // 저장 성공 신호
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 저장에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 