import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ThinQ/data/character.dart';
import 'package:ThinQ/data/chat_message.dart';
import 'package:ThinQ/data/task.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class CharacterAIService {
  // Character.AI API URL (실제로는 Character.AI의 API 엔드포인트로 대체해야 함)
  // 현재는 Character.AI의 공식 API가 없기 때문에 OpenAI API를 대체 예시로 사용
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // API 키는 Firebase Remote Config에서 가져옴
  static String get _apiKey => FirebaseRemoteConfig.instance.getString('openai_api_key');
  
  // 캐릭터에게 메시지 보내기
  static Future<String> sendMessage(Character character, String userMessage, 
      {List<ChatMessage>? chatHistory}) async {
    try {
      final messages = _buildMessages(character, userMessage, chatHistory);
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4', // Character.AI를 사용할 경우 이 부분을 변경
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final replyContent = data['choices'][0]['message']['content'];
        return replyContent;
      } else {
        throw Exception('AI 서비스에 연결할 수 없습니다: ${response.statusCode}');
      }
    } catch (e) {
      print('메시지 전송 중 오류 발생: $e');
      return _getDefaultResponse(character, userMessage);
    }
  }
  
  // 캐릭터에게 할 일 추천 요청
  static Future<List<Task>> getRecommendedTasks(
      Character character, String userId, List<Task> completedTasks, {int limit = 3}) async {
    try {
      // 사용자의 완료된 작업 분석
      final String tasksAnalysis = _analyzeCompletedTasks(completedTasks);
      
      final messages = [
        {'role': 'system', 'content': character.persona},
        {
          'role': 'user',
          'content': '사용자의 완료된 작업 목록입니다:\n$tasksAnalysis\n\n이 데이터를 바탕으로 사용자에게 추천할 작업 $limit개를 JSON 형식으로 생성해주세요. 각 작업은 title, description, duration(분)을 포함해야 합니다.'
        }
      ];
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4', // Character.AI를 사용할 경우 이 부분을 변경
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // JSON 문자열 추출 (AI 응답에서 JSON 부분만 파싱)
        final jsonRegex = RegExp(r'```json\n([\s\S]*?)\n```|(\{[\s\S]*\})');
        final match = jsonRegex.firstMatch(content);
        final jsonString = match?.group(1) ?? match?.group(2) ?? '[]';
        
        // JSON 파싱
        List<dynamic> tasksJson;
        try {
          tasksJson = jsonDecode(jsonString.trim());
        } catch (e) {
          tasksJson = jsonDecode('[$jsonString]');
        }
        
        if (tasksJson is! List) {
          tasksJson = [tasksJson];
        }
        
        // Task 객체로 변환
        final recommendedTasks = tasksJson.map((taskData) {
          return Task(
            id: 'recommended_${DateTime.now().millisecondsSinceEpoch}_${tasksJson.indexOf(taskData)}',
            uid: userId,
            title: taskData['title'] ?? '추천 작업',
            description: taskData['description'] ?? '',
            duration: taskData['duration'] ?? 25,
            isCompleted: false,
            createdAt: DateTime.now(),
          );
        }).toList();
        
        return recommendedTasks;
      } else {
        throw Exception('AI 서비스에 연결할 수 없습니다: ${response.statusCode}');
      }
    } catch (e) {
      print('추천 작업 생성 중 오류 발생: $e');
      // 오류 발생 시 기본 추천 작업 반환
      return _getDefaultRecommendations(userId, character, limit);
    }
  }
  
  // 할 일에 대한 피드백 요청
  static Future<String> getTaskFeedback(
      Character character, Task task, List<Task> completedTasks) async {
    try {
      final String tasksAnalysis = _analyzeCompletedTasks(completedTasks);
      
      final messages = [
        {'role': 'system', 'content': character.persona},
        {
          'role': 'user',
          'content': '다음 작업에 대한 피드백이 필요합니다:\n\n제목: ${task.title}\n설명: ${task.description}\n예상 소요시간: ${task.duration}분\n\n사용자의 과거 작업 이력:\n$tasksAnalysis\n\n이 작업을 효과적으로 수행하기 위한 조언과 피드백을 제공해주세요.'
        }
      ];
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4', // Character.AI를 사용할 경우 이 부분을 변경
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content;
      } else {
        throw Exception('AI 서비스에 연결할 수 없습니다: ${response.statusCode}');
      }
    } catch (e) {
      print('피드백 생성 중 오류 발생: $e');
      // 오류 발생 시 기본 피드백 반환
      return _getDefaultFeedback(character, task);
    }
  }
  
  // 메시지 배열 구성 (시스템 메시지 + 채팅 기록 + 사용자 메시지)
  static List<Map<String, String>> _buildMessages(
      Character character, String userMessage, List<ChatMessage>? chatHistory) {
    final List<Map<String, String>> messages = [];
    
    // 시스템 메시지 (캐릭터 페르소나)
    messages.add({
      'role': 'system',
      'content': character.persona,
    });
    
    // 채팅 기록이 있는 경우 추가 (너무 길면 최근 10개만)
    if (chatHistory != null && chatHistory.isNotEmpty) {
      final recentHistory = chatHistory.length > 10 
          ? chatHistory.sublist(chatHistory.length - 10) 
          : chatHistory;
      
      for (final message in recentHistory) {
        messages.add({
          'role': message.isUserMessage ? 'user' : 'assistant',
          'content': message.content,
        });
      }
    }
    
    // 새로운 사용자 메시지
    messages.add({
      'role': 'user',
      'content': userMessage,
    });
    
    return messages;
  }
  
  // 오류 발생 시 기본 응답
  static String _getDefaultResponse(Character character, String userMessage) {
    switch (character.characterType) {
      case 'ENFJ':
        return '안녕하세요! 네트워크 연결이 불안정한 것 같네요. 하지만 걱정하지 마세요. 저는 당신의 목표를 달성하는 데 도움을 드릴 준비가 되어 있습니다. 조금 후에 다시 시도해 주시겠어요?';
      case 'INTJ':
        return '현재 네트워크 연결에 문제가 발생했습니다. 효율적인 작업을 위해 잠시 후 다시 시도해 주시기 바랍니다. 기술적 문제가 해결되는 대로, 최적화된 솔루션을 제공하겠습니다.';
      case 'INFP':
        return '마음의 소리가 잠시 연결되지 않고 있어요. 당신의 메시지가 얼마나 중요한지 알고 있어요. 곧 다시 연결되면, 당신의 이야기에 귀 기울일 준비가 되어 있답니다. 조금만 기다려 주실래요?';
      default:
        return '네트워크 연결에 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
  
  // 완료된 작업을 분석하여 텍스트로 변환
  static String _analyzeCompletedTasks(List<Task> tasks) {
    if (tasks.isEmpty) {
      return '아직 완료된 작업이 없습니다.';
    }
    
    // 작업 카테고리 분석
    final Map<String, int> categories = {};
    int totalDuration = 0;
    
    for (final task in tasks) {
      totalDuration += task.duration;
      
      // 간단한 카테고리화 (실제로는 더 정교한 방법 필요)
      final words = task.title.toLowerCase().split(' ');
      for (final word in words) {
        if (word.length > 3) { // 짧은 단어 무시
          categories[word] = (categories[word] ?? 0) + 1;
        }
      }
    }
    
    // 가장 자주 사용된 키워드 추출
    final sortedCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topCategories = sortedCategories.take(5).map((e) => e.key).toList();
    
    // 분석 결과 생성
    final sb = StringBuffer();
    sb.writeln('완료된 작업 수: ${tasks.length}');
    sb.writeln('총 소요 시간: $totalDuration분');
    sb.writeln('평균 작업 시간: ${(totalDuration / tasks.length).round()}분');
    sb.writeln('주요 키워드: ${topCategories.join(', ')}');
    sb.writeln('\n최근 작업:');
    
    // 최근 5개 작업 목록 추가
    final recentTasks = List<Task>.from(tasks)
      ..sort((a, b) => (b.createdAt as DateTime).compareTo(a.createdAt as DateTime));
    
    for (int i = 0; i < recentTasks.length && i < 5; i++) {
      final task = recentTasks[i];
      sb.writeln('- ${task.title} (${task.duration}분): ${task.description}');
    }
    
    return sb.toString();
  }
  
  // 기본 추천 작업 생성 (AI가 실패할 경우 사용)
  static List<Task> _getDefaultRecommendations(String userId, Character character, int limit) {
    final Map<String, List<Map<String, dynamic>>> characterTasks = {
      'ENFJ': [
        {
          'title': '오늘의 목표 설정하기',
          'description': '오늘 달성하고 싶은 3가지 주요 목표를 설정하고 우선순위를 정해보세요.',
          'duration': 15
        },
        {
          'title': '팀원들과 소통하기',
          'description': '함께 일하는 동료나 팀원들에게 격려의 메시지를 보내보세요.',
          'duration': 10
        },
        {
          'title': '감사 일기 쓰기',
          'description': '오늘 감사했던 3가지 일을 기록하며 긍정적인 마인드를 유지하세요.',
          'duration': 15
        }
      ],
      'INTJ': [
        {
          'title': '작업 효율성 분석하기',
          'description': '지난 주 완료한 작업들을 분석하고 효율성을 개선할 방법을 찾아보세요.',
          'duration': 25
        },
        {
          'title': '지식 확장하기',
          'description': '관심 분야의 최신 논문이나 아티클을 읽고 인사이트를 정리해보세요.',
          'duration': 30
        },
        {
          'title': '장기 프로젝트 계획 수립하기',
          'description': '진행 중인 프로젝트의 다음 단계를 계획하고 마일스톤을 설정하세요.',
          'duration': 20
        }
      ],
      'INFP': [
        {
          'title': '창작 시간 갖기',
          'description': '자유롭게 생각을 표현할 수 있는 창작 활동을 해보세요 (글쓰기, 그림 등).',
          'duration': 30
        },
        {
          'title': '명상하기',
          'description': '조용한 환경에서 10분간 명상을 통해 내면의 목소리에 집중해보세요.',
          'duration': 10
        },
        {
          'title': '영감 찾기',
          'description': '좋아하는 예술 작품이나 영감을 주는 콘텐츠를 감상하고 느낀 점을 기록해보세요.',
          'duration': 25
        }
      ]
    };
    
    // 캐릭터 타입에 맞는 추천 작업 또는 기본 추천 작업
    final recommendations = characterTasks[character.characterType] ?? [
      {
        'title': '중요한 일 25분 집중하기',
        'description': '가장 중요한 작업을 선택하고 25분간 방해 없이 집중해보세요.',
        'duration': 25
      },
      {
        'title': '휴식 시간 갖기',
        'description': '5분간 스트레칭하고 물을 마시세요.',
        'duration': 5
      },
      {
        'title': '오늘 할 일 계획하기',
        'description': '오늘 완료해야 할 3가지 중요한 작업을 선택하세요.',
        'duration': 15
      }
    ];
    
    return recommendations.take(limit).map((task) => Task(
      id: 'default_${DateTime.now().millisecondsSinceEpoch}_${recommendations.indexOf(task)}',
      uid: userId,
      title: task['title'] as String,
      description: task['description'] as String,
      duration: task['duration'] as int,
      isCompleted: false,
      createdAt: DateTime.now(),
    )).toList();
  }
  
  // 기본 피드백 생성 (AI가 실패할 경우 사용)
  static String _getDefaultFeedback(Character character, Task task) {
    switch (character.characterType) {
      case 'ENFJ':
        return '이 작업은 당신의 목표 달성에 중요한 역할을 할 것 같네요! ${task.duration}분이라는 시간은 충분히 집중할 수 있는 시간이에요. 시작하기 전에 명확한 목표를 설정하고, 작업이 끝난 후 무엇을 성취했는지 기록해보는 건 어떨까요? 함께라면 분명 훌륭하게 해낼 수 있을 거예요!';
      case 'INTJ':
        return '이 작업에 대한 분석 결과, 최적의 수행을 위해서는 방해 요소를 최소화하는 것이 중요합니다. ${task.duration}분의 시간을 가장 효율적으로 활용하려면, 명확한 목표와 단계별 접근법을 미리 설정하는 것이 좋겠습니다. 작업 완료 후 성과를 측정하고 다음 작업에 개선점을 반영하세요.';
      case 'INFP':
        return '이 작업이 당신에게 어떤 의미인지 생각해보셨나요? ${task.duration}분 동안 당신만의 창의적인 관점으로 접근해보세요. 가끔은 기존의 방식에서 벗어나 새로운 시도를 해보는 것도 좋답니다. 작업을 마친 후, 그 과정에서 느낀 감정이나 얻은 깨달음을 기록해두면 더욱 의미 있는 경험이 될 거예요.';
      default:
        return '이 작업을 ${task.duration}분 내에 효과적으로 완료하기 위해서는 집중력이 중요합니다. 방해 요소를 최소화하고, 작업을 시작하기 전에 목표를 명확히 설정하세요. 작업이 끝난 후에는 성과를 평가하고 다음 단계를 계획해보세요.';
    }
  }
} 