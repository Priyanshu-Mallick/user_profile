import 'dart:html';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:user_profile/services/Message.dart';
import 'package:user_profile/services/Topic.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

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
  bool isTyping = false;

  // For firebase state management
  @override
  void initState() {
    super.initState();
    initializeFirebase();
  }

  // For Open Camera
  Future<void> openCamera() async {
    final picker = ImagePicker();
    final pickedImage = await picker.getImage(source: ImageSource.camera);
    if (pickedImage != null) {
      final croppedImage = await cropImage(pickedImage.path);
      if (croppedImage != null) {
        // Process the cropped image here
        // You can store it, upload it, etc.
        // Example:
        final imagePath = croppedImage.path;
        // Do something with the image path
      }
    }
  }

  // For image crop
  Future<CroppedFile?> cropImage(String imagePath) async {
    final imageCropper = ImageCropper();
    final croppedImage = await imageCropper.cropImage(
      sourcePath: imagePath,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      androidUiSettings: AndroidUiSettings(
        toolbarTitle: 'Crop Image',
        toolbarColor: Colors.deepOrange,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: CropAspectRatioPreset.original,
        lockAspectRatio: false,
      ),
      iosUiSettings: IOSUiSettings(
        title: 'Crop Image',
      ),
    );
    return croppedImage;
  }



  // Initialize the firebase
  Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
  }

  // For Sending Message
  void sendMessage(String content) async {
    if (content.isNotEmpty) {
      final encryptedContent = encryptContent(content); // Encrypt message content

      Message message = Message(
        content: encryptedContent,
        sender: widget.username,
        timestamp: DateTime.now(),
      );

      // Store the encrypted message in Firestore
      await _firestore
          .collection('chatrooms')
          .doc(widget.topic.id)
          .collection('messages')
          .add({
        'content': message.content,
        'sender': message.sender,
        'timestamp': message.timestamp,
      });

      setState(() {
        messages.add(message);
        messageController.clear();
        isTyping = false;
      });
    }
  }

  // For encrypting message
  String encryptContent(String content) {
    // Use your encryption algorithm of choice to encrypt the message content
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(content, iv: iv);
    return encrypted.base64; // Return the encrypted content as a string
  }

  // For decrypting message
  String decryptContent(String encryptedContent) {
    // Use your encryption algorithm of choice to decrypt the message content
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypt.Encrypted.fromBase64(encryptedContent);
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    return decrypted; // Return the decrypted content
  }

  // For random color generation for random userid color
  Color generateRandomColor() {
    final random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
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
              stream: _firestore
                  .collection('chatrooms')
                  .doc(widget.topic.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                messages = []; // Clear existing messages
                final messageDocs = snapshot.data!.docs;
                messageDocs.forEach((messageDoc) {
                  final data = messageDoc.data() as Map<String, dynamic>;
                  final decryptedContent =
                  decryptContent(data['content'] as String);
                  final message = Message(
                    content: decryptedContent,
                    sender: data['sender'] as String,
                    timestamp: (data['timestamp'] as Timestamp).toDate(),
                  );
                  messages.add(message);
                });

                return ListView.builder(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    Message message = messages[index];
                    bool isSender = message.sender == widget.username;
                    bool isFirstMessageFromSender = index == messages.length - 1 ||
                        messages[index + 1].sender != message.sender;
                    bool shouldShowUserId =
                        !isSender && isFirstMessageFromSender;
                    Color? senderColor;
                    if (!isSender && isFirstMessageFromSender) {
                      senderColor = generateRandomColor();
                    }

                    return Align(
                      alignment:
                      isSender ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: isFirstMessageFromSender
                              ? const EdgeInsets.symmetric(vertical: 5)
                              : const EdgeInsets.symmetric(vertical: 2),
                          constraints: BoxConstraints(maxWidth: 250),
                          decoration: BoxDecoration(
                            color: isSender ? Colors.blue : Colors.grey.shade300,
                            borderRadius: BorderRadius.only(
                              topLeft: isSender
                                  ? Radius.circular(15)
                                  : Radius.circular(
                                  isFirstMessageFromSender ? 0 : 15),
                              topRight: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                              bottomRight: isSender
                                  ? Radius.circular(
                                  isFirstMessageFromSender ? 0 : 15)
                                  : Radius.circular(15),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                            isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (shouldShowUserId)
                                Text(
                                  message.sender,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: senderColor,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isSender ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                DateFormat.jm()
                                    .format(message.timestamp), // Show only time
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          )),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextField(
                        controller: messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onChanged: (text) {
                          setState(() {
                            isTyping = text.isNotEmpty;
                          });
                        },
                      ),
                      Visibility(
                        visible: !isTyping,
                        child: IconButton(
                          onPressed: () {
                            openCamera(); // Open the camera when icon is clicked
                          },
                          icon: Icon(Icons.camera_alt),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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
