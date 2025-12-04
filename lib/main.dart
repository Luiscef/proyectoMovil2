// main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_config.dart';
import 'profile.dart';
import 'login.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class StorageService {
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future<String?> uploadImage(File imageFile, String folder) async {
    final String nameFile = DateTime.now().millisecondsSinceEpoch.toString() +
        "_" +
        imageFile.path.split('/').last;
    final Reference ref = storage.ref().child(folder).child(nameFile);
    final UploadTask task = ref.putFile(imageFile);
    final TaskSnapshot snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }
}

class FirestoreService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Guarda el URL en users/{uid} bajo el campo 'photoUrl'
  Future<void> saveProfilePhotoUrl(String uid, String url) async {
    final docRef = firestore.collection('users').doc(uid);
    await docRef.set({'photoUrl': url}, SetOptions(merge: true));
  }

  // Recupera el URL si existe, devuelve null si no
  Future<String?> getProfilePhotoUrl(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['photoUrl'] is String) {
        return data['photoUrl'] as String;
      }
    }
    return null;
  }
}

class LogoRotate extends StatefulWidget {
  const LogoRotate({super.key});
  @override
  State<LogoRotate> createState() => _LogoRotateState();
}

class _LogoRotateState extends State<LogoRotate> {
  final StorageService _storage = StorageService();
  final FirestoreService _firestore = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  // URL por defecto (se mostrará hasta que haya una guardada en Firestore)
  String imageUrl =
      'https://preview.redd.it/i-tried-to-remake-walter-white-skateboarding-v0-nvdd0uwwo4ne1.jpg?width=736&format=pjpg&auto=webp&s=d59d1fbdd478865f12c2c4beb76457691925885b';

  File? _localImage;
  bool _uploading = false;
  double turns = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSavedProfilePhoto();
  }

  Future<String> _getProfileDocId() async {
    final user = FirebaseAuth.instance.currentUser;
    // Si no hay usuario, usamos 'public_profile' para pruebas
    return user?.uid ?? 'public_profile';
  }

  Future<void> _loadSavedProfilePhoto() async {
    final String docId = await _getProfileDocId();
    final String? savedUrl = await _firestore.getProfilePhotoUrl(docId);
    if (savedUrl != null && mounted) {
      setState(() {
        imageUrl = savedUrl;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final File file = File(picked.path);

    setState(() {
      _localImage = file; // previsualización local
      _uploading = true;
    });

    try {
      final String? url = await _storage.uploadImage(file, 'profile_images');
      if (url != null) {
        final String docId = await _getProfileDocId();
        await _firestore.saveProfilePhotoUrl(docId, url);

        if (!mounted) return;
        setState(() {
          imageUrl = url;
          _localImage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la imagen')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error inesperado al subir la imagen')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double imageSize = 180.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 30),
            const Text(
              'nombre de usuario',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // FOTO + BOTON CAMBIAR
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: turns,
                  duration: const Duration(seconds: 1),
                  child: ClipOval(
                    child: SizedBox(
                      height: imageSize,
                      width: imageSize,
                      child: _localImage != null
                          ? Image.file(_localImage!, fit: BoxFit.cover)
                          : Image.network(imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),

                if (_uploading)
                  Container(
                    height: imageSize,
                    width: imageSize,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  ),

                Positioned(
                  right: 0,
                  bottom: 0,
                  child: FloatingActionButton(
                    heroTag: 'changePhoto',
                    mini: true,
                    onPressed: _uploading ? null : _pickAndUploadImage,
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'correo electronico',
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            Text(
              'qqqqqqqqqqqqq',
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
