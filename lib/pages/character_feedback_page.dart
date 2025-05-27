import 'package:flutter/material.dart';
import 'dart:math';

class CharacterFeedbackPage extends StatefulWidget {
  const CharacterFeedbackPage({super.key});

  @override
  State<CharacterFeedbackPage> createState() => _CharacterFeedbackPageState();
}

class _CharacterFeedbackPageState extends State<CharacterFeedbackPage> with TickerProviderStateMixin {
  late AnimationController _characterController;
  late Animation<double> _characterAnimation;
  
  String _currentMood = 'happy'; // happy, encouraging, proud, concerned
  String _feedbackMessage = '';
  List<String> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _characterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _characterAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _characterController, curve: Curves.elasticOut),
    );
    
    _generateFeedback();
    _characterController.forward();
  }

  @override
  void dispose() {
    _characterController.dispose();
    super.dispose();
  }

  void _generateFeedback() {
    setState(() {
      _isLoading = true;
    });

    // 실제로는 서버에서 통계 데이터를 분석하여 피드백 생성
    Future.delayed(const Duration(seconds: 2), () {
      _analyzeDailyPerformance();
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _analyzeDailyPerformance() {
    // 가상의 통계 데이터 분석
    int todayStudyTime = 85; // 분
    int completedTasks = 8;
    int totalTasks = 12;
    double completionRate = completedTasks / totalTasks;

    if (completionRate >= 0.8 && todayStudyTime >= 60) {
      _currentMood = 'proud';
      _feedbackMessage = '와! 오늘 정말 대단했어요! 🌟\n목표를 거의 달성하고 집중도 잘 하셨네요. 이런 페이스를 유지하면 곧 큰 성과를 볼 수 있을 거예요!';
      _suggestions = [
        '내일도 이 리듬을 유지해보세요',
        '완료한 작업들을 되돌아보며 성취감을 느껴보세요',
        '충분한 휴식도 잊지 마세요',
      ];
    } else if (completionRate >= 0.6 || todayStudyTime >= 45) {
      _currentMood = 'encouraging';
      _feedbackMessage = '좋은 진전이에요! 💪\n꾸준히 노력하고 계시는 모습이 보여요. 조금만 더 집중하면 목표 달성이 가능할 것 같아요!';
      _suggestions = [
        '작은 목표부터 차근차근 완료해보세요',
        '25분 집중 + 5분 휴식 패턴을 시도해보세요',
        '가장 중요한 할일부터 먼저 처리해보세요',
      ];
    } else {
      _currentMood = 'concerned';
      _feedbackMessage = '오늘은 조금 힘드셨나요? 😊\n괜찮아요, 누구에게나 그런 날이 있어요. 내일은 새로운 시작이니까 너무 걱정하지 마세요!';
      _suggestions = [
        '목표를 조금 더 작게 나누어보세요',
        '방해 요소들을 제거해보세요',
        '충분한 수면과 휴식을 취하세요',
        '동기부여가 되는 음악이나 환경을 만들어보세요',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '🤖 AI 피드백',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _generateFeedback,
            icon: const Icon(Icons.refresh),
            tooltip: '새로운 피드백',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildFeedbackView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '🤔',
                style: TextStyle(fontSize: 60),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI가 당신의 학습 패턴을 분석 중...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 캐릭터 카드
          _buildCharacterCard(),
          const SizedBox(height: 20),
          
          // 피드백 메시지
          _buildFeedbackCard(),
          const SizedBox(height: 20),
          
          // 개선 제안
          _buildSuggestionsCard(),
          const SizedBox(height: 20),
          
          // 격려 메시지
          _buildEncouragementCard(),
        ],
      ),
    );
  }

  Widget _buildCharacterCard() {
    String emoji = _getCharacterEmoji();
    Color backgroundColor = _getCharacterColor();
    
    return AnimatedBuilder(
      animation: _characterAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _characterAnimation.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor.withOpacity(0.8), backgroundColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 12),
                Text(
                  _getCharacterName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCharacterRole(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.indigo.shade400,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '오늘의 피드백',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _feedbackMessage,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '개선 제안',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._suggestions.asMap().entries.map((entry) {
            int index = entry.key;
            String suggestion = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEncouragementCard() {
    List<String> quotes = [
      '"작은 진전도 진전이다. 포기하지 마세요!" 💪',
      '"오늘의 노력이 내일의 성공을 만듭니다." ✨',
      '"완벽하지 않아도 괜찮아요. 꾸준함이 더 중요해요." 🌱',
      '"당신은 생각보다 훨씬 강한 사람이에요!" 🦋',
      '"한 걸음씩, 천천히. 그것이 성공의 비결입니다." 🚀',
    ];
    
    String randomQuote = quotes[Random().nextInt(quotes.length)];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade100, Colors.purple.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite,
            color: Colors.pink.shade400,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            '오늘의 격려',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            randomQuote,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getCharacterEmoji() {
    switch (_currentMood) {
      case 'proud':
        return '🌟';
      case 'encouraging':
        return '💪';
      case 'concerned':
        return '🤗';
      default:
        return '😊';
    }
  }

  Color _getCharacterColor() {
    switch (_currentMood) {
      case 'proud':
        return Colors.amber.shade400;
      case 'encouraging':
        return Colors.green.shade400;
      case 'concerned':
        return Colors.blue.shade400;
      default:
        return Colors.indigo.shade400;
    }
  }

  String _getCharacterName() {
    switch (_currentMood) {
      case 'proud':
        return 'AI 멘토 스타';
      case 'encouraging':
        return 'AI 코치 파이팅';
      case 'concerned':
        return 'AI 친구 케어';
      default:
        return 'AI 도우미';
    }
  }

  String _getCharacterRole() {
    switch (_currentMood) {
      case 'proud':
        return '성취를 축하하는 멘토';
      case 'encouraging':
        return '동기부여 전문 코치';
      case 'concerned':
        return '따뜻한 마음의 친구';
      default:
        return '학습 도우미';
    }
  }
} 