
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

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? ProfileController();

    _controller.loadSavedProfilePhoto().then((url) {
      if (url != null && mounted) setState(() {});
    }).catchError((_) {});
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    const double imageSize = 180.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'nombre de usuario',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    
                  },
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
              'correo electronico',
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
