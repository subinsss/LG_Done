import 'package:flutter/material.dart';
import '../services/local_ml_service.dart';

class LocalMLWidget extends StatefulWidget {
  final List<Map<String, dynamic>> todos;
  final double completionRate;
  final int totalTodos;
  final int completedTodos;
  final int studyTimeMinutes;
  final String currentMood;

  const LocalMLWidget({
    super.key,
    required this.todos,
    required this.completionRate,
    required this.totalTodos,
    required this.completedTodos,
    required this.studyTimeMinutes,
    required this.currentMood,
  });

  @override
  State<LocalMLWidget> createState() => _LocalMLWidgetState();
}

class _LocalMLWidgetState extends State<LocalMLWidget> {
  final LocalMLService _mlService = LocalMLService();
  MLFeedbackResponse? _feedback;
  MLProductivityPrediction? _prediction;
  MLSmartRecommendation? _recommendation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 위젯이 생성되면 자동으로 분석 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getMLAnalysis();
    });
  }

  @override
  void didUpdateWidget(LocalMLWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 할일 데이터가 변경되면 자동으로 재분석
    if (oldWidget.todos != widget.todos ||
        oldWidget.completionRate != widget.completionRate ||
        oldWidget.totalTodos != widget.totalTodos ||
        oldWidget.completedTodos != widget.completedTodos) {
      
      // 약간의 지연을 두고 재분석 (너무 빈번한 분석 방지)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _getMLAnalysis();
        }
      });
    }
  }

  Future<void> _getMLAnalysis() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 병렬로 ML 분석 실행
      final results = await Future.wait([
        _mlService.getProductivityFeedback(
          todos: widget.todos,
          completionRate: widget.completionRate,
          totalTodos: widget.totalTodos,
          completedTodos: widget.completedTodos,
          studyTimeMinutes: widget.studyTimeMinutes,
          currentMood: widget.currentMood,
        ),
        _mlService.getProductivityPrediction(
          currentHour: DateTime.now().hour,
          dayOfWeek: DateTime.now().weekday,
          recentCompletionRate: widget.completionRate,
          recentStudyTime: widget.studyTimeMinutes,
        ),
        _mlService.getSmartRecommendation(
          todos: widget.todos,
          currentMood: widget.currentMood,
          availableTimeMinutes: 60,
        ),
      ]);

      setState(() {
        _feedback = results[0] as MLFeedbackResponse;
        _prediction = results[1] as MLProductivityPrediction;
        _recommendation = results[2] as MLSmartRecommendation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ML 분석 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 로딩 상태 표시 (첫 로딩 시에만)
        if (_isLoading && _feedback == null && _prediction == null && _recommendation == null) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
                const SizedBox(height: 16),
                Text(
                  'AI가 생산성을 분석 중입니다...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // 재분석 중일 때 상단에 작은 로딩 바 표시
        if (_isLoading && (_feedback != null || _prediction != null || _recommendation != null)) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '업데이트 중...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // 각 섹션을 별도 카드로 분리
        if (_feedback != null) ...[
          _buildFeedbackCard(),
          const SizedBox(height: 8),
        ],

        if (_prediction != null) ...[
          _buildPredictionCard(),
          const SizedBox(height: 8),
        ],

        if (_recommendation != null) ...[
          _buildRecommendationCard(),
        ],
      ],
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
            Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade300, Colors.blue.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white, 
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '생산성 분석',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _feedback!.feedback,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            
            // 생산성 점수 표시 (개선된 디자인)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getScoreColor(_feedback!.productivityScore).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getScoreIcon(_feedback!.productivityScore), 
                              color: _getScoreColor(_feedback!.productivityScore), 
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '생산성 점수',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(_feedback!.productivityScore * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: _getScoreColor(_feedback!.productivityScore),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 개선된 프로그레스 바
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _feedback!.productivityScore,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getScoreColor(_feedback!.productivityScore),
                              _getScoreColor(_feedback!.productivityScore).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: _getScoreColor(_feedback!.productivityScore).withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getScoreDescription(_feedback!.productivityScore),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            if (_feedback!.suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'AI 제안사항:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              ...(_feedback!.suggestions.map((suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
            Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade300, Colors.green.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.timeline,
                    color: Colors.white, 
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '생산성 예측',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _prediction!.recommendation,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            
            // 예측 정보
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '예상 생산성',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_prediction!.predictedProductivity * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '최적 학습시간',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_prediction!.optimalStudyTime}분',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
            Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade300, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white, 
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '스마트 추천',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.task_alt, color: Colors.black, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '추천 작업',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _recommendation!.recommendedTask,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey.shade600, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '예상 시간: ${_recommendation!.estimatedTime}분',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.verified, color: Colors.grey.shade600, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '신뢰도: ${(_recommendation!.confidence * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            Text(
              _recommendation!.reason,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 헬퍼 메서드들
  Color _getScoreColor(double score) {
    if (score > 0.7) {
      return Colors.green.shade600;
    } else if (score > 0.4) {
      return Colors.orange.shade600;
    } else {
      return Colors.red.shade600;
    }
  }

  IconData _getScoreIcon(double score) {
    if (score > 0.7) {
      return Icons.trending_up;
    } else if (score > 0.4) {
      return Icons.trending_flat;
    } else {
      return Icons.trending_down;
    }
  }

  String _getScoreDescription(double score) {
    if (score > 0.7) {
      return '우수한 생산성을 보이고 있습니다!';
    } else if (score > 0.4) {
      return '보통 수준의 생산성입니다.';
    } else {
      return '생산성을 개선할 여지가 있습니다.';
    }
  }
} 