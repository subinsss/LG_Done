import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dx_project/data/character.dart';
import 'package:dx_project/data/task.dart';
import 'package:dx_project/services/character_ai_service.dart';
import 'package:dx_project/pages/task_page.dart';

class TaskRecommendationPage extends StatefulWidget {
  final Character character;

  const TaskRecommendationPage({super.key, required this.character});

  @override
  State<TaskRecommendationPage> createState() => _TaskRecommendationPageState();
}

class _TaskRecommendationPageState extends State<TaskRecommendationPage> {
  List<Task> _recommendedTasks = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }
  
  // 현재 로그인한 사용자 정보 가져오기
  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadRecommendations();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인이 필요합니다';
      });
    }
  }

  // 추천 작업 로드
  Future<void> _loadRecommendations() async {
    if (_userId == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 완료된 작업 데이터 가져오기
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('uid', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final completedTasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList();

      // Character AI 서비스를 통해 추천 받기
      final recommendations = await CharacterAIService.getRecommendedTasks(
        widget.character,
        _userId!,
        completedTasks,
        limit: 5,
      );

      setState(() {
        _recommendedTasks = recommendations;
        _isLoading = false;
      });

      // 분석 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'task_recommendations_loaded',
        parameters: {
          'character_id': widget.character.id,
          'count': recommendations.length,
        },
      );
    } catch (e) {
      print('추천 작업 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '추천 작업을 불러오는 중 오류가 발생했습니다';
      });
    }
  }

  // 작업을 Firestore에 추가
  Future<void> _addTaskToCollection(Task task) async {
    try {
      // Firestore에 작업 추가
      await FirebaseFirestore.instance.collection('tasks').add(task.toMap());

      // 성공 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\'${task.title}\' 작업이 추가되었습니다'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 분석 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'task_recommendation_added',
        parameters: {
          'character_id': widget.character.id,
          'task_title': task.title,
          'task_duration': task.duration,
        },
      );
    } catch (e) {
      // 오류 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('작업을 추가하는 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('작업 추가 중 오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.character.name}의 추천 작업',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isLoading ? null : _loadRecommendations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildRecommendationsList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _userId != null ? _loadRecommendations : null,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsList() {
    if (_recommendedTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: Colors.amber.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              '추천할 작업이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '더 많은 작업을 완료하면 더 나은 추천을 받을 수 있습니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRecommendations,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recommendedTasks.length + 1, // 헤더 포함
      itemBuilder: (context, index) {
        // 헤더
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildCharacterAvatar(widget.character, 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.character.name}의 추천 작업',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '당신의 활동 패턴을 분석하여 생산성 향상에 도움이 될 작업을 추천합니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
            ],
          );
        }

        // 추천 작업 카드
        final task = _recommendedTasks[index - 1];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${task.duration}분',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    task.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        // 작업 편집 페이지로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskPage(task: task),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('편집'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _addTaskToCollection(task),
                      icon: const Icon(Icons.add),
                      label: const Text('추가하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // 캐릭터 아바타 생성
  Widget _buildCharacterAvatar(Character character, double size) {
    // 실제 이미지를 사용하는 것이 좋지만, 현재는 단순히 이니셜로 대체
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blueGrey, // 캐릭터마다 다른 색상을 지정할 수 있음
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          character.name.substring(0, 1),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 