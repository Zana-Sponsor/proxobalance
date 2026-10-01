// ═══════════════════════════════════════════════════════════════════════
// FILENAME SANITIZER — turns a card's display name into a safe .html
// filename for local save + Telegram delivery.
//
// Rules:
//  - trim leading/trailing spaces
//  - collapse multiple spaces
//  - replace spaces with "-"
//  - remove unsafe filename characters (only unicode letters, digits,
//    "-" and "_" survive — this also means "." can never survive, which
//    is what makes ".html.html" structurally impossible: there is no dot
//    left in the stem for the appended ".html" to double up against)
//  - prevent path traversal (no "/", "\", "..")
//  - prevent ".html.html"
//  - fallback to "profile.html"
//
// Examples:
//   "Zana Ali"           -> "Zana-Ali.html"
//   "Alan Ahmed Hassan"  -> "Alan-Ahmed-Hassan.html"
//
// Unicode letters (so Kurdish/Arabic names — the app's primary audience —
// are preserved instead of being stripped down to "profile.html") are
// kept via \p{L}; only ASCII "-"/"_" are additionally allowed.
// ═══════════════════════════════════════════════════════════════════════

final RegExp _unsafeChars = RegExp(r'[^\p{L}\p{N}_-]', unicode: true);
final RegExp _multiSpace = RegExp(r'\s+');
final RegExp _multiDash = RegExp(r'-{2,}');
final RegExp _trimDashes = RegExp(r'^-+|-+$');

const int _maxStemLength = 100;

/// Turns a user-entered display name into a safe "Name.html" filename.
/// Never throws and never returns an empty string — falls back to
/// "profile.html" when the name sanitizes down to nothing (e.g. a name
/// that was only emoji or punctuation).
String sanitizeFilenameFromName(String rawName) {
  var s = rawName.trim();
  if (s.isEmpty) return 'profile.html';

  // Collapse internal whitespace runs, then turn spaces into hyphens.
  s = s.replaceAll(_multiSpace, ' ').trim();
  s = s.replaceAll(' ', '-');

  // Explicit path-traversal guard. Redundant with the allowlist strip
  // below (which also removes "/", "\" and "."), but kept explicit so
  // the intent is obvious and this still holds even if the allowlist
  // above it is ever loosened later.
  s = s.replaceAll('..', '').replaceAll('/', '').replaceAll('\\', '');

  // Drop anything that isn't a unicode letter, digit, hyphen or
  // underscore. This also removes every "." — so a name typed as
  // "Zana.html" can never turn into "Zana.html.html" below, since no
  // dot survives to collide with the extension we append.
  s = s.replaceAll(_unsafeChars, '');

  // Collapse hyphen runs created by the removals above, then trim
  // leading/trailing hyphens so the name can't start/end with "-".
  s = s.replaceAll(_multiDash, '-').replaceAll(_trimDashes, '');

  if (s.isEmpty) return 'profile.html';

  if (s.length > _maxStemLength) s = s.substring(0, _maxStemLength);
  s = s.replaceAll(_trimDashes, ''); // truncation could leave a trailing "-"
  if (s.isEmpty) return 'profile.html';

  return '$s.html';
}
