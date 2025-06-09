import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/pages/home_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nickNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _nickNameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _nickNameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F2F3),
      ),
      backgroundColor: const Color(0xFFF1F2F3),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Stack(
            children: [
              ListView(
                children: [
                  Image.asset(
                    'assets/done_logo.png',
                    width: 200,
                  ),
                  Container(height: 26),
                  Text(
                    '친구들의 사진과 동영상을 보려면\n가입하세요.',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Container(height: 46),
                  _buildEmailField(),
                  Container(height: 16),
                  _buildNickNameField(),
                  Container(height: 16),
                  _buildPasswordField(),
                  Container(height: 26),
                  _buildSignUpButton(context),
                  Container(height: 26),
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: '이메일',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(
            width: 1.0,
            color: Colors.black26,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(_nickNameFocusNode);
      },
    );
  }

  Widget _buildNickNameField() {
    return TextField(
      controller: _nickNameController,
      focusNode: _nickNameFocusNode,
      keyboardType: TextInputType.name,
      decoration: InputDecoration(
        hintText: '닉네임',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(
            width: 1.0,
            color: Colors.black26,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(_passwordFocusNode);
      },
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: true,
      decoration: InputDecoration(
        hintText: '비밀번호',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(
            width: 1.0,
            color: Colors.black26,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        _signUp(context);
      },
    );
  }

  Widget _buildSignUpButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 회원가입 처리
        _signUp(context);
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF2465D9),
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: const Text(
          '회원 가입',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _signUp(BuildContext context) async {
    try {
      setState(() => _isLoading = true);
      
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String nickName = _nickNameController.text.trim();

      // 입력 검증
      if (email.isEmpty || password.isEmpty || nickName.isEmpty) {
        throw '모든 필드를 입력해주세요.';
      }

      // 회원가입 처리
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      // 닉네임 업데이트 및 적용 대기
      await credential.user?.updateDisplayName(nickName);
      
      // Firebase에 변경사항 반영을 위해 현재 사용자 정보 다시 로드
      await FirebaseAuth.instance.currentUser?.reload();

      // Google Analytics 이벤트 로깅
      await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');

      // 로그인 성공 시 피드 화면으로 이동
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) {
            return HomePage();
          },
        ),
      );
    } catch (e) {
      // 오류 처리
      print('회원가입 오류 상세: $e');
      String errorMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
      
      if (e is FirebaseAuthException) {
        // Firebase Auth 오류 코드에 따른 메시지
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = '이미 사용 중인 이메일입니다.';
            break;
          case 'invalid-email':
            errorMessage = '올바른 이메일 형식이 아닙니다.';
            break;
          case 'weak-password':
            errorMessage = '비밀번호가 너무 약합니다. 6자 이상으로 설정해주세요.';
            break;
          case 'operation-not-allowed':
            errorMessage = '이메일/비밀번호 계정이 비활성화되어 있습니다.';
            break;
          default:
            errorMessage = '오류: ${e.message}';
        }
      } else if (e is String) {
        errorMessage = e;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
