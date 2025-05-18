import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String uid;
  final String username;
  final String? imageUrl;
  final String description;
  final List<Like> likes;
  final List<Comment> comments;
  final DateTime createdAt;
  final int? studyTime; // 공부 시간(분)
  final String? studyType; // 공부 유형

  Post({
    required this.uid,
    required this.username,
    required this.description,
    this.imageUrl,
    this.likes = const [],
    this.comments = const [],
    required Timestamp createdAt,
    this.studyTime,
    this.studyType,
  }) : createdAt = createdAt.toDate();

  String get timeAgo {
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}년 전';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}달 전';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // 공부 시간을 시간:분 형식으로 변환하는 getter
  String get formattedStudyTime {
    if (studyTime == null) return '0:00';
    final hours = studyTime! ~/ 60;
    final minutes = studyTime! % 60;
    return '${hours}:${minutes.toString().padLeft(2, '0')}';
  }

  static List<Post> samples = [
    Post(
      uid: 'r2nA56aZVuZcfwx0NKoqe4QNfH12',
      username: 'Kiboom',
      description:
          '출간 1주년을 앞두고 열린 북토크. 대전에서 온 독자, 다른 북토크에서 만났던 독자, 펜이라면서 편지를 건넨 독자, 경찰인 독자, 인스타로 자주 보고 있다는 독자, 드디어 만났다는 독자, 우리 독서모임 멤버인 독자. 모든 걸음이 소중하고 따스하다. 북토크만의 특별한 분위기가 있다. 처음 보는 사이지만, 우리끼리 아는 이야기를 나누는 느낌도 있고, 서로 좋아하는 사이처럼 사소한 이야기에도 꺄르르 웃는다. 나는 북토크에서 더 솔직해진다. 내 책을 읽어주셔서, 관심을 주셔서, 너무나 고맙다. 한편, 내일은, 출간 1주년이다! 독자님, 사랑합니다.',
      imageUrl:
          'https://images.unsplash.com/photo-1598646506778-56bb7a4660a9?q=80&w=3272&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      likes: [
        Like(
          uid: 'Kiboom',
          username: 'Kiboom',
        ),
      ],
      comments: [
        Comment(
          uid: 'mike_portnoy',
          username: 'mike_portnoy',
          comment: 'It was increddible show in Bratislava. We sent all of our love and energy to you',
          createdAt: DateTime.now().subtract(Duration(hours: 1)),
        ),
        Comment(
          uid: 'james_labrie',
          username: 'james_labrie',
          comment: 'Thank you for your support. We will come back soon',
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
        ),
        Comment(
          uid: 'john_petrucci',
          username: 'john_petrucci',
          comment: 'I love you all. You are the best fans in the world',
          createdAt: DateTime.now().subtract(Duration(hours: 2, minutes: 30)),
        ),
        Comment(
          uid: 'jordan_rudess',
          username: 'jordan_rudess',
          comment: 'I am so happy to hear that you enjoyed the show. We will come back soon',
          createdAt: DateTime.now().subtract(Duration(hours: 3)),
        ),
        Comment(
          uid: 'john_myung',
          username: 'john_myung',
          comment: 'Thank you for your support. We will come back soon',
          createdAt: DateTime.now().subtract(Duration(hours: 3, minutes: 30)),
        ),
      ],
      createdAt: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 4))),
      studyTime: 120, // 2시간
      studyType: '독서',
    ),
  ];
}

class Like {
  final String uid;
  final String username;

  Like({
    required this.uid,
    required this.username,
  });
}

class Comment {
  final String uid;
  final String username;
  final String comment;
  final DateTime createdAt;

  Comment({
    required this.uid,
    required this.username,
    required this.comment,
    required this.createdAt,
  });
}
