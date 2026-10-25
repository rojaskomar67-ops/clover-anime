import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Encrypted string store: API addresses and keys never appear as plain text
/// in the app. Each value has its own random nonce, a SHA-256 keystream and a
/// bit-rotation layer. Combined with Dart code obfuscation at build time.
class Vault {
  Vault._();
  static final _cache = <String, String>{};

  static List<int> get _seed => [
        for (var i = 0; i < 32; i++) (i * 73 + 41) % 251,
        ...utf8.encode('cl0v3r::v4ult'),
      ];

  static String open(String sealed) {
    final hit = _cache[sealed];
    if (hit != null) return hit;
    final raw = base64Decode(sealed);
    final nonce = raw.sublist(0, 8);
    final body = raw.sublist(8).map((b) => ((b >> 3) | (b << 5)) & 255).toList().reversed.toList();
    final ks = <int>[];
    var c = 0;
    while (ks.length < body.length) {
      ks.addAll(sha256.convert([..._seed, ...nonce, (c >> 24) & 255, (c >> 16) & 255, (c >> 8) & 255, c & 255]).bytes);
      c++;
    }
    final out = utf8.decode([for (var i = 0; i < body.length; i++) body[i] ^ ks[i]]);
    return _cache[sealed] = out;
  }

  static String get hindiBase => open('uksLZn/aPYg0urVqlJaW8/GlFLHa29mcG8iyJNchHsy4KQ84kXmDFWUTc8SiwEZW');
  static String get hindiKey => open('mK78booTrtibLdkYGqpo');
  static String get hindiSite => open('RftijOu6cNRjD589u0Az/Fxs8b4UgZK3bc8ckA==');
  static String get skipApi => open('pqEuBQFz6dNZTlH7VrG4k3QzaSk+17d0D0R09Sg055fWLVZ12vjtZdT2zX5uvw==');
  static String get jikan => open('0Cx+3ErCgQKqOKlZ3qSfbma4iVl2B/oDh1sTqaozfawv');
}
