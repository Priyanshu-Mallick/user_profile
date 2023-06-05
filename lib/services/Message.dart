class Message {
  final String content;
  final String sender;
  final DateTime timestamp;
  String type;

  Message({required this.content, required this.sender, required this.timestamp, required this.type});
}