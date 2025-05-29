import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/firestore_todo_service.dart';
import 'dart:async';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final FirestoreTodoService _firestoreService = FirestoreTodoService();
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<TodoItem> _allTodos = [];
  StreamSubscription<List<TodoItem>>? _todosSubscription;
  bool _isCalendarView = true; // 캘린더 뷰/리스트 뷰 전환용
  
  // 카테고리 목록
  final List<String> _categories = ['약속', '꼭할일', '집나가기전', '건우', '마루.아리'];
  
  // 할일 추가용 컨트롤러
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  String _selectedPriority = 'medium';
  String _selectedCategory = '꼭할일';

  @override
  void initState() {
    super.initState();
    _listenToTodos();
  }

  @override
  void dispose() {
    _todoController.dispose();
    _minutesController.dispose();
    _todosSubscription?.cancel();
    super.dispose();
  }

  void _listenToTodos() {
    _todosSubscription = _firestoreService.getTodosStream().listen(
      (todos) {
        setState(() {
          _allTodos = todos;
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('할일 목록을 불러오는데 실패했습니다: $error')),
        );
      },
    );
  }

  List<TodoItem> _getTodosForDay(DateTime day) {
    return _allTodos.where((todo) {
      if (todo.dueDate == null) return false;
      return isSameDay(todo.dueDate!, day);
    }).toList();
  }

  List<TodoItem> _getTodosForCategory(DateTime day, String category) {
    final dayTodos = _getTodosForDay(day);
    return dayTodos.where((todo) => todo.category == category).toList();
  }

  int _getCompletedCount(DateTime day) {
    return _getTodosForDay(day).where((todo) => todo.isCompleted).length;
  }

  int _getFailedCount(DateTime day) {
    final dayTodos = _getTodosForDay(day);
    final today = DateTime.now();
    if (day.isAfter(today)) return 0; // 미래 날짜는 실패 카운트 안함
    
    return dayTodos.where((todo) => !todo.isCompleted).length;
  }

  String _getEmoji(DateTime day) {
    final completed = _getCompletedCount(day);
    final failed = _getFailedCount(day);
    
    if (completed > failed) return '😊';
    if (completed == failed && completed > 0) return '😐';
    if (failed > completed) return '😔';
    return '🙂';
  }

  Future<void> _addTodo(String category) async {
    if (_todoController.text.trim().isEmpty) return;
    
    int estimatedMinutes = 30;
    if (_minutesController.text.isNotEmpty) {
      estimatedMinutes = int.tryParse(_minutesController.text) ?? 30;
    }
    
    final todoId = await _firestoreService.addTodo(
      title: _todoController.text.trim(),
      priority: _selectedPriority,
      estimatedMinutes: estimatedMinutes,
      dueDate: _selectedDay,
      category: category,
    );
    
    if (todoId != null) {
      _todoController.clear();
      _minutesController.clear();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 추가에 실패했습니다')),
      );
    }
  }

  Future<void> _toggleTodo(TodoItem todo) async {
    final success = await _firestoreService.toggleTodoCompletion(
      todo.id, 
      !todo.isCompleted
    );
    
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할일 상태 변경에 실패했습니다')),
      );
    }
  }

  void _showAddTodoDialog(String category) {
    _selectedCategory = category;
    _minutesController.text = '30';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(
            '$category 할일 추가',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _todoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '할일을 입력하세요',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    labelText: '할일',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '30',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    labelText: '예상 소요시간 (분)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  dropdownColor: const Color(0xFF2D2D2D),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '우선순위',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'low',
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('낮음'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('보통'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('높음'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedPriority = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => _addTodo(category),
              child: const Text('추가', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayTodos = _getTodosForDay(_selectedDay);
    final completedCount = _getCompletedCount(_selectedDay);
    final failedCount = _getFailedCount(_selectedDay);
    final emoji = _getEmoji(_selectedDay);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          '캘린더',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isCalendarView = !_isCalendarView;
              });
            },
            icon: Icon(
              _isCalendarView ? Icons.list : Icons.calendar_today,
              color: Colors.white,
            ),
            tooltip: _isCalendarView ? '리스트 보기' : '캘린더 보기',
          ),
        ],
      ),
      body: _isCalendarView ? _buildCalendarView(completedCount, failedCount, emoji) : _buildListView(),
    );
  }

  Widget _buildCalendarView(int completedCount, int failedCount, String emoji) {
    return Column(
      children: [
        // 상단 날짜 및 감정 표시
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('yyyy년 M월 d일').format(_selectedDay),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Text(
                '$completedCount',
                style: const TextStyle(color: Colors.green, fontSize: 16),
              ),
              const Text(' ✅ ', style: TextStyle(fontSize: 16)),
              Text(
                '$failedCount',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const Text(' ❌', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
        
        // 달력
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TableCalendar<TodoItem>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            eventLoader: _getTodosForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle: const TextStyle(color: Colors.white70),
              holidayTextStyle: const TextStyle(color: Colors.red),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white70),
              weekendStyle: TextStyle(color: Colors.white70),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 카테고리별 할일 목록
        Expanded(
          child: _buildCategoryTodoList(),
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        // 날짜 선택 헤더
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                  });
                },
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Text(
                DateFormat('yyyy년 M월 d일').format(_selectedDay),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.add(const Duration(days: 1));
                  });
                },
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
        ),
        
        // 카테고리별 할일 목록
        Expanded(
          child: _buildCategoryTodoList(),
        ),
      ],
    );
  }

  Widget _buildCategoryTodoList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '카테고리별 할일',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final categoryTodos = _getTodosForCategory(_selectedDay, category);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리 헤더
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showAddTodoDialog(category),
                              icon: const Icon(
                                Icons.add,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 카테고리 할일 목록
                      if (categoryTodos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '할일이 없습니다',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ...categoryTodos.map((todo) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: todo.isCompleted,
                                onChanged: (_) => _toggleTodo(todo),
                                activeColor: Colors.green,
                                checkColor: Colors.white,
                              ),
                              Expanded(
                                child: Text(
                                  todo.title,
                                  style: TextStyle(
                                    color: todo.isCompleted
                                        ? Colors.grey
                                        : Colors.white,
                                    decoration: todo.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: todo.priority == 'high'
                                      ? Colors.red
                                      : todo.priority == 'medium'
                                          ? Colors.orange
                                          : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${todo.estimatedMinutes}분',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 