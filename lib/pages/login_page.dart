import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/pages/feed_page.dart';
import 'package:ThinQ/pages/signup_page.dart';
import 'package:ThinQ/widgets/barrier_progress_indicator.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BarrierProgressIndicator(
      isActive: _isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F2F3),
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Image.asset(
                  'assets/ThinQ_logo.png',
                  width: 200,
                ),
                Container(height: 70),
                _buildEmailField(),
                Container(height: 16),
                _buildPasswordField(),
                Container(height: 16),
                _buildLoginButton(context),
                Container(height: 56),
                const Spacer(),
                _buildSignUpButton(context),
                Container(height: 40),
              ],
            ),
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
        _signIn(context);
      },
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 로그인 처리
        _signIn(context);
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
          '로그인',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 회원가입 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return SignUpPage();
            },
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            width: 1,
            color: Colors.black26,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '회원 가입',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    final String email = _emailController.text;
    final String password = _passwordController.text;

    try {
      setState(() => _isLoading = true);

      // FirebaseAuth 인증 처리
      final UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print(credential.user?.displayName);

      // Google Analytics 이벤트 로깅
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');

      // 로그인 성공 시 피드 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return FeedPage();
          },
        ),
      );
    } catch (e) {
      // 에러 처리
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.'),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
