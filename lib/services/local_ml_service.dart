import 'dart:convert';
import 'dart:io';
import 'dart:math';

class LocalMLService {
  // 싱글톤 패턴
  static final LocalMLService _instance = LocalMLService._internal();
  factory LocalMLService() => _instance;
  LocalMLService._internal();

  // ML 모델 경로
  static const String _mlModelPath = 'lib/ml_models';
  
  // Python 스크립트 실행 (Windows 환경)
  Future<Map<String, dynamic>?> _runPythonScript(String script, Map<String, dynamic> data) async {
    try {
      // 임시 데이터 파일 생성
      final tempDir = Directory.systemTemp;
      final inputFile = File('${tempDir.path}/ml_input.json');
      final outputFile = File('${tempDir.path}/ml_output.json');
      
      // 입력 데이터 저장
      await inputFile.writeAsString(jsonEncode(data));
      
      // Python 스크립트 실행
      final result = await Process.run(
        'python',
        [script, inputFile.path, outputFile.path],
        workingDirectory: Directory.current.path,
      );
      
      if (result.exitCode == 0 && await outputFile.exists()) {
        final outputData = await outputFile.readAsString();
        return jsonDecode(outputData);
      }
      
      print('Python 스크립트 실행 실패: ${result.stderr}');
      return null;
    } catch (e) {
      print('ML 스크립트 실행 오류: $e');
      return null;
    }
  }

  // 생산성 피드백 생성 (로컬 로직 사용)
  Future<MLFeedbackResponse> getProductivityFeedback({
    required List<Map<String, dynamic>> todos,
    required double completionRate,
    required int totalTodos,
    required int completedTodos,
    required int studyTimeMinutes,
    required String currentMood,
  }) async {
    try {
      // 간단한 로컬 ML 로직 (실제 모델 대신)
      final analysis = _analyzeProductivity(
        completionRate: completionRate,
        totalTodos: totalTodos,
        completedTodos: completedTodos,
        studyTimeMinutes: studyTimeMinutes,
        currentMood: currentMood,
      );
      
      return MLFeedbackResponse(
        feedback: analysis['feedback'],
        productivityScore: analysis['productivityScore'],
        suggestions: List<String>.from(analysis['suggestions']),
        mood: analysis['mood'],
        analysis: analysis['details'],
      );
    } catch (e) {
      print('로컬 ML 피드백 생성 실패: $e');
      return _getDefaultFeedback(completionRate);
    }
  }

  // 생산성 예측
  Future<MLProductivityPrediction> getProductivityPrediction({
    required int currentHour,
    required int dayOfWeek,
    required double recentCompletionRate,
    required int recentStudyTime,
  }) async {
    try {
      final prediction = _predictProductivity(
        currentHour: currentHour,
        dayOfWeek: dayOfWeek,
        recentCompletionRate: recentCompletionRate,
        recentStudyTime: recentStudyTime,
      );
      
      return MLProductivityPrediction(
        predictedProductivity: prediction['predictedProductivity'],
        recommendation: prediction['recommendation'],
        optimalStudyTime: prediction['optimalStudyTime'],
        factors: List<String>.from(prediction['factors']),
      );
    } catch (e) {
      print('생산성 예측 실패: $e');
      return _getDefaultPrediction();
    }
  }

  // 스마트 추천
  Future<MLSmartRecommendation> getSmartRecommendation({
    required List<Map<String, dynamic>> todos,
    required String currentMood,
    required int availableTimeMinutes,
  }) async {
    try {
      final recommendation = _generateSmartRecommendation(
        todos: todos,
        currentMood: currentMood,
        availableTimeMinutes: availableTimeMinutes,
      );
      
      return MLSmartRecommendation(
        recommendedTask: recommendation['recommendedTask'],
        estimatedTime: recommendation['estimatedTime'],
        reason: recommendation['reason'],
        confidence: recommendation['confidence'],
      );
    } catch (e) {
      print('스마트 추천 생성 실패: $e');
      return _getDefaultRecommendation(todos);
    }
  }

