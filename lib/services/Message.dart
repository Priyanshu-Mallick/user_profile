class Message {
  final String content;
  final String sender;
  final DateTime timestamp;
  final String? imageUrl;

  Message({required this.content, required this.sender, required this.timestamp, this.imageUrl,});
}