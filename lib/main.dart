import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:user_profile/services/auth_service.dart';
import 'bookdetails.dart';
import 'chat_room.dart';
import 'firebase_options.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Data Fill Page',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const UserFormData(),
    );
  }
}

class UserFormData extends StatefulWidget {
  const UserFormData({Key? key});

  @override
  _UserFormDataState createState() => _UserFormDataState();
}

class _UserFormDataState extends State<UserFormData> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late int _age;
  late String _bio;
  late String _interests;
  late String _profession;

  get floatingActionButton => null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Data Fill Page'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Age',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your age';
                  }
                  return null;
                },
                onSaved: (value) {
                  _age = int.parse(value!);
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Bio',
                ),
                maxLines: null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your bio';
                  }
                  return null;
                },
                onSaved: (value) {
                  _bio = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Interests',
                ),
                maxLines: null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your interests';
                  }
                  return null;
                },
                onSaved: (value) {
                  _interests = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Profession',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your profession';
                  }
                  return null;
                },
                onSaved: (value) {
                  _profession = value!;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          // save data to Firebase
                          Map<String,dynamic> data={
                            'name': _name,
                            'age': _age,
                            'bio': _bio,
                            'interests': _interests,
                            'profession': _profession,
                          };
                          FirebaseFirestore.instance.collection("Users").add(data);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User data saved'),
                            ),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BookDetails()),

                        );
                      },
                      child: const Text('Book Deatils'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return WillPopScope(
                onWillPop: () async => false, // Disable popping with back button
                child: Center(
                  child: SpinKitFadingCircle(
                    color: Theme.of(context).primaryColor,
                    size: 50.0,
                  ),
                ),
              );
            },
          );
          final user = await AuthService().signInWithGoogle();
          Navigator.pop(context); // Close the buffering animation dialog
          if (user != null) {
            final displayName = await AuthService().getUserDisplayName();
            final userName = await AuthService().getUniqueUsername(displayName!);
            await AuthService().storeUserDisplayName(displayName!, userName);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatRooms(),
              ),
            );
          }
        },
        child: const Icon(Feather.message_square), // Use the chat icon from the Flutter Icons package
      ),
    );
  }
}