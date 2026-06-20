import 'package:flutter/material.dart';

/// Premium reusable avatar widget that displays a profile photo or
/// falls back to a gradient initial circle.
///
/// Used across: Dashboard header, Advocate Directory, Discussions,
/// Firm Management, App Shell, and anywhere user identity is shown.
class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final double radius;
  final List<Color>? gradientColors;
  final bool showBorder;
  final double borderWidth;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.radius = 24,
    this.gradientColors,
    this.showBorder = true,
    this.borderWidth = 2.5,
    this.onTap,
  });

  /// Default gradient palette — consistent across the app
  static const _defaultGradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFF2563EB), Color(0xFF3B82F6)],
    [Color(0xFF0D9488), Color(0xFF14B8A6)],
    [Color(0xFFD97706), Color(0xFFF59E0B)],
    [Color(0xFFDC2626), Color(0xFFEF4444)],
    [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
  ];

  List<Color> get _colors {
    if (gradientColors != null) return gradientColors!;
    final hash = (name ?? 'A').codeUnits.fold(0, (prev, c) => prev + c);
    return _defaultGradients[hash % _defaultGradients.length];
  }

  String get _initial {
    final n = name?.trim() ?? '';
    if (n.isEmpty) return '?';
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _colors;

    final effectiveBorder = showBorder ? borderWidth : 0.0;

    final avatar = Container(
      width: (radius + effectiveBorder) * 2,
      height: (radius + effectiveBorder) * 2,
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )
          : null,
      padding: showBorder ? EdgeInsets.all(borderWidth) : null,
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? _buildPhotoAvatar(isDark, colors)
          : _buildInitialAvatar(isDark, colors),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildPhotoAvatar(bool isDark, List<Color> colors) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      backgroundImage: NetworkImage(avatarUrl!),
      onBackgroundImageError: (_, __) {},
      child: ClipOval(
        child: Image.network(
          avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              _buildInitialContent(colors),
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(bool isDark, List<Color> colors) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: _buildInitialContent(colors),
    );
  }

  Widget _buildInitialContent(List<Color> colors) {
    return Text(
      _initial,
      style: TextStyle(
        color: colors[0],
        fontWeight: FontWeight.w800,
        fontSize: radius * 0.75,
      ),
    );
  }
}
