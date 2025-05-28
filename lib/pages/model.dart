class ChatMessage {
  final bool isMe;
  String text;
  final DateTime sentAt;
  String? imageUrl;

  ChatMessage({
    required this.isMe, 
    required this.text, 
    required this.sentAt,
    this.imageUrl,
  });
  
  ChatMessage copyWith({
    bool? isMe,
    String? text,
    DateTime? sentAt,
    String? imageUrl,
  }) {
    return ChatMessage(
      isMe: isMe ?? this.isMe,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
class ChatRoom {
  List<ChatMessage> chats;
  final DateTime createdAt;

  ChatRoom({required this.chats, required this.createdAt});
}
