import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PremiumSubscriptionPage extends StatefulWidget {
  const PremiumSubscriptionPage({super.key});

  @override
  State<PremiumSubscriptionPage> createState() => _PremiumSubscriptionPageState();
}

class _PremiumSubscriptionPageState extends State<PremiumSubscriptionPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // 분석 이벤트 기록
    FirebaseAnalytics.instance.logEvent(
      name: 'premium_page_viewed',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프리미엄 구독'),
        backgroundColor: Colors.amber.shade100,
        foregroundColor: Colors.amber.shade900,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 프리미엄 배너
              _buildPremiumBanner(),
              
              const SizedBox(height: 24),
              
              // 프리미엄 혜택 목록
              _buildPremiumBenefits(),
              
              const SizedBox(height: 32),
              
              // 구독 옵션
              _buildSubscriptionOption(),
              
              const SizedBox(height: 32),
              
              // 구독 버튼
              _buildSubscribeButton(),
              
              const SizedBox(height: 16),
              
              // 약관 동의 텍스트
              Center(
                child: Text(
                  '구독 시 이용약관 및 개인정보 처리방침에 동의하게 됩니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 프리미엄 배너 위젯
  Widget _buildPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade200.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Colors.amber,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'ThinQ 프리미엄',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '모든 기능과 컨텐츠를 제한 없이 이용하세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // 혜택 목록 위젯
  Widget _buildPremiumBenefits() {
    final benefits = [
      {
        'icon': Icons.chat_bubble,
        'title': '모든 AI 캐릭터',
        'description': '프리미엄 전용 AI 캐릭터를 포함한 모든 캐릭터 이용 가능',
      },
      {
        'icon': Icons.style,
        'title': '캐릭터 커스터마이징',
        'description': '프로필 이미지 업로드 및 모든 커스터마이징 아이템 사용 가능',
      },
      {
        'icon': Icons.insights,
        'title': '고급 분석 및 추천',
        'description': '심층적인 작업 분석 및 AI의 고품질 추천 제공',
      },
      {
        'icon': Icons.support_agent,
        'title': '우선 지원',
        'description': '질문 및 요청사항에 대한 우선적인 지원',
      },
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '프리미엄 혜택',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...benefits.map((benefit) => _buildBenefitItem(
          icon: benefit['icon'] as IconData,
          title: benefit['title'] as String,
          description: benefit['description'] as String,
        )),
      ],
    );
  }
  
  // 혜택 아이템 위젯
  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.amber.shade800,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 구독 옵션 위젯
  Widget _buildSubscriptionOption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.amber.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '월간 구독',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '₩9,900',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
              Text(
                '/월',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              '매월 자동 결제됩니다. 언제든지 취소 가능합니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 구독 버튼 위젯
  Widget _buildSubscribeButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _onSubscribe,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              '구독하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
  
  // 구독 처리 메서드
  Future<void> _onSubscribe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 여기에 실제 결제 로직을 구현 (외부 결제 서비스 연동 등)
      // 예시로는 데이터베이스에 직접 업데이트하는 방식으로 구현
      
      // 분석 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'premium_subscription_started',
        parameters: {
          'price': 9900,
          'currency': 'KRW',
          'subscription_type': 'monthly',
        },
      );
      
      // 결제 성공 가정
      await Future.delayed(const Duration(seconds: 2));
      
      // 사용자 프로필에 프리미엄 상태 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isPremium': true,
        'premiumExpiresAt': DateTime.now().add(const Duration(days: 30)),
        'subscriptionAmount': 9900,
      });
      
      // 결제 성공 후 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프리미엄 구독이 시작되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true); // 성공 결과와 함께 이전 화면으로 돌아가기
      }
    } catch (e) {
      print('구독 처리 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구독 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 