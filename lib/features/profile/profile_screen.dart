import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/widgets/ui.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_details.dart';
import 'widgets/profile_edit_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _userService = UserService();

  User? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() { _isLoading = true; _error = null; });
    final user = await _authService.me();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (user != null) { _user = user; }
      else { _error = 'No se pudo cargar el perfil'; }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
    ));
  }

  Future<void> _openEditSheet() async {
    if (_user == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileEditSheet(
        user: _user!,
        onSave: (data) async {
          final result = await _userService.update(_user!.id, data);
          if (!mounted) return;
          Navigator.of(context).pop();
          if (result.success && result.user != null) {
            await LocalStorage.updateUser(result.user!);
            setState(() => _user = result.user);
            _showSnack('Perfil actualizado correctamente');
          } else {
            _showSnack(result.message, isError: true);
          }
        },
      ),
    );
  }

  Future<void> _logout() async {
    await ConfirmDialog.show(
      context: context,
      title: 'Cerrar sesión',
      content: '¿Estás seguro que deseas cerrar sesión?',
      confirmText: 'Cerrar sesión',
      isDestructive: true,
      onConfirm: () async {
        await _authService.logout();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: AppColors.danger),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _buildBody(cs, isDark),
    );
  }

  Widget _buildBody(ColorScheme cs, bool isDark) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_error != null || _user == null) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Error al cargar',
        subtitle: _error ?? 'No se pudo obtener la información del perfil',
        onAction: _loadUser,
        actionText: 'Reintentar',
      );
    }

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: _loadUser,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(user: _user!),
            const SizedBox(height: 28),
            AppButton(
              text: 'Editar perfil',
              icon: Icons.edit_outlined,
              onPressed: _openEditSheet,
            ),
            const SizedBox(height: 28),
            ProfileDetails(user: _user!),
            const SizedBox(height: 28),
            AppButton.destructive(
              text: 'Cerrar sesión',
              icon: Icons.logout_rounded,
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
