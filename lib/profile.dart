import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'theme_provider.dart';
import 'notification_service.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingProfile = true;
  String? _photoUrl;
  File? _localImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _fs.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null && mounted) {
        setState(() {
          _nameCtrl.text = data['displayName'] ?? user.displayName ?? '';
          _photoUrl = data['photoUrl'] ?? user.photoURL;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() {
        _loading = true;
        _localImage = File(image.path);
      });

      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // Subir imagen a Firebase Storage
      final ref = _storage.ref().child('profile_photos/${user.uid}.jpg');
      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();

      // Actualizar Firestore
      await _fs.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });

      // Actualizar perfil de Auth
      await user.updatePhotoURL(downloadUrl);

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
          _loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Foto de perfil actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _localImage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.photo_camera, color: Colors.white),
                ),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Elegir de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final nameController = TextEditingController(text: _nameCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.teal),
            SizedBox(width: 8),
            Text('Editar nombre'),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ingresa tu nombre',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre no puede estar vacío')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _updateName(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      await user.updateDisplayName(name);
      await _fs.collection('users').doc(user.uid).update({
        'displayName': name,
      });

      if (mounted) {
        setState(() {
          _nameCtrl.text = name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Nombre actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildPreferencesCard(ThemeProvider themeProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              themeProvider.darkMode ? Icons.dark_mode : Icons.light_mode,
              color: themeProvider.darkMode ? Colors.amber : Colors.orange,
            ),
            title: const Text('Tema oscuro'),
            subtitle: Text(
              themeProvider.darkMode ? 'Activado' : 'Desactivado',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            value: themeProvider.darkMode,
            activeColor: Colors.teal,
            onChanged: (v) {
              themeProvider.toggleTheme(v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(
              themeProvider.notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: themeProvider.notificationsEnabled ? Colors.teal : Colors.grey,
            ),
            title: const Text('Notificaciones'),
            subtitle: Text(
              themeProvider.notificationsEnabled ? 'Activadas' : 'Desactivadas',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            value: themeProvider.notificationsEnabled,
            activeColor: Colors.teal,
            onChanged: (v) {
              themeProvider.toggleNotifications(v);
            },
          ),
          // Después de las preferencias, antes del botón cerrar sesión:

const SizedBox(height: 16),

// BOTÓN PARA PROBAR NOTIFICACIONES
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  child: Column(
    children: [
      ListTile(
        leading: const Icon(Icons.notifications_active, color: Colors.teal),
        title: const Text('Probar Notificación'),
        subtitle: const Text('Enviar notificación de prueba ahora'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await NotificationService().showTestNotification();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Notificación de prueba enviada'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.schedule, color: Colors.orange),
        title: const Text('Ver Recordatorios Activos'),
        subtitle: const Text('Notificaciones programadas'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final pending = await NotificationService().getPendingNotifications();
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text('Recordatorios (${pending.length})'),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: pending.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No hay recordatorios programados'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: pending.length,
                          itemBuilder: (_, i) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.alarm, color: Colors.teal),
                              title: Text(pending[i].title ?? 'Sin título'),
                              subtitle: Text(pending[i].body ?? ''),
                            ),
                          ),
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    ],
  ),
),

ListTile(
  leading: const Icon(Icons.cloud, color: Colors.purple),
  title: const Text('Probar Push (Cloud)'),
  subtitle: const Text('Enviar desde Firebase'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuario logueado')),
      );
      return;
    }

    try {
      final url = Uri.parse(
        'https://us-central1-control-habitos.cloudfunctions.net/sendTestNotification?userId=$userId'
      );
      
      final response = await http.get(url);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.statusCode == 200 
              ? '✓ Notificación push enviada' 
              : 'Error: ${response.body}'),
            backgroundColor: response.statusCode == 200 ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  },
),
        ],
        
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _auth.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ===== FOTO DE PERFIL =====
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _localImage != null
                        ? FileImage(_localImage!)
                        : (_photoUrl != null && _photoUrl!.isNotEmpty
                            ? NetworkImage(_photoUrl!) as ImageProvider
                            : null),
                    child: (_localImage == null && (_photoUrl == null || _photoUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 70, color: Colors.white)
                        : null,
                  ),
                ),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _loading ? null : _showImageOptions,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===== NOMBRE CON BOTÓN EDITAR =====
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _nameCtrl.text.isEmpty ? 'Sin nombre' : _nameCtrl.text,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: _showEditNameDialog,
                  icon: const Icon(Icons.edit, color: Colors.teal),
                  tooltip: 'Editar nombre',
                ),
              ],
            ),

            // ===== EMAIL (SOLO LECTURA) =====
            Text(
              user?.email ?? 'correo@ejemplo.com',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            // ===== CARD DE INFORMACIÓN =====
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información de la cuenta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.person,
                      'Nombre',
                      _nameCtrl.text.isEmpty ? 'No establecido' : _nameCtrl.text,
                      editable: true,
                      onEdit: _showEditNameDialog,
                    ),
                    const Divider(),
                    _buildInfoRow(
                      Icons.email,
                      'Correo electrónico',
                      user?.email ?? 'No disponible',
                      editable: false,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ===== PREFERENCIAS =====
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Preferencias',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _buildPreferencesCard(themeProvider),

            const SizedBox(height: 32),

            // ===== BOTÓN CERRAR SESIÓN =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool editable = false,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          if (editable && onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 20),
              color: Colors.teal,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}