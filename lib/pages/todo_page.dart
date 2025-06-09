import 'package:flutter/material.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _todoController = TextEditingController();
  List<TodoItem> _todos = [
    TodoItem(title: '아침 운동하기', isCompleted: false),
    TodoItem(title: '프로젝트 회의 참석', isCompleted: true),
    TodoItem(title: '점심 약속', isCompleted: false),
    TodoItem(title: '저녁 요리하기', isCompleted: false),
    TodoItem(title: '독서 1시간', isCompleted: true),
  ];

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  void _addTodo() {
    if (_todoController.text.trim().isNotEmpty) {
      setState(() {
        _todos.add(TodoItem(
          title: _todoController.text.trim(),
          isCompleted: false,
        ));
        _todoController.clear();
      });
    }
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index] = TodoItem(
        title: _todos[index].title,
        isCompleted: !_todos[index].isCompleted,
      );
    });
  }

  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('새 할일 추가'),
          content: TextField(
            controller: _todoController,
            decoration: const InputDecoration(
              hintText: '할일을 입력하세요',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) {
              _addTodo();
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _todoController.clear();
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                _addTodo();
                Navigator.of(context).pop();
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int completedCount = _todos.where((todo) => todo.isCompleted).length;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '할일 관리',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 진행률 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.shade600,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '완료: $completedCount / ${_todos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _todos.isEmpty ? 0 : completedCount / _todos.length,
                  backgroundColor: Colors.purple.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
                const SizedBox(height: 10),
                Text(
                  _todos.isEmpty 
                    ? '할일을 추가해보세요!'
                    : completedCount == _todos.length 
                      ? '모든 할일을 완료했습니다! 🎉'
                      : '${_todos.length - completedCount}개의 할일이 남았습니다',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // 할일 목록
          Expanded(
            child: _todos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 20),
                        Text(
                          '아직 할일이 없습니다',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '+ 버튼을 눌러 할일을 추가해보세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          leading: GestureDetector(
                            onTap: () => _toggleTodo(index),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: todo.isCompleted 
                                    ? Colors.green 
                                    : Colors.grey,
                                  width: 2,
                                ),
                                color: todo.isCompleted 
                                  ? Colors.green 
                                  : Colors.transparent,
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
                          title: Text(
                            todo.title,
                            style: TextStyle(
                              fontSize: 16,
                              decoration: todo.isCompleted 
                                ? TextDecoration.lineThrough 
                                : null,
                              color: todo.isCompleted 
                                ? Colors.grey 
                                : Colors.black,
                              fontWeight: todo.isCompleted 
                                ? FontWeight.normal 
                                : FontWeight.w500,
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: () => _deleteTodo(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                          onTap: () => _toggleTodo(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTodoDialog,
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TodoItem {
  final String title;
  final bool isCompleted;
  
  TodoItem({required this.title, required this.isCompleted});
} 