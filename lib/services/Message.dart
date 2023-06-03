class Message {
  final String content;
  final String sender;
  final DateTime timestamp;
  String type;
  final String? imageUrl;

  Message({required this.content, required this.sender, required this.timestamp, required this.type, this.imageUrl,});
}