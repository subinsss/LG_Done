import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ThinQ/pages/community_page.dart';
import 'package:ThinQ/pages/feed_page.dart';
import 'package:ThinQ/pages/timer_page.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _dailyStats = [];
  int _currentIndex = 3; // 통계 탭 선택
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 선택한 날짜의 연, 월, 일만 가져와서 시작과 끝 범위를 설정
      final startDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endDate = startDate.add(Duration(days: 1));

      // 현재 사용자의 통계 데이터를 Firestore에서 가져옴
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Firestore에서 해당 날짜의 작업 데이터 가져오기
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('uid', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThan: endDate)
          .get();

      // 포스트 데이터 가져오기
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThan: endDate)
          .get();

      // 통계 생성 (임시 데이터 포함)
      final stats = [
        {'title': '완료한 작업', 'value': tasksSnapshot.docs.where((doc) => doc.data()['isCompleted'] == true).length.toString(), 'icon': Icons.task_alt},
        {'title': '진행 중인 작업', 'value': tasksSnapshot.docs.where((doc) => doc.data()['isCompleted'] == false).length.toString(), 'icon': Icons.pending_actions},
        {'title': '총 작업 시간', 'value': _calculateTotalTime(tasksSnapshot.docs), 'icon': Icons.access_time},
        {'title': '작성한 게시물', 'value': postsSnapshot.docs.length.toString(), 'icon': Icons.article},
      ];

      setState(() {
        _dailyStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('통계 로딩 오류: $e');
      setState(() {
        _isLoading = false;
        _dailyStats = [
          {'title': '완료한 작업', 'value': '0', 'icon': Icons.task_alt},
          {'title': '진행 중인 작업', 'value': '0', 'icon': Icons.pending_actions},
          {'title': '총 작업 시간', 'value': '0분', 'icon': Icons.access_time},
          {'title': '작성한 게시물', 'value': '0', 'icon': Icons.article},
        ];
      });
    }
  }

  String _calculateTotalTime(List<QueryDocumentSnapshot> docs) {
    int totalMinutes = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('duration')) {
        totalMinutes += (data['duration'] as int? ?? 0);
      }
    }
    
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return '$hours시간 $minutes분';
    } else {
      return '$totalMinutes분';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F2F3),
        title: Column(
          children: [
            Image.asset(
              'assets/ThinQ_logo2.png',
              width: 150,
            ),
            Text(
              '통계 화면',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF1F2F3),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 날짜 선택 UI
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios),
                        onPressed: () {
                          setState(() {
                            _selectedDate = _selectedDate.subtract(Duration(days: 1));
                            _loadStats();
                          });
                        },
                      ),
                      GestureDetector(
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null && pickedDate != _selectedDate) {
                            setState(() {
                              _selectedDate = pickedDate;
                              _loadStats();
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Theme.of(context).colorScheme.primary),
                          ),
                          child: Text(
                            DateFormat('yyyy년 MM월 dd일').format(_selectedDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_forward_ios),
                        onPressed: _selectedDate.isBefore(DateTime.now())
                            ? () {
                                setState(() {
                                  _selectedDate = _selectedDate.add(Duration(days: 1));
                                  _loadStats();
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                
                // 통계 그리드
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: _dailyStats.length,
                    itemBuilder: (context, index) {
                      final stat = _dailyStats[index];
                      return _buildStatCard(
                        title: stat['title'],
                        value: stat['value'],
                        icon: stat['icon'],
                      );
                    },
                  ),
                ),
                
                // 주간 요약 카드
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이번 주 요약',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('평균 작업 시간: 2시간 30분'),
                          Text('완료율: 62%'),
                        ],
                      ),
                      SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: 0.62,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            switch (index) {
              case 0: // 내역 페이지
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => FeedPage()),
                );
                break;
              case 1: // 관리 페이지
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => TimerPage()),
                );
                break;
              case 2: // 커뮤니티 페이지
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => CommunityPage()),
                );
                break;
              case 3: // 현재 페이지(통계)
                break;
            }
          }
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '내역',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: '관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '커뮤니티',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '통계',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
} 