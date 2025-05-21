import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String characterId;  // 캐릭터 ID
  final String userId;       // 사용자 ID
  final bool isMe;           // 사용자 메시지인지 여부
  String text;               // 메시지 내용
  final DateTime sentAt;     // 메시지 시간
  
  bool get isUserMessage => isMe;
  String get content => text;

  ChatMessage({
    this.id = '',
    required this.characterId,
    required this.userId,
    required this.isMe,
    required this.text,
    required this.sentAt,
  });

  ChatMessage copyWith({
    String? id,
    String? characterId,
    String? userId,
    bool? isMe,
    String? text,
    DateTime? sentAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      userId: userId ?? this.userId,
      isMe: isMe ?? this.isMe,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'characterId': characterId,
      'userId': userId,
      'isMe': isMe,
      'text': text,
      'sentAt': sentAt,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessage(
      id: docId,
      characterId: map['characterId'] ?? '',
      userId: map['userId'] ?? '',
      isMe: map['isMe'] ?? map['isUserMessage'] ?? false,
      text: map['text'] ?? map['content'] ?? '',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? 
              (map['timestamp'] as Timestamp?)?.toDate() ?? 
              DateTime.now(),
    );
  }
} 