import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class BookDetails extends StatefulWidget {
  @override
  _BookDetailsState createState() => _BookDetailsState();
}

class _BookDetailsState extends State<BookDetails> {
  final _formKey = GlobalKey<FormState>();
  late String _bname;
  late String _aname;
  late String _bdesc;
  late String _lcomment;
  double? lat;
  double? long;
  String address = "";
  String currentLocation = 'Tap the button to get current location';

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  getLatLong() {
    Future<Position> data = _determinePosition();
    data.then((value) {
      // print("value $value");
      setState(() {
        lat = value.latitude;
        long = value.longitude;
      });
    }).catchError((error) {
      print("Error $error");
    });
  }

  updateText() {
    setState(() {
      currentLocation = address;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Data Fill page'),
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
                  labelText: 'Book Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the book name';
                  }
                  return null;
                },
                onSaved: (value) {
                  _bname = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Author Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Author name';
                  }
                  return null;
                },
                onSaved: (value) {
                  _aname = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Book Description',
                ),
                maxLines: null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Give some description for book';
                  }
                  return null;
                },
                onSaved: (value) {
                  _bdesc = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Lender\'s Comment',
                ),
                maxLines: null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Leave a comment';
                  }
                  return null;
                },
                onSaved: (value) {
                  _lcomment = value!;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      currentLocation,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: () async {
                      await getLatLong();
                      List<Placemark> placemarks =
                          await placemarkFromCoordinates(lat!, long!);
                      setState(() {
                        address =
                            '${placemarks[0].street}, ${placemarks[0].subLocality}, ${placemarks[0].locality}, ${placemarks[0].administrativeArea}, ${placemarks[0].country}, ${placemarks[0].postalCode}';
                      });
                      updateText();
                    },
                    child: const Icon(Icons.location_on),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    await FirebaseFirestore.instance.collection('Books').add({
                      'book_name': _bname,
                      'author_name': _aname,
                      'book_description': _bdesc,
                      'lender_comment': _lcomment,
                      'location': address,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Book data added successfully!')),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Please fill in all the details and tap the location button!')),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
