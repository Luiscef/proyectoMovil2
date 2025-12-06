// lib/profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_controller.dart';

class LogoRotate extends StatefulWidget {
  final ProfileController? controller;
  const LogoRotate({super.key, this.controller});

  @override
  State<LogoRotate> createState() => _LogoRotateState();
}

class _LogoRotateState extends State<LogoRotate> {
  late final ProfileController _controller;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ProfileController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _controller.loadSavedProfile();
    if (mounted) {
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final result = await _controller.pickAndUploadImage(source);
      if (result != null) {
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se actualizó la imagen')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar foto'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUpload(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de la galería'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUpload(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _controller.displayName);
    final emailCtrl = TextEditingController(text: _controller.email);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre y correo requeridos')));
                  return;
                }
                Navigator.pop(ctx);
                _updateProfileFlow(name, email);
              },
              child: const Text('Guardar'),
            )
          ],
        );
      },
    );
  }

  Future<void> _updateProfileFlow(String name, String email) async {
    try {
      await _controller.updateProfile(name: name, email: email);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('requires-recent-login')) {
        final password = await _askForPassword();
        if (password != null) {
          try {
            final ok = await _controller.reauthenticateAndUpdateEmail(password, email);
            if (ok) {
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo actualizado tras re-autenticación')));
            }
          } catch (e2) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al re-autenticar: $e2')));
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    }
  }

  Future<String?> _askForPassword() async {
    final pwdCtrl = TextEditingController();
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Re-autenticación requerida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa tu contraseña actual para confirmar el cambio de correo.'),
              const SizedBox(height: 8),
              TextField(
                controller: pwdCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                result = pwdCtrl.text;
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    return result;
  }

  Widget _buildPreferences() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Tema oscuro'),
          subtitle: const Text('Alternar entre claro y oscuro (aplica en esta pantalla)'),
          value: _controller.darkMode,
          onChanged: (v) async {
            await _controller.toggleTheme(v);
            if (!mounted) return;
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tema guardado')));
          },
        ),
        SwitchListTile(
          title: const Text('Notificaciones'),
          subtitle: const Text('Activar o desactivar recordatorios'),
          value: _controller.notificationsEnabled,
          onChanged: (v) async {
            await _controller.toggleNotifications(v);
            if (!mounted) return;
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferencia guardada')));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    const double imageSize = 180.0;
    final ThemeData themePreview = controller.darkMode ? ThemeData.dark() : ThemeData.light();

    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Theme(
      data: themePreview,
      child: Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      controller.displayName.isEmpty ? 'Sin nombre' : controller.displayName,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _showEditProfileDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        height: imageSize,
                        width: imageSize,
                        child: controller.localImage != null
                            ? Image.file(controller.localImage!, fit: BoxFit.cover)
                            : Image.network(controller.imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                    if (controller.uploading)
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
                        onPressed: controller.uploading ? null : _showPickOptions,
                        child: const Icon(Icons.camera_alt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  controller.email.isEmpty ? 'correo no disponible' : controller.email,
                  style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                _buildPreferences(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
