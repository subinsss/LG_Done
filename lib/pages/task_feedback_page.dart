import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dx_project/data/character.dart';
import 'package:dx_project/data/task.dart';
import 'package:dx_project/services/character_ai_service.dart';

class TaskFeedbackPage extends StatefulWidget {
  final Character character;
  final Task? task; // 선택적으로 특정 작업에 대한 피드백을 요청하는 경우

  const TaskFeedbackPage({
    super.key, 
    required this.character, 
    this.task,
  });

  @override
  State<TaskFeedbackPage> createState() => _TaskFeedbackPageState();
}

class _TaskFeedbackPageState extends State<TaskFeedbackPage> {
  List<Task> _tasks = [];
  Task? _selectedTask;
  bool _isLoading = true;
  bool _isFeedbackLoading = false;
  String _errorMessage = '';
  String _feedback = '';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    
    // 이미 작업이 선택된 경우
    if (widget.task != null) {
      _selectedTask = widget.task;
    }
  }
  
  // 현재 로그인한 사용자 정보 가져오기
  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadTasks();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인이 필요합니다';
      });
    }
  }

  // 사용자의 작업 목록 로드
  Future<void> _loadTasks() async {
    if (_userId == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 작업 데이터 가져오기 (완료되지 않은 작업)
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('uid', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final loadedTasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _tasks = loadedTasks;
        _isLoading = false;
        
        // 이미 작업이 선택되어 있는 경우 (widget.task가 있는 경우) 피드백 요청
        if (_selectedTask != null) {
          _requestFeedback();
        }
      });
    } catch (e) {
      print('작업 목록 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '작업 목록을 불러오는 중 오류가 발생했습니다';
      });
    }
  }

  // 피드백 요청
  Future<void> _requestFeedback() async {
    if (_userId == null || _selectedTask == null) return;
    
    setState(() {
      _isFeedbackLoading = true;
      _feedback = '';
    });

    try {
      // 완료된 작업 데이터 가져오기 (과거 데이터 분석용)
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('uid', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final completedTasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList();

      // Character AI 서비스를 통해 피드백 받기
      final feedback = await CharacterAIService.getTaskFeedback(
        widget.character,
        _selectedTask!,
        completedTasks,
      );

      setState(() {
        _feedback = feedback;
        _isFeedbackLoading = false;
      });

      // 분석 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'task_feedback_requested',
        parameters: {
          'character_id': widget.character.id,
          'task_id': _selectedTask!.id,
          'task_title': _selectedTask!.title,
        },
      );
    } catch (e) {
      print('피드백 요청 중 오류 발생: $e');
      setState(() {
        _isFeedbackLoading = false;
        _feedback = '피드백을 요청하는 중 오류가 발생했습니다. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.character.name}의 작업 피드백',
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
            onPressed: _isLoading ? null : _loadTasks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildTaskFeedbackView(),
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
            onPressed: _userId != null ? _loadTasks : null,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskFeedbackView() {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              '피드백을 받을 작업이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '먼저 작업을 추가한 후 피드백을 요청해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 캐릭터 정보 헤더
          Row(
            children: [
              _buildCharacterAvatar(widget.character, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.character.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${widget.character.characterType} 유형',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 안내 메시지
          if (_selectedTask == null) ...[
            const Text(
              '피드백을 받을 작업을 선택하세요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '작업에 대한 분석과 개선 방안을 AI 캐릭터가 제공합니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // 작업 드롭다운 선택
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Task>(
                isExpanded: true,
                hint: const Text('작업 선택'),
                value: _selectedTask,
                items: _tasks.map((task) {
                  return DropdownMenuItem<Task>(
                    value: task,
                    child: Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (Task? value) {
                  setState(() {
                    _selectedTask = value;
                    if (value != null) {
                      _requestFeedback();
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // 선택된 작업 정보 (있는 경우)
          if (_selectedTask != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.task_alt, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedTask!.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedTask!.duration}분',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedTask!.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _selectedTask!.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 피드백 섹션
            const Text(
              '피드백',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: _isFeedbackLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            '${widget.character.name}의 피드백을 기다리는 중...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _feedback.isEmpty
                      ? Center(
                          child: Text(
                            '피드백을 요청해주세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildCharacterAvatar(widget.character, 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.character.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _feedback,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ],
      ),
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