  // 로컬 생산성 분석 로직
  Map<String, dynamic> _analyzeProductivity({
    required double completionRate,
    required int totalTodos,
    required int completedTodos,
    required int studyTimeMinutes,
    required String currentMood,
  }) {
    final random = Random();
    
    // 기본 생산성 점수 계산
    double baseScore = completionRate;
    
    // 시간 요소 고려
    double timeBonus = (studyTimeMinutes / 120.0).clamp(0.0, 1.0) * 0.2;
    
    // 기분 요소 고려
    double moodMultiplier = _getMoodMultiplier(currentMood);
    
    double finalScore = (baseScore + timeBonus) * moodMultiplier;
    finalScore = finalScore.clamp(0.0, 1.0);
    
    // 피드백 생성
    String feedback;
    String mood;
    List<String> suggestions;
    
    if (finalScore >= 0.8) {
      feedback = "🎉 훌륭한 성과입니다! 오늘 정말 생산적인 하루를 보내고 계시네요. 이 페이스를 유지하면서 적절한 휴식도 잊지 마세요.";
      mood = "excellent";
      suggestions = [
        "현재의 좋은 페이스 유지하기",
        "성취감을 만끽하며 적절한 휴식 취하기",
        "내일을 위한 계획 세우기"
      ];
    } else if (finalScore >= 0.6) {
      feedback = "👍 좋은 진전이에요! 목표 달성까지 조금만 더 집중하면 될 것 같습니다. 화이팅!";
      mood = "good";
      suggestions = [
        "우선순위가 높은 작업부터 처리하기",
        "25분 집중 + 5분 휴식 패턴 적용",
        "작은 목표들로 나누어 성취감 높이기"
      ];
    } else if (finalScore >= 0.4) {
      feedback = "💪 아직 시작 단계네요. 작은 것부터 차근차근 해보는 건 어떨까요? 천천히 리듬을 만들어가세요.";
      mood = "encouraging";
      suggestions = [
        "가장 쉬운 작업부터 시작하기",
        "작업 환경 정리하고 집중력 높이기",
        "동기부여가 되는 음악이나 영상 활용"
      ];
    } else {
      feedback = "🤗 오늘은 좀 힘든 하루인가요? 괜찮아요, 누구에게나 그런 날이 있어요. 무리하지 말고 천천히 시작해봐요.";
      mood = "gentle";
      suggestions = [
        "충분한 휴식과 수면 취하기",
        "스트레스 해소 활동하기",
        "내일을 위한 간단한 계획만 세우기"
      ];
    }
    
    return {
      'feedback': feedback,
      'productivityScore': finalScore,
      'suggestions': suggestions,
      'mood': mood,
      'details': {
        'baseScore': baseScore,
        'timeBonus': timeBonus,
        'moodMultiplier': moodMultiplier,
        'studyTimeMinutes': studyTimeMinutes,
        'completionRate': completionRate,
      }
    };
  }

  // 생산성 예측 로직
  Map<String, dynamic> _predictProductivity({
    required int currentHour,
    required int dayOfWeek,
    required double recentCompletionRate,
    required int recentStudyTime,
  }) {
    final random = Random();
    
    // 시간대별 생산성 패턴
    double timeProductivity;
    String timeRecommendation;
    int optimalTime;
    
    if (currentHour >= 9 && currentHour <= 11) {
      timeProductivity = 0.85 + random.nextDouble() * 0.1;
      timeRecommendation = "오전 시간대는 집중력이 가장 높은 골든타임입니다!";
      optimalTime = 90;
    } else if (currentHour >= 14 && currentHour <= 16) {
      timeProductivity = 0.75 + random.nextDouble() * 0.1;
      timeRecommendation = "오후 시간대, 적당한 난이도의 작업에 적합합니다.";
      optimalTime = 60;
    } else if (currentHour >= 19 && currentHour <= 21) {
      timeProductivity = 0.65 + random.nextDouble() * 0.1;
      timeRecommendation = "저녁 시간대, 복습이나 가벼운 작업을 추천합니다.";
      optimalTime = 45;
    } else {
      timeProductivity = 0.45 + random.nextDouble() * 0.1;
      timeRecommendation = "휴식이 필요한 시간대입니다. 무리하지 마세요.";
      optimalTime = 30;
    }
    
    // 요일별 조정
    double dayMultiplier = _getDayMultiplier(dayOfWeek);
    double finalProductivity = (timeProductivity * dayMultiplier).clamp(0.0, 1.0);
    
    return {
      'predictedProductivity': finalProductivity,
      'recommendation': timeRecommendation,
      'optimalStudyTime': optimalTime,
      'factors': ['시간대 패턴', '요일 효과', '개인 학습 리듬', '최근 성과']
    };
  }

