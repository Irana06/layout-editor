/// Share links come in two shapes and both mean the same thing.
///
/// `https://<host>/l/<code>` is what gets pasted into a chat and what Android
/// App Links verifies. `shiclash://layout/<code>` is the fallback that works the
/// moment the app is installed, without waiting on domain verification — which
/// also makes deep links testable before a domain is settled.
String? shareCodeFromUri(Uri uri) {
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();

  final code = switch (uri.scheme) {
    'shiclash' when uri.host == 'layout' && segments.isNotEmpty =>
      segments.first,
    'http' ||
    'https' when segments.length >= 2 && segments.first == 'l' => segments[1],
    _ => null,
  };

  return code != null && _looksLikeCode(code) ? code : null;
}

/// Codes are six characters from an alphabet with no 0/O or 1/l. Checking the
/// shape here keeps a stray link from becoming a pointless network round trip.
bool _looksLikeCode(String value) =>
    RegExp(r'^[23456789abcdefghjkmnpqrstuvwxyz]{6}$').hasMatch(value);
