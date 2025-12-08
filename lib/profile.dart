import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_controller.dart';
import 'login.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileController _controller = ProfileController();
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _controller.loadSavedProfile();
    if (mounted) {
      setState(() => _loadingProfile = false);
    }
  }

  // ============ LOGOUT ============
  Future<void> _logout() async {
    await _controller.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ============ CAMBIAR FOTO ============
  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final result = await _controller.pickAndUploadImage(source);
      if (!mounted) return;
      
      if (result != null) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Foto de perfil actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
                  _pickAndUpload(ImageSource.camera);
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
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ============ EDITAR SOLO NOMBRE ============
  void _showEditNameDialog() {
    final nameCtrl = TextEditingController(text: _controller.displayName);
    
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
          controller: nameCtrl,
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
              final name = nameCtrl.text.trim();
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
    try {
      // Solo actualiza el nombre, mantiene el email actual
      await _controller.updateProfile(name: name, email: _controller.email);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Nombre actualizado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============ PREFERENCIAS ============
  Widget _buildPreferencesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              _controller.darkMode ? Icons.dark_mode : Icons.light_mode,
              color: _controller.darkMode ? Colors.amber : Colors.orange,
            ),
            title: const Text('Tema oscuro'),
            subtitle: Text(
              _controller.darkMode ? 'Activado' : 'Desactivado',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            value: _controller.darkMode,
            activeColor: Colors.teal,
            onChanged: (v) async {
              await _controller.toggleTheme(v);
              if (!mounted) return;
              setState(() {});
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(
              _controller.notificationsEnabled 
                  ? Icons.notifications_active 
                  : Icons.notifications_off,
              color: _controller.notificationsEnabled ? Colors.teal : Colors.grey,
            ),
            title: const Text('Notificaciones'),
            subtitle: Text(
              _controller.notificationsEnabled ? 'Activadas' : 'Desactivadas',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            value: _controller.notificationsEnabled,
            activeColor: Colors.teal,
            onChanged: (v) async {
              await _controller.toggleNotifications(v);
              if (!mounted) return;
              setState(() {});
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

    final themeData = _controller.darkMode ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: themeData.copyWith(
        colorScheme: themeData.colorScheme.copyWith(primary: Colors.teal),
      ),
      child: Scaffold(
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
                      backgroundImage: _controller.localImage != null
                          ? FileImage(_controller.localImage!)
                          : NetworkImage(_controller.imageUrl) as ImageProvider,
                    ),
                  ),
                  if (_controller.uploading)
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
                      onTap: _controller.uploading ? null : _showImageOptions,
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
                      _controller.displayName.isEmpty 
                          ? 'Sin nombre' 
                          : _controller.displayName,
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
                _controller.email.isEmpty 
                    ? 'correo@ejemplo.com' 
                    : _controller.email,
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
                        _controller.displayName.isEmpty 
                            ? 'No establecido' 
                            : _controller.displayName,
                        editable: true,
                        onEdit: _showEditNameDialog,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.email,
                        'Correo electrónico',
                        _controller.email.isEmpty 
                            ? 'No disponible' 
                            : _controller.email,
                        editable: false, // ← EMAIL NO EDITABLE
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
              _buildPreferencesCard(),
              
              const SizedBox(height: 32),
              
              // ===== BOTÓN CERRAR SESIÓN =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
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
}