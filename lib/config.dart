// lib/core/firebase_config.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseConfig {
  static const String dbUrl =
      'https://biocollarsystem-default-rtdb.firebaseio.com';

  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBA0Z6v845KdcqVC2vDmwm-xteAlNVatbo',
        appId: '1:412699555807:android:79f7e76f7d30ee735b766a',
        messagingSenderId: '412699555807',
        projectId: 'biocollarsystem',
        storageBucket: 'biocollarsystem.firebasestorage.app',
        databaseURL: dbUrl,
      ),
    );
  }

  static DatabaseReference rootRef() =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: dbUrl)
          .ref();

  static DatabaseReference ref(String path) =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: dbUrl)
          .ref(path);
}