  // 스마트 추천 로직
  Map<String, dynamic> _generateSmartRecommendation({
    required List<Map<String, dynamic>> todos,
    required String currentMood,
    required int availableTimeMinutes,
  }) {
    // 미완료 작업 필터링
    final incompleteTodos = todos.where((todo) => !(todo['isCompleted'] ?? false)).toList();
    
    // 건강 관리 추천 확인
    final healthRecommendation = _getHealthRecommendation();
    if (healthRecommendation != null) {
      return healthRecommendation;
    }
    
    if (incompleteTodos.isEmpty) {
      return {
        'recommendedTask': '새로운 할일 추가하기',
        'estimatedTime': 5,
        'reason': '모든 작업을 완료했습니다! 새로운 목표를 설정해보세요.',
        'confidence': 0.9
      };
    }
    
    // 현재 시간대 분석
    final now = DateTime.now();
    final hour = now.hour;
    final timeCategory = _getTimeCategory(hour);
    
    // 우선순위별 분류 (높음 → 보통 → 낮음 순서로 정렬)
    final highPriority = incompleteTodos.where((todo) => todo['priority'] == 'high').toList();
    final mediumPriority = incompleteTodos.where((todo) => todo['priority'] == 'medium').toList();
    final lowPriority = incompleteTodos.where((todo) => todo['priority'] == 'low').toList();
    
    Map<String, dynamic> selectedTask;
    String reason;
    double confidence;
    int estimatedTime;
    
    // 시간대와 기분을 종합적으로 고려한 추천
    if (timeCategory == 'morning' && (currentMood == 'happy' || currentMood == 'working')) {
      // 오전 + 좋은 컨디션: 가장 중요한 작업 우선
      if (highPriority.isNotEmpty) {
        selectedTask = _selectBestTask(highPriority, availableTimeMinutes);
        reason = "오전 집중력이 높은 시간! 가장 중요한 작업을 처리하세요.";
        confidence = 0.9;
        estimatedTime = (availableTimeMinutes * 0.8).round();
      } else if (mediumPriority.isNotEmpty) {
        selectedTask = _selectBestTask(mediumPriority, availableTimeMinutes);
        reason = "오전 시간을 활용해 중요한 작업을 완료해보세요.";
        confidence = 0.8;
        estimatedTime = (availableTimeMinutes * 0.7).round();
      } else {
        selectedTask = _selectBestTask(lowPriority, availableTimeMinutes);
        reason = "가벼운 작업으로 하루를 시작해보세요.";
        confidence = 0.7;
        estimatedTime = (availableTimeMinutes * 0.5).round();
      }
    } else if (timeCategory == 'afternoon') {
      // 오후: 우선순위 높은 것부터, 하지만 시간 고려
      if (highPriority.isNotEmpty && availableTimeMinutes >= 45) {
        selectedTask = _selectBestTask(highPriority, availableTimeMinutes);
        reason = "오후 시간을 활용해 중요한 작업을 마무리하세요.";
        confidence = 0.8;
        estimatedTime = (availableTimeMinutes * 0.7).round();
      } else if (mediumPriority.isNotEmpty) {
        selectedTask = _selectBestTask(mediumPriority, availableTimeMinutes);
        reason = "오후에 적합한 중간 난이도 작업을 추천합니다.";
        confidence = 0.8;
        estimatedTime = (availableTimeMinutes * 0.6).round();
      } else if (lowPriority.isNotEmpty) {
        selectedTask = _selectBestTask(lowPriority, availableTimeMinutes);
        reason = "가벼운 작업으로 오후를 마무리해보세요.";
        confidence = 0.7;
        estimatedTime = (availableTimeMinutes * 0.5).round();
      } else {
        selectedTask = _selectBestTask(highPriority, availableTimeMinutes);
        reason = "중요한 작업이지만 차근차근 진행해보세요.";
        confidence = 0.6;
        estimatedTime = (availableTimeMinutes * 0.8).round();
      }
    } else if (timeCategory == 'evening') {
      // 저녁: 가벼운 작업 우선, 하지만 중요한 것이 급하면 그것부터
      if (highPriority.isNotEmpty && _isUrgentTask(highPriority)) {
        selectedTask = _selectBestTask(highPriority, availableTimeMinutes);
        reason = "급한 중요 작업이 있습니다. 집중해서 처리하세요.";
        confidence = 0.85;
        estimatedTime = (availableTimeMinutes * 0.6).round();
      } else if (lowPriority.isNotEmpty) {
        selectedTask = _selectBestTask(lowPriority, availableTimeMinutes);
        reason = "저녁 시간, 가벼운 작업으로 하루를 마무리하세요.";
        confidence = 0.8;
        estimatedTime = (availableTimeMinutes * 0.5).round();
      } else if (mediumPriority.isNotEmpty) {
        selectedTask = _selectBestTask(mediumPriority, availableTimeMinutes);
        reason = "적당한 난이도의 작업으로 마무리해보세요.";
        confidence = 0.7;
        estimatedTime = (availableTimeMinutes * 0.6).round();
      } else {
        selectedTask = _selectBestTask(highPriority, availableTimeMinutes);
        reason = "중요한 작업이지만 무리하지 말고 진행하세요.";
        confidence = 0.6;
        estimatedTime = (availableTimeMinutes * 0.7).round();
      }
    } else {
      // 늦은 시간: 간단한 작업만
      if (lowPriority.isNotEmpty) {
        selectedTask = _selectBestTask(lowPriority, availableTimeMinutes);
        reason = "늦은 시간이니 간단한 작업만 하세요.";
        confidence = 0.9;
        estimatedTime = (availableTimeMinutes * 0.4).round();
      } else if (mediumPriority.isNotEmpty && availableTimeMinutes <= 30) {
        selectedTask = _selectBestTask(mediumPriority, availableTimeMinutes);
        reason = "짧은 시간 안에 할 수 있는 작업을 추천합니다.";
        confidence = 0.7;
        estimatedTime = (availableTimeMinutes * 0.5).round();
      } else if (highPriority.isNotEmpty && _isUrgentTask(highPriority)) {
        selectedTask = _selectBestTask(highPriority, availableTimeMinutes);
        reason = "급한 작업이지만 무리하지 마세요.";
        confidence = 0.6;
        estimatedTime = (availableTimeMinutes * 0.5).round();
      } else {
        return {
          'recommendedTask': '휴식하기',
          'estimatedTime': 15,
          'reason': '늦은 시간입니다. 충분한 휴식을 취하세요.',
          'confidence': 0.9
        };
      }
    }
    
    // 기분에 따른 추가 조정
    if (currentMood == 'tired') {
      estimatedTime = (estimatedTime * 0.7).round();
      reason += " (컨디션을 고려해 짧게 진행하세요)";
    } else if (currentMood == 'happy' || currentMood == 'working') {
      confidence = (confidence * 1.1).clamp(0.0, 1.0);
    }
    
    return {
      'recommendedTask': selectedTask['title'] ?? '작업',
      'estimatedTime': estimatedTime.clamp(10, availableTimeMinutes),
      'reason': reason,
      'confidence': confidence
    };
  }

