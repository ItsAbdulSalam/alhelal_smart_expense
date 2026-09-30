import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  String _displayName = '';
  String _email = '';
  String? _avatarUrl;

  User? get _user => _supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();

    final user = _user;
    _email = user?.email ?? 'No email';

    final metadataName = user?.userMetadata?['full_name']?.toString().trim();

    _displayName = metadataName?.isNotEmpty == true
        ? metadataName!
        : _nameFromEmail(_email);

    _avatarUrl = user?.userMetadata?['avatar_url']?.toString();

    if (_avatarUrl?.trim().isEmpty == true) {
      _avatarUrl = null;
    }

    _nameController = TextEditingController(text: _displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _nameFromEmail(String email) {
    if (!email.contains('@')) {
      return 'User';
    }

    final value = email.split('@').first.trim();

    return value.isEmpty ? 'User' : value;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? const Color(0xFFDC2626)
              : const Color(0xFF059669),
        ),
      );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar || _user == null) {
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() => _isUploadingAvatar = true);

      final Uint8List bytes = await pickedFile.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Image must be smaller than 5 MB.');
      }

      final extension = _fileExtension(pickedFile.name);
      final path = '${_user!.id}/avatar.$extension';

      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentType(extension),
            ),
          );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

      // Cache busting so the browser immediately displays the new avatar.
      final avatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase.auth.updateUser(
        UserAttributes(
          data: {...?_user?.userMetadata, 'avatar_url': avatarUrl},
        ),
      );

      if (!mounted) return;

      setState(() {
        _avatarUrl = avatarUrl;
      });

      _showMessage('Profile photo updated successfully.');
    } catch (error) {
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  String _fileExtension(String fileName) {
    final parts = fileName.toLowerCase().split('.');

    if (parts.length < 2) {
      return 'jpg';
    }

    final extension = parts.last;

    if (extension == 'jpeg' ||
        extension == 'jpg' ||
        extension == 'png' ||
        extension == 'webp') {
      return extension;
    }

    return 'jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _user == null) {
      return;
    }

    final name = _nameController.text.trim();

    if (name.length < 2) {
      _showMessage('Please enter a valid name.', error: true);
      return;
    }

    try {
      setState(() => _isSaving = true);

      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...?_user?.userMetadata,
            'full_name': name,
            if (_avatarUrl != null) 'avatar_url': _avatarUrl,
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        _displayName = name;
        _isEditing = false;
      });

      _showMessage('Profile updated successfully.');
    } catch (error) {
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEditing() {
    _nameController.text = _displayName;

    setState(() {
      _isEditing = false;
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('row-level security')) {
      return 'You do not have permission to perform this action.';
    }

    if (message.contains('Payload too large')) {
      return 'The selected image is too large.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    final horizontalPadding = width < 600 ? 16.0 : 24.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                48,
              ),
              children: [
                _buildProfileHero(context),

                const SizedBox(height: 32),

                _SectionTitle(
                  icon: Icons.person_outline_rounded,
                  title: 'Personal information',
                  subtitle: 'Manage your personal account details.',
                ),

                const SizedBox(height: 14),

                _buildPersonalInformation(context),

                const SizedBox(height: 32),

                _SectionTitle(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Choose how Alhelal Smart Expense looks.',
                ),

                const SizedBox(height: 14),

                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.themeMode,
                  builder: (context, currentMode, _) {
                    return _AppearanceCard(currentMode: currentMode);
                  },
                ),
                const SizedBox(height: 32),

                _SectionTitle(
                  icon: Icons.shield_outlined,
                  title: 'Account',
                  subtitle: 'Your account and authentication information.',
                ),

                const SizedBox(height: 14),

                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        leading: _TileIcon(
                          icon: Icons.email_outlined,
                          color: colors.primary,
                        ),
                        title: const Text('Email address'),
                        subtitle: Text(_email),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        leading: _TileIcon(
                          icon: Icons.verified_user_outlined,
                          color: colors.primary,
                        ),
                        title: const Text('Account status'),
                        subtitle: const Text('Active account'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primary.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;

            final avatar = _AvatarEditor(
              name: _displayName,
              avatarUrl: _avatarUrl,
              loading: _isUploadingAvatar,
              onPressed: _pickAndUploadAvatar,
            );

            final information = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _email,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Change photo'),
                ),
              ],
            );

            if (compact) {
              return Column(
                children: [avatar, const SizedBox(height: 20), information],
              );
            }

            return Row(
              children: [
                avatar,
                const SizedBox(width: 26),
                Expanded(child: information),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPersonalInformation(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (_isEditing) {
                  _saveProfile();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              enabled: false,
              initialValue: _email,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isEditing) ...[
                  TextButton(
                    onPressed: _isSaving ? null : _cancelEditing,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _isEditing = true);
                    },
                    icon: Icon(Icons.edit_outlined, color: colors.primary),
                    label: const Text('Edit profile'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool loading;
  final VoidCallback onPressed;

  const _AvatarEditor({
    required this.name,
    required this.avatarUrl,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 116,
          height: 116,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.24),
          ),
          child: ClipOval(
            child: Material(
              color: Colors.white.withValues(alpha: 0.14),
              child: InkWell(
                onTap: loading ? null : onPressed,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : hasAvatar
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return _AvatarFallback(name: name);
                        },
                      )
                    : _AvatarFallback(name: name),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 2,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: loading ? null : onPressed,
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileIcon(icon: icon, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TileIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final ThemeMode currentMode;

  const _AppearanceCard({required this.currentMode});

  String _modeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData _modeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<ThemeMode>(
        tooltip: 'Change appearance',
        position: PopupMenuPosition.under,
        onSelected: ThemeController.setThemeMode,
        itemBuilder: (context) {
          return [
            _buildItem(
              context,
              mode: ThemeMode.system,
              icon: Icons.brightness_auto_rounded,
              title: 'System',
              subtitle: 'Use your device appearance',
            ),
            _buildItem(
              context,
              mode: ThemeMode.light,
              icon: Icons.light_mode_rounded,
              title: 'Light',
              subtitle: 'Always use light appearance',
            ),
            _buildItem(
              context,
              mode: ThemeMode.dark,
              icon: Icons.dark_mode_rounded,
              title: 'Dark',
              subtitle: 'Always use dark appearance',
            ),
          ];
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _modeIcon(currentMode),
                  color: colors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose your preferred appearance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Text(
                _modeName(currentMode),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(width: 6),

              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<ThemeMode> _buildItem(
    BuildContext context, {
    required ThemeMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = currentMode == mode;

    return PopupMenuItem<ThemeMode>(
      value: mode,
      height: 64,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? colors.primary : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (selected)
            Icon(Icons.check_rounded, color: colors.primary, size: 21),
        ],
      ),
    );
  }
}
