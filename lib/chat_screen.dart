// import 'dart:html';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:user_profile/services/Message.dart';
import 'package:user_profile/services/Topic.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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

  File? imageFile;

  // For firebase state management
  @override
  void initState() {
    super.initState();
    initializeFirebase();
  }

  // Initialize the firebase
  Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
  }

  // Open dialog box with camera and image gallery options
  void openImageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Send the image
                  openCamera();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.camera),
                label: const Text('Camera'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Send the image
                  openGallery();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.image),
                label: const Text('Gallery'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Open image overview after selecting image
  void showImageOverview(File imageFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(imageFile),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Send the image
                  // sendMessage(imageFile.path);
                  uploadImage(imageFile.path);
                  Navigator.pop(context);
                },
                child: const Text('Send'),
              ),
            ],
          ),
        );
      },
    );
  }


  // Show the image message on the chat screen
  void showImageMessage(String imageUrl) {
    Message message = Message(
      content: imageUrl,
      sender: widget.username,
      timestamp: DateTime.now(),
      type: 'image',
    );

    setState(() {
      messages.add(message);
    });
  }


  // For image upload
  Future uploadImage(String file) async {
    final firebaseStorageRef = FirebaseStorage.instance.ref().child('images/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = firebaseStorageRef.putFile(imageFile!);

    uploadTask.whenComplete(() {

      final firestore = FirebaseFirestore.instance;
      if (uploadTask.snapshot.state == TaskState.success) {
        firebaseStorageRef.getDownloadURL().then((downloadUrl) {
          // Handle the download URL, e.g., store it in Firestore or display it to the user
          print('Download URL: $downloadUrl');

          showImageMessage(downloadUrl);

          if (downloadUrl.isNotEmpty) {
            final encryptedContent = encryptContent(
                downloadUrl); // Encrypt message content

            Message message = Message(
              content: encryptedContent,
              sender: widget.username,
              timestamp: DateTime.now(),
              type: 'image',
            );

            firestore
                .collection('chatrooms') // Existing collection
                .doc(widget.topic.id) // Document ID of the current topic
                .collection('messages') // New collection for images
                .add({
              'content': message.content,
              'sender': message.sender,
              'timestamp': message.timestamp,
              'type':message.type,
            })
                .then((value) {
              Fluttertoast.showToast(
                msg: 'Image uploaded successfully',
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.green,
                textColor: Colors.white,
              );
            })
                .catchError((error) {
              print('Error storing image URL: $error');
            });
            setState(() {
              messages.add(message);
            });
          }
        });
      }
    }).catchError((error) {
      // Handle any errors that occur during the upload process
      print('Error uploading image: $error');
    });
  }

  // For Open Camera
  Future<void> openCamera() async {
    final picker = ImagePicker();
    final pickedImage = await picker.getImage(source: ImageSource.camera);
    if (pickedImage != null) {
      setState(() {
        imageFile = File(pickedImage.path);
      });
      // Open image overview dialog
      showImageOverview(imageFile!);
    }
  }

  // Open gallery to select image
  Future<void> openGallery() async {
    final picker = ImagePicker();
    final pickedImage = await picker.getImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        imageFile = File(pickedImage.path);
      });
      // Open image overview dialog
      showImageOverview(imageFile!);
    }
  }

  // For Sending Message
  void sendMessage(String content) async {
    if (content.isNotEmpty) {
      final encryptedContent = encryptContent(content); // Encrypt message content

      Message message = Message(
        content: encryptedContent,
        sender: widget.username,
        timestamp: DateTime.now(),
        type: 'text',
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
        'type':message.type,
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
                  return const Center(child: CircularProgressIndicator());
                }

                messages = []; // Clear existing messages
                final messageDocs = snapshot.data!.docs;
                for (var messageDoc in messageDocs) {
                  final data = messageDoc.data() as Map<String, dynamic>;
                  final decryptedContent =
                  decryptContent(data['content'] as String);
                  final message = Message(
                    content: decryptedContent,
                    sender: data['sender'] as String,
                    timestamp: (data['timestamp'] as Timestamp).toDate(),
                    type: data['type'],
                  );
                  messages.add(message);
                }

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

                    if (message.type == 'image') {
                      // Display image message
                      return Align(
                        alignment:
                        isSender ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                content: Image.network(message.content), // Show the image in the dialog
                              ),
                            );
                          },
                          child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: isFirstMessageFromSender
                                  ? const EdgeInsets.symmetric(vertical: 5)
                                  : const EdgeInsets.symmetric(vertical: 2),
                              constraints: const BoxConstraints(maxWidth: 250),
                              decoration: BoxDecoration(
                                color: isSender ? Colors.blue : Colors.grey
                                    .shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: isSender
                                      ? const Radius.circular(15)
                                      : Radius.circular(
                                      isFirstMessageFromSender ? 0 : 15),
                                  topRight: const Radius.circular(15),
                                  bottomLeft: const Radius.circular(15),
                                  bottomRight: isSender
                                      ? Radius.circular(
                                      isFirstMessageFromSender ? 0 : 15)
                                      : const Radius.circular(15),
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
                                isSender
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
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
                                  message.content != ""? Image.network(message.content) : const CircularProgressIndicator(),
                                  Text(
                                    DateFormat.jm()
                                        .format(message.timestamp),
                                    // Show only time
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              )
                          ),
                        ),
                      );
                    }else {
                      return Align(
                        alignment:
                        isSender ? Alignment.centerRight : Alignment.centerLeft,

                        child: Container(
                            padding: const EdgeInsets.all(10),
                            margin: isFirstMessageFromSender
                                ? const EdgeInsets.symmetric(vertical: 5)
                                : const EdgeInsets.symmetric(vertical: 2),
                            constraints: const BoxConstraints(maxWidth: 250),
                            decoration: BoxDecoration(
                              color: isSender ? Colors.blue : Colors.grey
                                  .shade300,
                              borderRadius: BorderRadius.only(
                                topLeft: isSender
                                    ? const Radius.circular(15)
                                    : Radius.circular(
                                    isFirstMessageFromSender ? 0 : 15),
                                topRight: const Radius.circular(15),
                                bottomLeft: const Radius.circular(15),
                                bottomRight: isSender
                                    ? Radius.circular(
                                    isFirstMessageFromSender ? 0 : 15)
                                    : const Radius.circular(15),
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
                              isSender
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
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
                                    color: isSender ? Colors.white : Colors
                                        .black,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat.jm()
                                      .format(message.timestamp),
                                  // Show only time
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            )
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                            openImageDialog(); // Open Dialog Box
                          },
                          icon: const Icon(Icons.image),
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