  // 건강 관리 추천
  Map<String, dynamic>? _getHealthRecommendation() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    // 물 마시기 추천 (2시간마다)
    if (minute >= 0 && minute <= 5) {
      if (hour == 9 || hour == 11 || hour == 14 || hour == 16 || hour == 19) {
        return {
          'recommendedTask': '💧 물 마시기',
          'estimatedTime': 2,
          'reason': '수분 보충 시간입니다! 건강한 하루를 위해 물을 마셔보세요.',
          'confidence': 0.95
        };
      }
    }
    
    // 스트레칭 추천 (오후 3시, 저녁 8시)
    if (minute >= 0 && minute <= 10) {
      if (hour == 15) {
        return {
          'recommendedTask': '🤸‍♀️ 간단한 스트레칭',
          'estimatedTime': 5,
          'reason': '오후 피로를 풀어주는 스트레칭 시간입니다!',
          'confidence': 0.9
        };
      } else if (hour == 20) {
        return {
          'recommendedTask': '🧘‍♀️ 목과 어깨 스트레칭',
          'estimatedTime': 5,
          'reason': '하루 종일 쌓인 피로를 풀어주는 스트레칭을 해보세요.',
          'confidence': 0.9
        };
      }
    }
    
    // 눈 휴식 추천 (1시간마다)
    if (minute >= 30 && minute <= 35) {
      if (hour >= 9 && hour <= 21) {
        return {
          'recommendedTask': '👀 눈 휴식하기',
          'estimatedTime': 3,
          'reason': '20-20-20 법칙: 20초간 20피트(6m) 떨어진 곳을 바라보세요.',
          'confidence': 0.85
        };
      }
    }
    
