import 'dart:convert';
import 'package:http/http.dart' as http;

class HardwareService {
  static const String _baseUrl = 'http://localhost:8080/api'; // Spring Boot 서버 주소
  
  // 싱글톤 패턴
  static final HardwareService _instance = HardwareService._internal();
  factory HardwareService() => _instance;
  HardwareService._internal();

  // 하드웨어에서 타이머 상태 받아오기
  Future<TimerData?> getTimerData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/timer'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TimerData.fromJson(data);
      }
      return null;
    } catch (e) {
      print('타이머 데이터 받아오기 실패: $e');
      return null;
    }
  }

  // 캐릭터 상태 전송 (하드웨어로)
  Future<bool> sendCharacterState({
    required String mood, // happy, working, tired
    required String status, // 상태 메시지
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/character'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mood': mood,
          'status': status,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('캐릭터 상태 전송 실패: $e');
      return false;
    }
  }

  // 할일 진행률 전송 (하드웨어로)
  Future<bool> sendTodoProgress({
    required int totalTodos,
    required int completedTodos,
    required double progressPercentage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/todo-progress'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'totalTodos': totalTodos,
          'completedTodos': completedTodos,
          'progressPercentage': progressPercentage,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('할일 진행률 전송 실패: $e');
      return false;
    }
  }

  // 하드웨어 연결 상태 확인
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      print('하드웨어 연결 확인 실패: $e');
      return false;
    }
  }

  // 타이머 시작 명령 전송
  Future<bool> startTimer() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/timer/start'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('타이머 시작 명령 실패: $e');
      return false;
    }
  }

  // 타이머 정지 명령 전송
  Future<bool> stopTimer() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/timer/stop'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('타이머 정지 명령 실패: $e');
      return false;
    }
  }

  // 타이머 리셋 명령 전송
  Future<bool> resetTimer() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/timer/reset'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('타이머 리셋 명령 실패: $e');
      return false;
    }
  }
}

// 타이머 데이터 모델
class TimerData {
  final bool isRunning;
  final int seconds;
  final String formattedTime;
  final DateTime timestamp;

  TimerData({
    required this.isRunning,
    required this.seconds,
    required this.formattedTime,
    required this.timestamp,
  });

  factory TimerData.fromJson(Map<String, dynamic> json) {
    return TimerData(
      isRunning: json['isRunning'] ?? false,
      seconds: json['seconds'] ?? 0,
      formattedTime: json['formattedTime'] ?? '00:00',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  // 기본값 (연결 안될 때)
  static TimerData get defaultData => TimerData(
    isRunning: false,
    seconds: 0,
    formattedTime: '00:00',
    timestamp: DateTime.now(),
  );
}

class AIService {
  // Flask 서버 주소 (나중에 Colab ngrok URL로 변경)
  static const String _baseUrl = 'http://localhost:5000/api';
  
  // 싱글톤 패턴
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // AI 피드백 요청
  Future<AIFeedbackResponse?> getAIFeedback({
    required List<TodoData> todos,
    required double completionRate,
    required int totalTodos,
    required int completedTodos,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'todos': todos.map((todo) => todo.toJson()).toList(),
          'completion_rate': completionRate,
          'total_todos': totalTodos,
          'completed_todos': completedTodos,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AIFeedbackResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      print('AI 피드백 요청 실패: $e');
      return null;
    }
  }

  // 캐릭터 이미지 생성 요청
  Future<String?> generateCharacterImage({
    required String mood,
    required double completionRate,
    required String timeOfDay,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mood': mood,
          'completion_rate': completionRate,
          'time_of_day': timeOfDay,
          'style': 'cute_character',
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['image_url'];
      }
      return null;
    } catch (e) {
      print('이미지 생성 요청 실패: $e');
      return null;
    }
  }

  // 서버 연결 상태 확인
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      print('서버 연결 확인 실패: $e');
      return false;
    }
  }

  // 할일 데이터 분석 요청
  Future<TodoAnalysis?> analyzeTodos({
    required List<TodoData> todos,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analyze-todos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'todos': todos.map((todo) => todo.toJson()).toList(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TodoAnalysis.fromJson(data);
      }
      return null;
    } catch (e) {
      print('할일 분석 요청 실패: $e');
      return null;
    }
  }
}

