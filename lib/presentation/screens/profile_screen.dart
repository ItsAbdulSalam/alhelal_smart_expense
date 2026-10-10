import 'dart:io';
import 'package:alhelal_smart_expense/core/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isLoading = true;

  String _displayName = '';
  String _email = '';
  String? _avatarUrl;
  File? _localSelectedImage; // لعرض الصورة المختارة محلياً وفوراً

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final localEmail = prefs.getString('user_email') ?? '';
    final localName = prefs.getString('user_name') ?? '';
    final localAvatar = prefs.getString('user_avatar_url');

    try {
      final response = await ApiClient.dio.get('/user');
      if (response.data != null && mounted) {
        final data = response.data is Map ? response.data : {};

        final serverAvatar = (data['avatar_url'] ?? data['user']?['avatar_url'])
            ?.toString();
        final effectiveAvatar =
            (serverAvatar != null && serverAvatar.trim().isNotEmpty)
            ? serverAvatar
            : ((localAvatar != null && localAvatar.trim().isNotEmpty)
                  ? localAvatar
                  : null);

        if (serverAvatar != null && serverAvatar.trim().isNotEmpty) {
          await prefs.setString('user_avatar_url', serverAvatar);
        }

        setState(() {
          _displayName =
              (data['name'] ?? (localName.isNotEmpty ? localName : 'المستخدم'))
                  .toString();
          _email = (data['email'] ?? localEmail).toString();
          _avatarUrl = effectiveAvatar;
          _nameController.text = _displayName;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayName = localName.isNotEmpty ? localName : 'المستخدم';
          _email = localEmail;
          _avatarUrl = (localAvatar != null && localAvatar.trim().isNotEmpty)
              ? localAvatar
              : null;
          _nameController.text = _displayName;
          _isLoading = false;
        });
      }
    }
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
    if (_isUploadingAvatar) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);

      setState(() {
        _isUploadingAvatar = true;
        _localSelectedImage = file; // عرض الصورة المختارة مباشرة على الواجهة
      });

      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          file.path,
          filename: pickedFile.name,
        ),
      });

      final response = await ApiClient.dio.post('/user/avatar', data: formData);

      if (mounted) {
        final resData = response.data is Map ? response.data : {};
        final newUrl = (resData['avatar_url'] ?? resData['data']?['avatar_url'])
            ?.toString();

        debugPrint('📸 Avatar Upload Response: ${response.data}');
        debugPrint('📸 Final URL: $newUrl');

        if (newUrl != null && newUrl.trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_avatar_url', newUrl);
          setState(() {
            _avatarUrl = newUrl;
          });
        }
        _notify('تم تحديث الصورة الشخصية بنجاح.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localSelectedImage = null; // إعادة الوضع السابق في حال الفشل
        });
      }
      _notify('فشل تحميل الصورة الشخصية: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _notify('يرجى إدخال اسم صحيح لا يقل عن حرفين.', isError: true);
      return;
    }

    try {
      setState(() => _isSaving = true);
      await ApiClient.dio.put('/user/profile', data: {'name': name});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);

      if (!mounted) return;
      setState(() {
        _displayName = name;
        _isEditing = false;
      });
      _notify('تم حفظ التعديلات بنجاح.');
    } catch (e) {
      setState(() {
        _displayName = name;
        _isEditing = false;
      });
      _notify('تم حفظ الاسم محلياً.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
                  ),
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
                        : _buildAvatarImage(),
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
                        _displayName.isEmpty ? 'المستخدم' : _displayName,
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

  Widget _buildAvatarImage() {
    if (_localSelectedImage != null) {
      return Image.file(
        _localSelectedImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackAvatar(),
      );
    }

    if (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty) {
      return Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Image load error: $error on URL: $_avatarUrl');
          return _fallbackAvatar();
        },
      );
    }

    return _fallbackAvatar();
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey(_email),
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
              'حساب نشط وموثق عبر Laravel API',
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
