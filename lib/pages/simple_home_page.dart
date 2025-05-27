import 'package:flutter/material.dart';
import 'dart:async';
import '../services/hardware_service.dart';
import '../widgets/local_ml_widget.dart';

class SimpleHomePage extends StatefulWidget {
  const SimpleHomePage({super.key});

  @override
  State<SimpleHomePage> createState() => _SimpleHomePageState();
}

class _SimpleHomePageState extends State<SimpleHomePage> {
  // 할일 목록
  final List<TodoItem> _todos = [
    TodoItem(title: '프로젝트 회의 참석', isCompleted: false, priority: 'high'),
    TodoItem(title: '운동하기', isCompleted: true, priority: 'medium'),
    TodoItem(title: 'Flutter 공부', isCompleted: false, priority: 'high'),
    TodoItem(title: '독서 1시간', isCompleted: false, priority: 'low'),
  ];

  // 할일 추가 컨트롤러
  final TextEditingController _todoController = TextEditingController();
  String _selectedPriority = 'medium';

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
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
  }

  // 할일 삭제
  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
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

  Widget _buildCharacterImage() {
    int completedCount = _todos.where((todo) => todo.isCompleted).length;
    double completionRate = _todos.isEmpty ? 0 : completedCount / _todos.length;
    
    String characterEmoji;
    String statusText;
    
    if (completionRate >= 0.8) {
      characterEmoji = '🎉';
      statusText = '완벽해요!';
    } else if (completionRate >= 0.5) {
      characterEmoji = '💪';
      statusText = '열심히 하고 있어요!';
    } else if (completionRate > 0) {
      characterEmoji = '🌱';
      statusText = '시작이 좋아요!';
    } else {
      characterEmoji = '😊';
      statusText = '새로운 하루!';
    }

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
        children: [
          Text(
            characterEmoji,
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '완료율: ${(completionRate * 100).toInt()}%',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    int totalTodos = _todos.length;
    int completedTodos = _todos.where((todo) => todo.isCompleted).length;
    int pendingTodos = totalTodos - completedTodos;

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
          const Text(
            '📊 오늘의 성과',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '전체 할일',
                  totalTodos.toString(),
                  Colors.blue.shade400,
                  Icons.list_alt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '완료',
                  completedTodos.toString(),
                  Colors.green.shade400,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '남은 할일',
                  pendingTodos.toString(),
                  Colors.orange.shade400,
                  Icons.pending,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTodoManagement() {
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
                '✅ 할일 관리',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddTodoDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_todos.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '아직 할일이 없어요!\n새로운 할일을 추가해보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                final todo = _todos[index];
                return _buildTodoItem(todo, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(TodoItem todo, int index) {
    Color priorityColor;
    switch (todo.priority) {
      case 'high':
        priorityColor = Colors.red.shade400;
        break;
      case 'medium':
        priorityColor = Colors.orange.shade400;
        break;
      case 'low':
        priorityColor = Colors.green.shade400;
        break;
      default:
        priorityColor = Colors.grey.shade400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: todo.isCompleted ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: todo.isCompleted ? Colors.grey.shade200 : priorityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleTodo(index),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: todo.isCompleted ? Colors.green.shade400 : Colors.transparent,
                border: Border.all(
                  color: todo.isCompleted ? Colors.green.shade400 : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: todo.isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: todo.isCompleted ? Colors.grey.shade500 : Colors.black87,
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    todo.priority == 'high' ? '높음' : todo.priority == 'medium' ? '보통' : '낮음',
                    style: TextStyle(
                      fontSize: 10,
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteTodo(index),
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
              size: 20,
            ),
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int completedCount = _todos.where((todo) => todo.isCompleted).length;
    double completionRate = _todos.isEmpty ? 0 : completedCount / _todos.length;
    
    // 할일 데이터를 Map 형식으로 변환
    List<Map<String, dynamic>> todosData = _todos.map((todo) => {
      'title': todo.title,
      'isCompleted': todo.isCompleted,
      'priority': todo.priority,
    }).toList();

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
            
            // 로컬 ML 위젯
            LocalMLWidget(
              todos: todosData,
              completionRate: completionRate,
              totalTodos: _todos.length,
              completedTodos: completedCount,
              studyTimeMinutes: 60, // 기본값
              currentMood: completionRate > 0.7 ? 'happy' : completionRate > 0.4 ? 'working' : 'encouraging',
            ),
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

