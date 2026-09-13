/// The single definition of what counts as an acceptable password.
///
/// Sign-up and password-reset used to enforce different rules — sign-up wanted
/// 8 characters with an uppercase letter and a digit, while the reset sheet
/// accepted any 6 characters. That made "forgot password" a way around the
/// policy: register with a strong password, then immediately reset it to
/// something trivial. Both call this now, so they cannot diverge again.
///
/// This is a usability guard, not a security boundary. Anyone can call the
/// Supabase Auth API directly and skip it entirely, so the authoritative
/// minimum must also be configured in Supabase
/// (Authentication → Policies → minimum password length / required
/// characters), together with leaked-password protection, which checks
/// candidates against HaveIBeenPwned.
library;

/// Minimum length accepted by the client forms.
const int kMinPasswordLength = 8;

/// Returns a human-readable reason the password is unacceptable, or `null` if
/// it passes.
String? validatePasswordPolicy(String? password) {
  if (password == null || password.isEmpty) return 'Enter a password';
  if (password.length < kMinPasswordLength) {
    return 'Minimum $kMinPasswordLength characters required';
  }
  if (!password.contains(RegExp(r'[A-Z]'))) {
    return 'Must contain at least 1 uppercase letter';
  }
  if (!password.contains(RegExp(r'[0-9]'))) {
    return 'Must contain at least 1 digit';
  }
  return null;
}
