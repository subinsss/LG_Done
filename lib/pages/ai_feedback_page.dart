import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/firestore_todo_service.dart';
import '../widgets/local_ml_widget.dart';

class AIFeedbackPage extends StatefulWidget {
  const AIFeedbackPage({super.key});

  @override
  State<AIFeedbackPage> createState() => _AIFeedbackPageState();
}

class _AIFeedbackPageState extends State<AIFeedbackPage> {
  // Firestore 서비스
  final FirestoreTodoService _firestoreService = FirestoreTodoService();
  
  // 할일 목록 (Firestore에서 실시간으로 받아옴)
  List<TodoItem> _todos = [];
  StreamSubscription<List<TodoItem>>? _todosSubscription;

  // 오늘 날짜
  final DateTime _today = DateTime.now();

  bool _isDataLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _todosSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isDataLoading = true;
    });

    try {
      _listenToTodos();
    } catch (e) {
      print('❌ 데이터 초기화 오류: $e');
    } finally {
      setState(() {
        _isDataLoading = false;
      });
    }
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

  // 날짜 비교 함수 (같은 날인지 확인)
  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildTodayHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.today,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '오늘의 AI 피드백',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  DateFormat('yyyy년 M월 d일 (E)').format(_today),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStats() {
    // 오늘 날짜의 할일만 필터링
    final todayTodos = _todos.where((todo) {
      if (todo.dueDate == null) return false;
      return _isSameDay(todo.dueDate!, _today);
    }).toList();

    int totalTodos = todayTodos.length;
    int completedTodos = todayTodos.where((todo) => todo.isCompleted).length;
    int pendingTodos = totalTodos - completedTodos;
    double completionRate = totalTodos == 0 ? 0.0 : completedTodos / totalTodos;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 진행 상황',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          
          // 완료율 진행바
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '완료율',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '${(completionRate * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: completionRate > 0.7 ? Colors.black : 
                                completionRate > 0.4 ? Colors.grey.shade700 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: completionRate,
                    child: Container(
                      decoration: BoxDecoration(
                        color: completionRate > 0.7 ? Colors.black : 
                                completionRate > 0.4 ? Colors.grey.shade700 : Colors.grey.shade500,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 15),
          
          // 통계 항목들
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('전체', totalTodos, Colors.black),
              _buildStatItem('완료', completedTodos, Colors.black),
              _buildStatItem('대기', pendingTodos, Colors.grey.shade600),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'AI 피드백',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 오늘 날짜 헤더
            _buildTodayHeader(),
            
            const SizedBox(height: 10),
            
            // 오늘의 통계
            _buildTodayStats(),
            
            const SizedBox(height: 20),
            
            // AI 피드백 위젯 (오늘의 할일만 분석)
            Builder(
              builder: (context) {
                // 오늘 날짜의 할일만 필터링
                final todayTodos = _todos.where((todo) {
                  if (todo.dueDate == null) return false;
                  return _isSameDay(todo.dueDate!, _today);
                }).toList();
                
                final completedCount = todayTodos.where((todo) => todo.isCompleted).length;
                final totalCount = todayTodos.length;
                final completionRate = totalCount == 0 ? 0.0 : completedCount / totalCount;
                
                return LocalMLWidget(
                  todos: todayTodos.map((todo) => {
                    'title': todo.title,
                    'isCompleted': todo.isCompleted,
                    'priority': todo.priority,
                  }).toList(),
                  completionRate: completionRate,
                  totalTodos: totalCount,
                  completedTodos: completedCount,
                  studyTimeMinutes: 60,
                  currentMood: totalCount == 0 ? 'encouraging' : 
                              (completionRate > 0.7 ? 'happy' : 
                               completionRate > 0.4 ? 'working' : 'encouraging'),
                );
              },
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
} 