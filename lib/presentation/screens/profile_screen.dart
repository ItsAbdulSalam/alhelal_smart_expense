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
    _email = user?.email ?? 'user@alhelal.dev';
    final metaName = user?.userMetadata?['full_name']?.toString().trim();
    _displayName = (metaName != null && metaName.isNotEmpty)
        ? metaName
        : _nameFromEmail(_email);

    _avatarUrl = user?.userMetadata?['avatar_url']?.toString();
    if (_avatarUrl?.trim().isEmpty == true) _avatarUrl = null;

    _nameController = TextEditingController(text: _displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _nameFromEmail(String email) {
    if (!email.contains('@')) return 'المستخدم';
    final name = email.split('@').first.replaceAll('.', ' ');
    return name.isEmpty ? 'المستخدم' : name;
  }

  void _notify(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: isError
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
        ),
      );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar || _user == null) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingAvatar = true);
      final Uint8List bytes = await pickedFile.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('الحد الأقصى لحجم الصورة هو 5 ميجابايت.');
      }

      final ext = pickedFile.name.split('.').last.toLowerCase();
      final validExt = ['png', 'webp', 'jpg', 'jpeg'].contains(ext)
          ? ext
          : 'jpg';
      final path = '${_user!.id}/avatar.$validExt';

      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$validExt',
            ),
          );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      final cacheBustedUrl =
          '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      // ignore: unused_local_variable
      final res = await _supabase.auth.updateUser(
        UserAttributes(
          data: {...?_user?.userMetadata, 'avatar_url': cacheBustedUrl},
        ),
      );

      if (!mounted) return;
      setState(() {
        _avatarUrl = cacheBustedUrl;
      });

      _notify('تم تحديث الصورة الشخصية بنجاح.');
    } catch (e) {
      _notify('فشل تحميل الصورة: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _user == null) return;
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _notify('يرجى إدخال اسم صحيح لا يقل عن حرفين.', isError: true);
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
      _notify('تم حفظ التعديلات بنجاح.');
    } catch (e) {
      _notify('حدث خطأ أثناء حفظ البيانات.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // حل تباين الخلفية ومنع البهتان في وضع النظام والوضع الفاتح
    final scaffoldBg = isDark
        ? const Color(0xFF030712)
        : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'الملف الشخصي والإعدادات',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildHeroBanner(
                  isDark,
                  cardBg,
                  borderColor,
                  textColor,
                  subTextColor,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  'المعلومات الأساسية',
                  'بيانات الحساب الشخصي المعروضة بالمنصة',
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  cardBg,
                  borderColor,
                  textColor,
                  subTextColor,
                  isDark,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  'المظهر والنظام',
                  'تخصيص الثيم والألوان لتلائم رؤيتك',
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildAppearanceCard(
                  cardBg,
                  borderColor,
                  textColor,
                  subTextColor,
                  isDark,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  'حالة الحساب والأمان',
                  'توثيق الحساب والبريد المعتمد',
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildAccountStatusCard(
                  cardBg,
                  borderColor,
                  textColor,
                  subTextColor,
                  isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFF64748B).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Container(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    child: _isUploadingAvatar
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? Image.network(
                            _avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallbackAvatar(),
                          )
                        : _fallbackAvatar(),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: const Color(0xFF4F46E5),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _displayName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  style: TextStyle(color: subTextColor, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text(
                    'تغيير الصورة الشخصية',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    final char = _displayName.trim().isNotEmpty
        ? _displayName.trim()[0].toUpperCase()
        : 'U';
    return Center(
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            enabled: _isEditing,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'الاسم الكامل',
              labelStyle: TextStyle(color: subTextColor),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: subTextColor,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0B132B)
                  : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF4F46E5),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _email,
            enabled: false,
            style: TextStyle(color: subTextColor),
            decoration: InputDecoration(
              labelText: 'البريد الإلكتروني (غير قابل للتعديل)',
              labelStyle: TextStyle(color: subTextColor),
              prefixIcon: Icon(Icons.email_outlined, color: subTextColor),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF070D1E)
                  : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isEditing) ...[
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _nameController.text = _displayName;
                          setState(() => _isEditing = false);
                        },
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF4F46E5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Color(0xFF4F46E5),
                  ),
                  label: const Text(
                    'تعديل البيانات',
                    style: TextStyle(color: Color(0xFF4F46E5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              _themeOption(
                title: 'تلقائي (النظام)',
                icon: Icons.brightness_auto_rounded,
                selected: currentMode == ThemeMode.system,
                onTap: () => ThemeController.setThemeMode(ThemeMode.system),
                isDark: isDark,
              ),
              _themeOption(
                title: 'فاتح (Light)',
                icon: Icons.light_mode_rounded,
                selected: currentMode == ThemeMode.light,
                onTap: () => ThemeController.setThemeMode(ThemeMode.light),
                isDark: isDark,
              ),
              _themeOption(
                title: 'داكن (Dark)',
                icon: Icons.dark_mode_rounded,
                selected: currentMode == ThemeMode.dark,
                onTap: () => ThemeController.setThemeMode(ThemeMode.dark),
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOption({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4F46E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? Colors.white
                    : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF334155)),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountStatusCard(
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x1A10B981),
              child: Icon(
                Icons.shield_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            title: Text(
              'حالة الحساب',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'حساب نشط وموثق',
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x1A10B981),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'موثق',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
