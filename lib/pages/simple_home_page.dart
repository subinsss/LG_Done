import 'package:flutter/material.dart';
import 'dart:async';
import '../services/hardware_service.dart';
import '../services/firestore_todo_service.dart';
import '../services/external_server_service.dart';
import '../widgets/local_ml_widget.dart';

class SimpleHomePage extends StatefulWidget {
  const SimpleHomePage({super.key});

  @override
  State<SimpleHomePage> createState() => _SimpleHomePageState();
}

class _SimpleHomePageState extends State<SimpleHomePage> {
  // Firestore 서비스
  final FirestoreTodoService _firestoreService = FirestoreTodoService();
  
  // 할일 목록 (Firestore에서 실시간으로 받아옴)
  List<TodoItem> _todos = [];
  StreamSubscription<List<TodoItem>>? _todosSubscription;

  // 할일 추가 컨트롤러
  final TextEditingController _todoController = TextEditingController();
  String _selectedPriority = 'medium';

  @override
  void initState() {
    super.initState();
    _listenToTodos();
    _testServerConnection();
  }

  // 서버 연결 테스트
  void _testServerConnection() async {
    final isConnected = await ExternalServerService.testConnection();
    if (isConnected) {
      print('🎉 외부 서버 연결 성공!');
    } else {
      print('⚠️ 외부 서버 연결 실패');
    }
  }

  @override
  void dispose() {
    _todoController.dispose();
    _todosSubscription?.cancel();
    super.dispose();
  }

  // Firestore에서 할일 목록 실시간 구독
  void _listenToTodos() {
    _todosSubscription = _firestoreService.getTodosStream().listen(
      (todos) {
        setState(() {
          _todos = todos;
        });
      },
      onError: (error) {
        print('❌ 할일 목록 구독 오류: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('할일 목록을 불러오는데 실패했습니다: $error')),
        );
      },
    );
  }

  // 할일 토글 (Firestore 업데이트)
  Future<void> _toggleTodo(TodoItem todo) async {
    final success = await _firestoreService.toggleTodoCompletion(
      todo.id, 
      !todo.isCompleted
    );
    
    if (success) {
      // Firestore 성공 시 외부 서버에도 알림
      final updatedTodo = TodoItem(
        id: todo.id,
        title: todo.title,
        description: todo.description,
        isCompleted: !todo.isCompleted,
        priority: todo.priority,
        estimatedMinutes: todo.estimatedMinutes,
        createdAt: todo.createdAt,
        updatedAt: DateTime.now(),
        completedAt: !todo.isCompleted ? DateTime.now() : null,
        userId: todo.userId,
      );
      _notifyExternalServerUpdate(updatedTodo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 상태 변경에 실패했습니다')),
      );
    }
  }

