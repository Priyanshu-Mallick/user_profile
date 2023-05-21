// import 'dart:html';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:user_profile/services/Topic.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_screen.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;


class ChatRooms extends StatefulWidget {
  const ChatRooms({Key? key});

  @override
  _ChatRoomsState createState() => _ChatRoomsState();
}

class _ChatRoomsState extends State<ChatRooms> {
  List<Topic> topics = [];
  String searchText = '';

  void handleSearch(String value) {
    EasyDebounce.debounce(
      'search-bar-debouncer',                        // Debouncer ID
      const Duration(milliseconds: 1500),            // Debounce duration
          () => setState(() => searchText = value),  // Target method
    );
  }

  void addTopic(String name, String description) {
    final topic = Topic(name: name, description: description);

    // Store topic in Firestore - roomTopic collection under chatuser
    FirebaseFirestore.instance
        .collection('chatuser')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('roomTopic')
        .add(topic.toMap())
        .then((value) {
      // Add the topic to the local list
      setState(() {
        topic.id = value.id;
        topics.add(topic);
      });
      Navigator.pop(context); // Close the popup dialog after saving
    }).catchError((error) {
      print('Failed to add topic: $error');
      // Handle the error if necessary
    });

    // Store topic in Firestore - chatrooms collection
    FirebaseFirestore.instance
        .collection('chatrooms')
        .add(topic.toMap())
        .then((value) {
      // Handle the successful addition to chatrooms collection
    }).catchError((error) {
      print('Failed to add topic to chatrooms collection: $error');
      // Handle the error if necessary
    });
  }


  @override
  void initState() {
    super.initState();
    fetchTopics();
  }

  void fetchTopics() {
    FirebaseFirestore.instance
        .collection('chatrooms')
        .get()
        .then((snapshot) {
      setState(() {
        topics = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Topic.fromMap(data, id: doc.id);
        }).toList();
      });
    }).catchError((error) {
      print('Failed to fetch topics: $error');
      // Handle the error if necessary
    });
  }


  List<Topic> getFilteredTopics() {
    if (searchText.isEmpty) {
      return topics;
    } else {
      return topics.where((topic) {
        final name = topic.name.toLowerCase();
        final search = searchText.toLowerCase();
        return name.contains(search);
      }).toList();
    }
  }

  Future<void> _selectAndCropImage() async {
    final pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Adjust the aspect ratio as needed
        compressQuality: 70, // Adjust the compression quality as needed
        maxWidth: 800, // Adjust the maximum width as needed
        maxHeight: 800, // Adjust the maximum height as needed
      );

      if (croppedFile != null) {
        // Upload the cropped image to Firebase Storage
        final storageRef = firebase_storage.FirebaseStorage.instance.ref().child('groupicon').child(DateTime.now().millisecondsSinceEpoch.toString());
        final uploadTask = storageRef.putFile(File(croppedFile.path));

        // Get the download URL of the uploaded image
        final snapshot = await uploadTask.whenComplete(() {});
        final downloadURL = await snapshot.ref.getDownloadURL();

        // Store the download URL in Firestore
        final chatRoomRef = FirebaseFirestore.instance.collection('chatrooms').doc(FirebaseAuth.instance.currentUser?.uid);
        chatRoomRef.update({'groupicon': downloadURL});
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final filteredTopics = getFilteredTopics();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatRooms'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chatuser')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: SpinKitFadingCircle(
                color: Theme.of(context).primaryColor,
                size: 50.0,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Text('No data available');
          }
          final data = snapshot.data!.data();
          final username = data?['username'] ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Username: $username',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          handleSearch(value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search chat room by Topic name',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredTopics.isEmpty
                    ? const Center(
                  child: Text(
                    'Chatroom not found, Create your own',
                    style: TextStyle(fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  itemCount: filteredTopics.length,
                  itemBuilder: (context, index) {
                    final topic = filteredTopics[index];
                    return InkWell(
                      onTap: () {
                        // Navigate to ChatScreen with the selected topic
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(topic: topic, username: username),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(topic.name),
                            subtitle: Text(topic.description),
                          ),
                          const Divider(
                            color: Colors.grey,
                            height: 1,
                            thickness: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              String name = '';
              String description = '';
              File? image;

              // Function to handle selecting a new image for the profile picture
              Future<void> _pickImage() async {
                final pickedFile = await ImagePicker().getImage(
                  source: ImageSource.gallery,
                );

                setState(() {
                  if (pickedFile != null) {
                    image = File(pickedFile.path);
                  } else {
                    print('No image selected.');
                  }
                });
              }

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            // Display the selected image if available, otherwise show the default icon
                            backgroundImage: image != null ? FileImage(image!) : null,
                            radius: 50.0,
                            child: image == null ? const Icon(Icons.person) : null,
                          ),
                          Positioned(
                            bottom: 0.0,
                            right: 0.0,
                            child: GestureDetector(
                              onTap: () {
                                // _selectAndCropImage();
                              },
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                radius: 20.0,
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Topic Name',
                        ),
                        onChanged: (value) {
                          name = value;
                        },
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Topic Description',
                        ),
                        onChanged: (value) {
                          description = value;
                        },
                      ),
                      SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              addTopic(name, description);
                            },
                            child: const Text('Save'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close the dialog without saving
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}