import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ThinQ/data/task.dart';
import 'package:ThinQ/widgets/rounded_inkwell.dart';
import 'package:ThinQ/widgets/haptic_feedback.dart';

class TaskPage extends StatefulWidget {
  final Task? task;

  const TaskPage({super.key, this.task});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _duration = 25; // 기본 25분
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // 편집 모드인 경우 기존 데이터 저장
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _duration = widget.task!.duration;
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
    final bool isEditMode = widget.task != null;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditMode ? '작업 편집' : '새 작업',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEditMode)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteConfirmation,
            ),
          TextButton(
            onPressed: _saveTask,
            child: Text(
              '저장',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: '작업 제목',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: '작업 내용 (선택사항)',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: TextStyle(fontSize: 16),
                    maxLines: 5,
                    minLines: 3,
                  ),
                  SizedBox(height: 24),
                  Text(
                    '집중 시간 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildDurationSelector(),
                ],
              ),
            ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      children: [
        Text(
          '$_duration분',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(height: 16),
        Slider(
          value: _duration.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          label: '$_duration분',
          activeColor: Theme.of(context).colorScheme.primary,
          onChanged: (value) {
            setState(() {
              _duration = value.round();
            });
            HapticFeedback.lightImpact();
          },
        ),
        SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimePresetButton(15),
            _buildTimePresetButton(25),
            _buildTimePresetButton(45),
            _buildTimePresetButton(60),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePresetButton(int minutes) {
    final isSelected = _duration == minutes;
    
    return RoundedInkWell(
      onTap: () {
        setState(() {
          _duration = minutes;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$minutes분',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('작업 제목을 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final description = _descriptionController.text.trim();
      
      if (widget.task != null) {
        // 편집 모드
        await FirebaseFirestore.instance
            .collection('tasks')
            .doc(widget.task!.id)
            .update({
          'title': title,
          'description': description,
          'duration': _duration,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // 분석 이벤트 전송
        await FirebaseAnalytics.instance.logEvent(
          name: 'task_updated',
          parameters: {
            'task_id': widget.task!.id,
          },
        );
      } else {
        // 생성 모드
        await FirebaseFirestore.instance.collection('tasks').add({
          'uid': user.uid,
          'title': title,
          'description': description,
          'duration': _duration,
          'isCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // 분석 이벤트 전송
        await FirebaseAnalytics.instance.logEvent(
          name: 'task_created',
          parameters: {
            'duration': _duration,
          },
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('작업 삭제'),
        content: Text('정말로 이 작업을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteTask();
            },
            child: Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask() async {
    if (widget.task == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task!.id)
          .delete();
      
      // 분석 이벤트 전송
      await FirebaseAnalytics.instance.logEvent(
        name: 'task_deleted',
        parameters: {
          'task_id': widget.task!.id,
        },
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
} 