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
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI 기반 피드백',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '내장 ML 모델 기반 분석',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // AI 분석 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _getMLAnalysis,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.psychology),
                  label: Text(_isLoading ? 'AI 분석 중...' : 'AI 분석 시작'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 분석 결과 표시
              if (_feedback != null) ...[
                _buildFeedbackSection(),
                const SizedBox(height: 16),
              ],

              if (_prediction != null) ...[
                _buildPredictionSection(),
                const SizedBox(height: 16),
              ],

              if (_recommendation != null) ...[
                _buildRecommendationSection(),
              ],

              // 초기 상태 메시지
              if (_feedback == null && _prediction == null && _recommendation == null && !_isLoading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 48,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '위 버튼을 눌러 AI 분석을 시작하세요!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '로컬 ML 모델이 당신의 생산성을 분석합니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
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
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback_outlined, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text(
                '생산성 피드백',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 16,
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
          
          // 생산성 점수 표시
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                const Text(
                  '생산성 점수: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${(_feedback!.productivityScore * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _feedback!.productivityScore > 0.7
                        ? Colors.grey.shade800
                        : _feedback!.productivityScore > 0.4
                            ? Colors.grey.shade600
                            : Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 60,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _feedback!.productivityScore,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _feedback!.productivityScore > 0.7
                            ? Colors.grey.shade800
                            : _feedback!.productivityScore > 0.4
                                ? Colors.grey.shade600
                                : Colors.grey.shade500,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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
    );
  }

  Widget _buildPredictionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text(
                '생산성 예측',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 16,
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
                    color: Colors.white,
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
                    color: Colors.white,
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
    );
  }

  Widget _buildRecommendationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.recommend, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text(
                '스마트 추천',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
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
    );
  }
} 