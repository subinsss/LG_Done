import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:dx_project/data/task.dart';

class TaskItem {
  final String title;
  final String? description;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  TaskItem({
    required this.title,
    this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}

class TaskPage extends StatefulWidget {
  final Task? task;

  const TaskPage({super.key, this.task});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  // 일정 입력을 위한 컨트롤러
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 시간 설정을 위한 변수
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

  // 일정 목록
  final List<TaskItem> _tasks = [];
  
  // 입력폼 표시 여부
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    
    // 전달받은 Task가 있으면 폼 초기화
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      if (widget.task!.description.isNotEmpty) {
        _descriptionController.text = widget.task!.description;
      }
      _showForm = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 상단 제목
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text(
                '내 일정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // 달력
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  calendarFormat: _calendarFormat,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 선택한 날짜 표시
            Text(
              '${_selectedDay.year}년 ${_selectedDay.month}월 ${_selectedDay.day}일',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 16),
            
            // 할 일 추가 버튼
            if (!_showForm)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    
                    // 현재 시간으로 시작 시간 초기화
                    _startTime = TimeOfDay.now();
                    // 시작 시간보다 1시간 후로 종료 시간 초기화
                    _endTime = TimeOfDay(
                      hour: (_startTime.hour + 1) % 24, 
                      minute: _startTime.minute
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('할 일 추가'),
              ),
            
            // 할 일 입력 폼
            if (_showForm)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '새 할 일 추가',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 제목 입력 필드
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '할 일 제목',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      
                      // 설명 입력 필드
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: '설명 (선택사항)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      
                      // 시간 선택 버튼들
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(context, true),
                              icon: const Icon(Icons.access_time),
                              label: Text('시작: ${_formatTimeOfDay(_startTime)}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(context, false),
                              icon: const Icon(Icons.access_time),
                              label: Text('종료: ${_formatTimeOfDay(_endTime)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 버튼
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showForm = false;
                                _titleController.clear();
                                _descriptionController.clear();
                              });
                            },
                            child: const Text('취소'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveTask,
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // 할 일 목록
            Expanded(
              child: _getTasksForSelectedDay().isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_note,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '선택한 날짜에 일정이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _getTasksForSelectedDay().length,
                      itemBuilder: (context, index) {
                        final task = _getTasksForSelectedDay()[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(task.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (task.description != null && task.description!.isNotEmpty)
                                  Text(task.description!),
                                Text(
                                  '${_formatTimeOfDay(task.startTime)} - ${_formatTimeOfDay(task.endTime)}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                _deleteTask(task);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 시간 선택 다이얼로그 표시
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );

    if (pickedTime != null) {
      setState(() {
        if (isStartTime) {
          _startTime = pickedTime;
          
          // 시작 시간이 종료 시간보다 늦으면 종료 시간 자동 조정
          if (_compareTimeOfDay(_startTime, _endTime) >= 0) {
            _endTime = TimeOfDay(
              hour: (_startTime.hour + 1) % 24,
              minute: _startTime.minute,
            );
          }
        } else {
          // 종료 시간이 시작 시간보다 빠르지 않게 설정
          if (_compareTimeOfDay(pickedTime, _startTime) < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('종료 시간은 시작 시간보다 뒤여야 합니다.'),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            _endTime = pickedTime;
          }
        }
      });
    }
  }

  // TimeOfDay를 비교하기 위한 헬퍼 메소드
  int _compareTimeOfDay(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour < time2.hour) {
      return -1;
    } else if (time1.hour > time2.hour) {
      return 1;
    } else {
      return time1.minute.compareTo(time2.minute);
    }
  }

  // TimeOfDay를 포맷팅하는 메소드
  String _formatTimeOfDay(TimeOfDay time) {
    final format = DateFormat('HH:mm');
    final date = DateTime(2022, 1, 1, time.hour, time.minute);
    return format.format(date);
  }

  // 할 일 저장
  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('할 일 제목을 입력해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final task = TaskItem(
      title: title,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text.trim(),
      date: _selectedDay,
      startTime: _startTime,
      endTime: _endTime,
    );

    setState(() {
      _tasks.add(task);
      _showForm = false;
      _titleController.clear();
      _descriptionController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('할 일이 추가되었습니다: $title'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 선택한 날짜의 일정만 필터링
  List<TaskItem> _getTasksForSelectedDay() {
    return _tasks.where((task) => 
      task.date.year == _selectedDay.year &&
      task.date.month == _selectedDay.month &&
      task.date.day == _selectedDay.day
    ).toList();
  }

  // 할 일 삭제
  void _deleteTask(TaskItem task) {
    setState(() {
      _tasks.remove(task);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${task.title} 일정이 삭제되었습니다'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
} 