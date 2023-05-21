import 'package:flutter/material.dart';
import 'package:user_profile/services/Message.dart';
import 'package:user_profile/services/Topic.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final Topic topic;
  final String username;


  const ChatScreen({required this.topic, required this.username});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> messages = [];
  late FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeFirebase();
  }

  Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
  }

  void sendMessage(String content) async {
    if (content.isNotEmpty) {
      final encryptedContent = encryptContent(content); // Encrypt message content

      Message message = Message(
        content: encryptedContent,
        sender: widget.username,
        timestamp: DateTime.now(),
      );

      // Store the encrypted message in Firestore
      await _firestore.collection('messages').add({
        'content': message.content,
        'sender': message.sender,
        'timestamp': message.timestamp,
      });

      setState(() {
        messages.add(message);
        messageController.clear();
      });
    }
  }

  String encryptContent(String content) {
    // Use your encryption algorithm of choice to encrypt the message content
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(content, iv: iv);
    return encrypted.base64; // Return the encrypted content as a string
  }

  String decryptContent(String encryptedContent) {
    // Use your encryption algorithm of choice to decrypt the message content
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypt.Encrypted.fromBase64(encryptedContent);
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    return decrypted; // Return the decrypted content
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue,
            child: Text(
              'Username: ${widget.username}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('messages').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                messages = []; // Clear existing messages
                final messageDocs = snapshot.data!.docs;
                messageDocs.forEach((messageDoc) {
                  final data = messageDoc.data() as Map<String, dynamic>;
                  final decryptedContent = decryptContent(data['content'] as String);
                  final message = Message(
                    content: decryptedContent,
                    sender: data['sender'] as String,
                    timestamp: (data['timestamp'] as Timestamp).toDate(),
                  );
                  messages.add(message);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    Message message = messages[index];
                    bool isSender = message.sender == widget.username;

                    return Align(
                      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSender ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            color: isSender ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: () => sendMessage(messageController.text),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
