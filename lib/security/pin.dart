import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PIN helpers. The PIN itself is never stored, only a salted hash that is
/// run through SHA-256 many times so it can't be guessed quickly from the file.
class PinCrypto {
  static const iterations = 20000;
  static final _rng = Random.secure();

  static String newSalt() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hash(String secret, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$secret')).bytes;
    for (var i = 0; i < iterations; i++) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return base64Url.encode(digest);
  }

  /// Compares without stopping at the first different character.
  static bool sameHash(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// 8-digit recovery code, shown once, written in the shop's notebook.
  static String newRecoveryCode() =>
      List.generate(8, (_) => _rng.nextInt(10)).join();

  static bool isValidPin(String pin) => RegExp(r'^[0-9]{4}$').hasMatch(pin);
}
