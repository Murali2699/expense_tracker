import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (raw.isEmpty) {
      throw StateError('API_BASE_URL is missing in .env');
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      throw StateError('API_BASE_URL in .env is invalid');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('API_BASE_URL must use HTTPS in release builds');
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
}
