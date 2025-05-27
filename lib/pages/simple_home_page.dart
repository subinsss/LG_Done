import 'package:flutter/material.dart';
import 'dart:async';
import '../services/hardware_service.dart';

class SimpleHomePage extends StatefulWidget {
  const SimpleHomePage({super.key});

  @override
  State<SimpleHomePage> createState() => _SimpleHomePageState();
}

class _SimpleHomePageState extends State<SimpleHomePage> {
  // AI 서비스
  final AIService _aiService = AIService();
  bool _isServerConnected = false;
  
  // AI 피드백 데이터
  AIFeedbackResponse? _currentFeedback;
  bool _isLoadingFeedback = false;

  // 할일 목록
  List<TodoItem> _todos = [
    TodoItem(title: '프로젝트 회의 참석', isCompleted: false, priority: 'high'),
    TodoItem(title: '운동하기', isCompleted: true, priority: 'medium'),
    TodoItem(title: 'Flutter 공부', isCompleted: false, priority: 'high'),
    TodoItem(title: '독서 1시간', isCompleted: false, priority: 'low'),
  ];

  // 할일 추가 컨트롤러
  final TextEditingController _todoController = TextEditingController();
  String _selectedPriority = 'medium';

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
    _loadAIFeedback();
  }

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  // 서버 연결 상태 확인
  Future<void> _checkServerConnection() async {
    final isConnected = await _aiService.checkConnection();
    setState(() {
      _isServerConnected = isConnected;
    });
  }

  // AI 피드백 로드
  Future<void> _loadAIFeedback() async {
    setState(() {
      _isLoadingFeedback = true;
    });

    int completedCount = _todos.where((todo) => todo.isCompleted).length;
    double completionRate = _todos.isEmpty ? 0 : (completedCount / _todos.length) * 100;

    // 할일 데이터를 TodoData 형식으로 변환
    List<TodoData> todoData = _todos.map((todo) => TodoData(
      title: todo.title,
      isCompleted: todo.isCompleted,
      priority: todo.priority,
      createdAt: DateTime.now(),
    )).toList();

    AIFeedbackResponse? feedback;
    
    if (_isServerConnected) {
      // 서버에서 AI 피드백 받아오기
      feedback = await _aiService.getAIFeedback(
        todos: todoData,
        completionRate: completionRate,
        totalTodos: _todos.length,
        completedTodos: completedCount,
      );
    }
    
    // 서버 연결 실패 시 기본 피드백 사용
    feedback ??= AIFeedbackResponse.getDefaultFeedback(completionRate);

    setState(() {
      _currentFeedback = feedback;
      _isLoadingFeedback = false;
    });
  }

  // 할일 토글
  void _toggleTodo(int index) {
    setState(() {
      _todos[index] = TodoItem(
        title: _todos[index].title,
        isCompleted: !_todos[index].isCompleted,
        priority: _todos[index].priority,
      );
    });
    
    // 할일 상태 변경 시 AI 피드백 새로고침
    _loadAIFeedback();
  }

  // 할일 삭제
  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
    
    // 할일 삭제 시 AI 피드백 새로고침
    _loadAIFeedback();
  }

  // 할일 추가
  void _addTodo() {
    if (_todoController.text.trim().isEmpty) return;
    
    setState(() {
      _todos.add(TodoItem(
        title: _todoController.text.trim(),
        isCompleted: false,
        priority: _selectedPriority,
      ));
    });
    
    _todoController.clear();
    Navigator.of(context).pop();
    
    // 할일 추가 시 AI 피드백 새로고침
    _loadAIFeedback();
  }

  // 할일 추가 다이얼로그
  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 할일 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _todoController,
              decoration: const InputDecoration(
                hintText: '할일을 입력하세요',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(
                labelText: '우선순위',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'high', child: Text('높음')),
                DropdownMenuItem(value: 'medium', child: Text('보통')),
                DropdownMenuItem(value: 'low', child: Text('낮음')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPriority = value!;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: _addTodo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isServerConnected ? Colors.pink.shade400 : Colors.red.shade400,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isServerConnected ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            _isServerConnected ? 'AI 서버 연결됨' : 'AI 서버 연결 안됨',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterImage() {
    String emoji = '😊';
    Color backgroundColor = Colors.pink.shade100;
    String statusText = '준비 완료!';
    
    // AI 피드백이 있으면 해당 이모지 사용
    if (_currentFeedback != null) {
      emoji = _currentFeedback!.emoji;
      statusText = _currentFeedback!.title;
      
      switch (_currentFeedback!.mood) {
        case 'happy':
          backgroundColor = Colors.green.shade100;
          break;
        case 'encouraging':
          backgroundColor = Colors.orange.shade100;
          break;
        case 'motivating':
          backgroundColor = Colors.blue.shade100;
          break;
        default:
          backgroundColor = Colors.pink.shade100;
      }
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, backgroundColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 캐릭터 이미지
          Text(
            emoji,
            style: const TextStyle(fontSize: 100),
          ),
          const SizedBox(height: 15),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          _buildConnectionStatus(),
        ],
      ),
    );
  }

  Widget _buildTodoManagement() {
    int completedCount = _todos.where((todo) => todo.isCompleted).length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '💕 할일 관리',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '$completedCount/${_todos.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showAddTodoDialog,
                    icon: Icon(Icons.add_circle, color: Colors.pink.shade400),
                    tooltip: '할일 추가',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          // 진행률 바
          LinearProgressIndicator(
            value: _todos.isEmpty ? 0 : completedCount / _todos.length,
            backgroundColor: Colors.pink.shade50,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.pink.shade400),
            minHeight: 6,
          ),
          const SizedBox(height: 15),
          
          // 할일 목록
          if (_todos.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '할일을 추가해보세요!',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_todos.asMap().entries.map((entry) {
              int index = entry.key;
              TodoItem todo = entry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: Key('todo_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (direction) => _deleteTodo(index),
                  child: GestureDetector(
                    onTap: () => _toggleTodo(index),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: todo.isCompleted ? Colors.grey.shade50 : Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: todo.isCompleted ? Colors.grey.shade200 : Colors.pink.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // 체크박스
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: todo.isCompleted ? Colors.pink.shade400 : Colors.transparent,
                              border: Border.all(
                                color: todo.isCompleted ? Colors.pink.shade400 : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: todo.isCompleted
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          
                          // 할일 제목
                          Expanded(
                            child: Text(
                              todo.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                color: todo.isCompleted ? Colors.grey.shade600 : Colors.black87,
                              ),
                            ),
                          ),
                          
                          // 우선순위 표시
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getPriorityColor(todo.priority),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red.shade400;
      case 'medium':
        return Colors.orange.shade400;
      case 'low':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  Widget _buildQuickStats() {
    int completedCount = _todos.where((todo) => todo.isCompleted).length;
    double completionRate = _todos.isEmpty ? 0 : (completedCount / _todos.length) * 100;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade300, Colors.pink.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💖 오늘의 성과',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${completionRate.toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIFeedback() {
    if (_isLoadingFeedback) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AI가 분석 중이에요...'),
            ],
          ),
        ),
      );
    }

    final feedback = _currentFeedback ?? AIFeedbackResponse.getDefaultFeedback(0);
    Color feedbackColor = _getFeedbackColor(feedback.mood);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    feedback.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '🤖 AI 피드백',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadAIFeedback,
                icon: Icon(
                  Icons.refresh,
                  color: Colors.pink.shade400,
                ),
                tooltip: '피드백 새로고침',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: feedbackColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: feedbackColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: feedbackColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  feedback.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                if (feedback.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '💡 제안사항:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...feedback.suggestions.map((suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: feedbackColor)),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getFeedbackColor(String mood) {
    switch (mood) {
      case 'happy':
        return Colors.green.shade400;
      case 'encouraging':
        return Colors.orange.shade400;
      case 'motivating':
        return Colors.blue.shade400;
      case 'gentle':
        return Colors.purple.shade400;
      default:
        return Colors.pink.shade400;
    }
  }

  Widget _buildServerStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isServerConnected ? Colors.pink.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isServerConnected ? Colors.pink.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isServerConnected ? Icons.cloud_done : Icons.cloud_off,
            color: _isServerConnected ? Colors.pink.shade600 : Colors.red.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isServerConnected ? 'AI 서버 연결됨 💕' : 'AI 서버 연결 안됨 😢',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isServerConnected ? Colors.pink.shade700 : Colors.red.shade700,
                  ),
                ),
                Text(
                  _isServerConnected 
                    ? 'Flask AI 서버와 연결되어 있어요!'
                    : 'localhost:5000 또는 Colab 서버를 확인해주세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isServerConnected ? Colors.pink.shade600 : Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text(
          '🌸 ThinQ 홈',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.pink.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await _checkServerConnection();
              _loadAIFeedback();
            },
            icon: const Icon(Icons.refresh),
            tooltip: '상태 새로고침',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 캐릭터 이미지
            _buildCharacterImage(),
            const SizedBox(height: 25),
            
            // 오늘의 성과
            _buildQuickStats(),
            const SizedBox(height: 25),
            
            // 할일 관리
            _buildTodoManagement(),
            const SizedBox(height: 25),
            
            // AI 피드백
            _buildAIFeedback(),
            const SizedBox(height: 20),
            
            // 서버 연결 상태
            _buildServerStatus(),
          ],
        ),
      ),
    );
  }
}

class TodoItem {
  final String title;
  final bool isCompleted;
  final String priority; // high, medium, low
  
  TodoItem({
    required this.title, 
    required this.isCompleted,
    this.priority = 'medium',
  });
} 