  // 할일 삭제 (Firestore에서 삭제)
  Future<void> _deleteTodo(TodoItem todo) async {
    print('🗑️ 삭제 요청: ${todo.title} (ID: ${todo.id})');
    
    final success = await _firestoreService.deleteTodo(todo.id);
    
    if (success) {
      print('✅ Firestore 삭제 성공: ${todo.id}');
      // Firestore 성공 시 외부 서버에도 알림 (한 번만)
      _notifyExternalServerDelete(todo.id, todo.title);
    } else {
      print('❌ Firestore 삭제 실패: ${todo.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 삭제에 실패했습니다')),
      );
    }
  }

  // 할일 추가 (Firestore에 추가)
  Future<void> _addTodo() async {
    if (_todoController.text.trim().isEmpty) return;
    
    final todoId = await _firestoreService.addTodo(
      title: _todoController.text.trim(),
      priority: _selectedPriority,
    );
    
    if (todoId != null) {
      // Firestore 성공 시 외부 서버에도 알림 (실패해도 무시)
      _notifyExternalServer('create', _todoController.text.trim());
      
      _todoController.clear();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 추가에 실패했습니다')),
      );
    }
  }

  // 외부 서버 알림 (오류 무시)
  void _notifyExternalServer(String action, String data) {
    ExternalServerService.notifyServerSimple(action, data).catchError((error) {
      print('📤 외부 서버 알림 실패 (무시됨): $error');
    });
  }

  // 외부 서버 업데이트 알림
  void _notifyExternalServerUpdate(TodoItem todo) {
    ExternalServerService.sendTodoUpdate(todo).catchError((error) {
      print('📤 외부 서버 업데이트 알림 실패 (무시됨): $error');
    });
  }

  // 외부 서버 삭제 알림
  void _notifyExternalServerDelete(String todoId, String title) {
    ExternalServerService.sendTodoDelete(todoId, title).catchError((error) {
      print('📤 외부 서버 삭제 알림 실패 (무시됨): $error');
    });
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

    return Center(
      child: Container(
        width: double.infinity,
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              characterEmoji,
              style: const TextStyle(fontSize: 80),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '완료율: ${(completionRate * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          Text(
            '오늘의 할일',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade600,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('전체', totalTodos, Colors.blue),
              _buildStatItem('완료', completedTodos, Colors.green),
              _buildStatItem('대기', pendingTodos, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoList() {
    if (_todos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '할일이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '새로운 할일을 추가해보세요!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _todos.length,
      itemBuilder: (context, index) {
        final todo = _todos[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: GestureDetector(
              onTap: () => _toggleTodo(todo),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: todo.isCompleted ? Colors.green : Colors.grey.shade300,
                    width: 2,
                  ),
                  color: todo.isCompleted ? Colors.green : Colors.transparent,
                ),
                child: todo.isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                color: todo.isCompleted ? Colors.grey.shade500 : Colors.black87,
              ),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(todo.priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getPriorityText(todo.priority),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getPriorityColor(todo.priority),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${todo.estimatedMinutes}분',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
              onPressed: () => _deleteTodo(todo),
            ),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return '높음';
      case 'medium':
        return '보통';
      case 'low':
        return '낮음';
      default:
        return '보통';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text(
          '할일 관리',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.pink.shade400,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 캐릭터 이미지
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: _buildCharacterImage(),
            ),
            const SizedBox(height: 20),
            
            // 빠른 통계
            _buildQuickStats(),
            const SizedBox(height: 20),
            
            // 서버 연동 상태 및 설정
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '외부 서버 연동',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ExternalServerService.isEnabled ? '활성화됨' : '비활성화됨',
                        style: TextStyle(
                          fontSize: 14,
                          color: ExternalServerService.isEnabled ? Colors.green : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        ExternalServerService.isEnabled = !ExternalServerService.isEnabled;
                      });
                      if (ExternalServerService.isEnabled) {
                        _testServerConnection();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ExternalServerService.isEnabled ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(ExternalServerService.isEnabled ? '비활성화' : '활성화'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // 할일 목록 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '할일 목록',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${_todos.length}개',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddTodoDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('추가'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 할일 목록
            _buildTodoList(),
            
            const SizedBox(height: 20),
            
            // ML 위젯
            LocalMLWidget(
              todos: _todos.map((todo) => {
                'title': todo.title,
                'isCompleted': todo.isCompleted,
                'priority': todo.priority,
              }).toList(),
              completionRate: _todos.isEmpty ? 0 : _todos.where((todo) => todo.isCompleted).length / _todos.length,
              totalTodos: _todos.length,
              completedTodos: _todos.where((todo) => todo.isCompleted).length,
              studyTimeMinutes: 60,
              currentMood: _todos.isEmpty ? 'encouraging' : 
                          (_todos.where((todo) => todo.isCompleted).length / _todos.length > 0.7 ? 'happy' : 
                           _todos.where((todo) => todo.isCompleted).length / _todos.length > 0.4 ? 'working' : 'encouraging'),
            ),
          ],
        ),
      ),

    );
  }
}

 

