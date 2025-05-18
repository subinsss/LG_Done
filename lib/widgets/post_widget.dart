import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostWidget extends StatefulWidget {
  const PostWidget({
    super.key,
    required this.item,
    this.onPostUpdated,
  });

  final Post item;
  final Function(Post)? onPostUpdated;

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late Post _post;

  @override
  void initState() {
    super.initState();
    _post = widget.item;
  }

  // 좋아요 토글 함수
  void _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isLiked = _post.likes.any((like) => like.username == currentUser.displayName);
    
    try {
      // Firestore 참조
      final postRef = FirebaseFirestore.instance.collection('posts').doc(_post.uid);
      
      if (isLiked) {
        // 좋아요 취소
        await postRef.update({
          'likes': FieldValue.arrayRemove([{
            'uid': currentUser.uid,
            'username': currentUser.displayName,
          }])
        });
        
        setState(() {
          _post = Post(
            uid: _post.uid,
            username: _post.username,
            description: _post.description,
            imageUrl: _post.imageUrl,
            likes: _post.likes.where((like) => like.username != currentUser.displayName).toList(),
            comments: _post.comments,
            createdAt: Timestamp.fromDate(_post.createdAt),
            studyTime: _post.studyTime,
            studyType: _post.studyType,
          );
        });
      } else {
        // 좋아요 추가
        final newLike = {
          'uid': currentUser.uid,
          'username': currentUser.displayName,
        };
        
        await postRef.update({
          'likes': FieldValue.arrayUnion([newLike])
        });
        
        setState(() {
          _post = Post(
            uid: _post.uid,
            username: _post.username,
            description: _post.description,
            imageUrl: _post.imageUrl,
            likes: [
              ..._post.likes,
              Like(
                uid: currentUser.uid,
                username: currentUser.displayName ?? '',
              ),
            ],
            comments: _post.comments,
            createdAt: Timestamp.fromDate(_post.createdAt),
            studyTime: _post.studyTime,
            studyType: _post.studyType,
          );
        });
      }
      
      // 상태 업데이트를 부모에게 알림
      if (widget.onPostUpdated != null) {
        widget.onPostUpdated!(_post);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileImage(),
          Container(height: 12),
          if (_post.studyTime != null || _post.studyType != null)
            _buildStudyInfo(),
          _buildImage(),
          Container(height: 12),
          _buildIcons(),
          Container(height: 12),
          _buildLikeAndComments(),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
        ),
        Container(width: 8),
        Text(
          _post.username,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    if (_post.imageUrl == null) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: _post.imageUrl ?? "",
        placeholder: (context, url) {
          return Container(
            height: 300,
            alignment: Alignment.center,
            color: Colors.black.withOpacity(0.03),
            child: Container(
              width: 30,
              height: 30,
              child: const CircularProgressIndicator(
                strokeWidth: 1.0,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black45),
                strokeCap: StrokeCap.round,
              ),
            ),
          );
        },
        errorWidget: (context, url, error) {
          return Container(
            height: 300,
            alignment: Alignment.center,
            child: const Icon(
              Icons.error,
              size: 56,
              color: Colors.black54,
            ),
          );
        },
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildIcons() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = _post.likes.any((like) => like.username == currentUser?.displayName);
    
    return Row(
      children: [
        IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: 26,
            color: isLiked ? Colors.red : Colors.black,
          ),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
          onPressed: _toggleLike,
        ),
        Container(width: 12),
        IconButton(
          icon: Icon(
            Icons.chat_bubble_outline,
            size: 24,
          ),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
          onPressed: () {
            // 댓글 기능 구현
          },
        ),
        Container(width: 12),
        const Spacer(),
        IconButton(
          icon: Icon(
            Icons.bookmark_border,
            size: 26,
          ),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
          onPressed: () {
            // 북마크 기능 구현
          },
        ),
      ],
    );
  }

  Widget _buildLikeAndComments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '좋아요 ${_post.likes.length}개',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(height: 4),
        Text(
          _post.description,
          style: TextStyle(
            color: Colors.black,
          ),
        ),
        Container(height: 4),
        Text(
          '댓글 ${_post.comments.length}개 모두 보기',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
        Container(height: 4),
        Text(
          _post.timeAgo,
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  // 공부 정보를 표시하는 위젯
  Widget _buildStudyInfo() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_post.studyTime != null) 
                  Text(
                    '공부 시간: ${_post.formattedStudyTime}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                if (_post.studyType != null)
                  Text(
                    '공부 유형: ${_post.studyType}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
