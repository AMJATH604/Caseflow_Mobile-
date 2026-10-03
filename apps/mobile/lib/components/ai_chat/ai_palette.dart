import 'package:flutter/material.dart';

/// The AI assistant's colours, in one place.
///
/// Neutral ink on white (and its dark twin), the way ChatGPT and Claude set
/// a conversation: the answer is the content, so the chrome around it stays
/// quiet. Colour is kept for meaning — a failed state, a cited source — not
/// for decoration.
class AiPalette {
  final bool isDark;
  const AiPalette(this.isDark);

  /// Page background.
  Color get bg => isDark ? const Color(0xFF141414) : Colors.white;

  /// Raised surfaces: your message, the composer, cards.
  Color get surface => isDark ? const Color(0xFF262626) : const Color(0xFFF4F4F5);

  /// A step above [surface]: pressed rows, the active chat in history.
  Color get surfaceHigh =>
      isDark ? const Color(0xFF303030) : const Color(0xFFE9E9EC);

  Color get border => isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE4E4E7);

  /// Body text.
  Color get ink => isDark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);

  /// Secondary text and icons.
  Color get muted => isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

  /// Hints and the least important text.
  Color get faint => isDark ? const Color(0xFF6B6B73) : const Color(0xFFA1A1AA);

  /// The send button: ink on white, white on ink.
  Color get action => isDark ? Colors.white : const Color(0xFF18181B);
  Color get onAction => isDark ? const Color(0xFF18181B) : Colors.white;

  /// Citations: the one accent on the page.
  Color get cite => isDark ? const Color(0xFF8AB4FF) : const Color(0xFF2563EB);
}