    // 심호흡 추천 (스트레스 해소)
    if (minute >= 45 && minute <= 50) {
      if (hour == 12 || hour == 18) {
        return {
          'recommendedTask': '🌬️ 심호흡하기',
          'estimatedTime': 3,
          'reason': '깊은 심호흡으로 마음을 진정시키고 에너지를 충전하세요.',
          'confidence': 0.8
        };
      }
    }
    
    // 점심시간 추천
    if (hour == 12 && minute >= 0 && minute <= 30) {
      return {
        'recommendedTask': '🍽️ 점심 식사',
        'estimatedTime': 30,
        'reason': '점심시간입니다! 영양가 있는 식사로 에너지를 보충하세요.',
        'confidence': 0.95
      };
    }
    
    // 저녁 식사 추천
    if (hour == 18 && minute >= 0 && minute <= 30) {
      return {
        'recommendedTask': '🍽️ 저녁 식사',
        'estimatedTime': 30,
        'reason': '저녁 식사 시간입니다! 하루를 마무리하는 건강한 식사를 하세요.',
        'confidence': 0.95
      };
    }
    
    return null; // 건강 추천이 없을 때
  }

  // 시간대 분류
  String _getTimeCategory(int hour) {
    if (hour >= 6 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 18) {
      return 'afternoon';
    } else if (hour >= 18 && hour < 22) {
      return 'evening';
    } else {
      return 'late';
    }
  }

  // 가장 적합한 작업 선택 (시간 고려)
  Map<String, dynamic> _selectBestTask(List<Map<String, dynamic>> tasks, int availableTime) {
    if (tasks.isEmpty) return {};
    
    // 예상 시간이 있는 작업 우선 고려
    final suitableTasks = tasks.where((task) {
      final estimatedMinutes = task['estimatedMinutes'] ?? 30;
      return estimatedMinutes <= availableTime;
    }).toList();
    
    if (suitableTasks.isNotEmpty) {
      // 가장 최근에 생성된 작업 우선
      suitableTasks.sort((a, b) {
        final aTime = a['createdAt'] as DateTime? ?? DateTime.now();
        final bTime = b['createdAt'] as DateTime? ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return suitableTasks.first;
    }
    
    // 적합한 작업이 없으면 가장 최근 작업
    tasks.sort((a, b) {
      final aTime = a['createdAt'] as DateTime? ?? DateTime.now();
      final bTime = b['createdAt'] as DateTime? ?? DateTime.now();
      return bTime.compareTo(aTime);
    });
    return tasks.first;
  }

  // 긴급한 작업인지 확인
  bool _isUrgentTask(List<Map<String, dynamic>> tasks) {
    final now = DateTime.now();
    return tasks.any((task) {
      final createdAt = task['createdAt'] as DateTime? ?? now;
      final hoursSinceCreated = now.difference(createdAt).inHours;
      return hoursSinceCreated > 24; // 24시간 이상 된 작업은 긴급
    });
  }

  // 헬퍼 메서드들
  double _getMoodMultiplier(String mood) {
    switch (mood) {
      case 'happy': return 1.2;
      case 'working': return 1.1;
      case 'encouraging': return 0.9;
      case 'tired': return 0.7;
      default: return 1.0;
    }
  }

  double _getDayMultiplier(int dayOfWeek) {
    // 1=월요일, 7=일요일
    switch (dayOfWeek) {
      case 1: case 2: case 3: return 1.1; // 월화수
      case 4: case 5: return 1.0; // 목금
      case 6: case 7: return 0.8; // 토일
      default: return 1.0;
    }
  }

  // 기본값 반환 메서드들
  MLFeedbackResponse _getDefaultFeedback(double completionRate) {
    return MLFeedbackResponse(
      feedback: "오늘도 수고하셨어요! 꾸준히 노력하는 모습이 멋집니다.",
      productivityScore: completionRate,
      suggestions: ["꾸준한 노력 계속하기", "적절한 휴식 취하기"],
      mood: "neutral",
      analysis: {},
    );
  }

  MLProductivityPrediction _getDefaultPrediction() {
    return MLProductivityPrediction(
      predictedProductivity: 0.7,
      recommendation: "현재 시간대에 적합한 작업을 선택해보세요.",
      optimalStudyTime: 60,
      factors: ["시간대", "개인 패턴"],
    );
  }

  MLSmartRecommendation _getDefaultRecommendation(List<Map<String, dynamic>> todos) {
    final incompleteTodos = todos.where((todo) => !(todo['isCompleted'] ?? false)).toList();
    
    if (incompleteTodos.isNotEmpty) {
      final randomTodo = incompleteTodos[Random().nextInt(incompleteTodos.length)];
      return MLSmartRecommendation(
        recommendedTask: randomTodo['title'] ?? '작업',
        estimatedTime: 30,
        reason: "남은 작업 중 하나를 선택했습니다.",
        confidence: 0.6,
      );
    }
    
    return MLSmartRecommendation(
      recommendedTask: '새로운 할일 추가하기',
      estimatedTime: 5,
      reason: '모든 작업을 완료했습니다!',
      confidence: 0.9,
    );
  }
}

// 데이터 모델들
class MLFeedbackResponse {
  final String feedback;
  final double productivityScore;
  final List<String> suggestions;
  final String mood;
  final Map<String, dynamic> analysis;

  MLFeedbackResponse({
    required this.feedback,
    required this.productivityScore,
    required this.suggestions,
    required this.mood,
    required this.analysis,
  });
}

class MLProductivityPrediction {
  final double predictedProductivity;
  final String recommendation;
  final int optimalStudyTime;
  final List<String> factors;

  MLProductivityPrediction({
    required this.predictedProductivity,
    required this.recommendation,
    required this.optimalStudyTime,
    required this.factors,
  });
}

class MLSmartRecommendation {
  final String recommendedTask;
  final int estimatedTime;
  final String reason;
  final double confidence;

  MLSmartRecommendation({
    required this.recommendedTask,
    required this.estimatedTime,
    required this.reason,
    required this.confidence,
  });
} 