// 할일 데이터 모델
class TodoData {
  final String title;
  final bool isCompleted;
  final String priority;
  final DateTime createdAt;

  TodoData({
    required this.title,
    required this.isCompleted,
    required this.priority,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'is_completed': isCompleted,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// AI 피드백 응답 모델
class AIFeedbackResponse {
  final String emoji;
  final String title;
  final String message;
  final String mood; // happy, encouraging, motivating, gentle
  final List<String> suggestions;
  final String? imageUrl;

  AIFeedbackResponse({
    required this.emoji,
    required this.title,
    required this.message,
    required this.mood,
    required this.suggestions,
    this.imageUrl,
  });

  factory AIFeedbackResponse.fromJson(Map<String, dynamic> json) {
    return AIFeedbackResponse(
      emoji: json['emoji'] ?? '😊',
      title: json['title'] ?? '좋은 하루예요!',
      message: json['message'] ?? '오늘도 화이팅!',
      mood: json['mood'] ?? 'encouraging',
      suggestions: List<String>.from(json['suggestions'] ?? []),
      imageUrl: json['image_url'],
    );
  }

  // 기본 피드백 (서버 연결 안될 때)
  static AIFeedbackResponse getDefaultFeedback(double completionRate) {
    if (completionRate >= 80) {
      return AIFeedbackResponse(
        emoji: '🎉',
        title: '정말 대단해요!',
        message: '오늘 할일의 ${completionRate.toInt()}%를 완료했네요! 이런 페이스를 유지하면 목표 달성이 확실해요!',
        mood: 'happy',
        suggestions: ['이 페이스를 유지하세요!', '자신에게 작은 보상을 주세요'],
      );
    } else if (completionRate >= 50) {
      return AIFeedbackResponse(
        emoji: '💪',
        title: '좋은 진전이에요!',
        message: '절반 이상 완료했어요! 조금만 더 힘내면 오늘 목표를 달성할 수 있을 거예요!',
        mood: 'encouraging',
        suggestions: ['남은 할일 중 가장 쉬운 것부터 시작해보세요', '잠깐 휴식을 취한 후 다시 도전하세요'],
      );
    } else if (completionRate > 0) {
      return AIFeedbackResponse(
        emoji: '🌱',
        title: '시작이 반이에요!',
        message: '좋은 시작이에요! 작은 성취도 큰 발걸음이 될 수 있어요. 하나씩 차근차근 해보세요!',
        mood: 'motivating',
        suggestions: ['작은 할일부터 차근차근 완료해보세요', '완료한 할일을 다시 한번 확인해보세요'],
      );
    } else {
      return AIFeedbackResponse(
        emoji: '🤗',
        title: '새로운 하루예요!',
        message: '오늘도 새로운 기회가 가득해요! 작은 할일부터 시작해서 성취감을 느껴보세요!',
        mood: 'gentle',
        suggestions: ['가장 간단한 할일부터 시작해보세요', '할일을 더 작은 단위로 나누어보세요'],
      );
    }
  }
}

// 할일 분석 결과 모델
class TodoAnalysis {
  final Map<String, int> priorityDistribution;
  final double averageCompletionTime;
  final List<String> productivityTips;
  final String overallTrend;

  TodoAnalysis({
    required this.priorityDistribution,
    required this.averageCompletionTime,
    required this.productivityTips,
    required this.overallTrend,
  });

  factory TodoAnalysis.fromJson(Map<String, dynamic> json) {
    return TodoAnalysis(
      priorityDistribution: Map<String, int>.from(json['priority_distribution'] ?? {}),
      averageCompletionTime: (json['average_completion_time'] ?? 0.0).toDouble(),
      productivityTips: List<String>.from(json['productivity_tips'] ?? []),
      overallTrend: json['overall_trend'] ?? 'stable',
    );
  }
} 