import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/post.dart';
import 'package:ThinQ/pages/feed_page.dart';
import 'package:ThinQ/pages/stats_page.dart';
import 'package:ThinQ/pages/timer_page.dart';
import 'package:ThinQ/pages/write_page.dart';
import 'package:ThinQ/widgets/post_widget.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<Post> _posts = [];
  bool _isLoading = false;
  int _currentIndex = 2; // 정보 탭(커뮤니티) 선택

  @override
  void initState() {
    super.initState();
    _loadCommunityPosts();
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
              '시간 관리 커뮤니티',
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
          : RefreshIndicator(
              onRefresh: _loadCommunityPosts,
              child: _posts.isEmpty
                  ? _buildEmptyCommunity()
                  : ListView.builder(
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        return PostWidget(
                          item: _posts[index],
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          // 글쓰기 페이지로 이동
          await Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) {
                return WritePage();
              },
            ),
          );
          _loadCommunityPosts();
        },
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
              case 2: // 현재 페이지(정보/커뮤니티)
                break;
              case 3: // 통계 페이지
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => StatsPage()),
                );
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

  Widget _buildEmptyCommunity() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outlined, 
            size: 80, 
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 20),
          Text(
            '아직 공유된 시간 관리가 없습니다',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '여러분의 시간 관리 경험을 공유해보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('새 포스트 작성하기'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (context) {
                    return WritePage();
                  },
                ),
              );
              _loadCommunityPosts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCommunityPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 모든 사용자의 게시물을 가져옵니다.
      final snapshot = await FirebaseFirestore.instance
          .collection("posts")
          .orderBy("createdAt", descending: true)
          .get();
      
      final documents = snapshot.docs;

      // FirebaseFirestore로부터 받아온 데이터를 Post 객체로 변환합니다.
      List<Post> posts = [];

      for (final doc in documents) {
        final data = doc.data();
        final uid = data['uid'];
        final username = data['username'];
        final description = data['description'];
        final imageUrl = data['imageUrl'];
        final createdAt = data['createdAt'];
        final studyTime = data['studyTime']; // 추가: 공부한 시간
        final studyType = data['studyType']; // 추가: 공부 유형
        
        posts.add(
          Post(
            uid: uid,
            username: username,
            description: description,
            imageUrl: imageUrl,
            createdAt: createdAt,
            studyTime: studyTime, // 추가
            studyType: studyType, // 추가
          ),
        );
      }

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print('커뮤니티 포스트 로딩 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
} 