import 'dart:convert';

class JwtUtils {
  /// Decodes a JWT token and returns the payload as a Map
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      // Decode the payload (second part)
      String normalizedPayload = parts[1];
      // Add padding if needed
      while (normalizedPayload.length % 4 != 0) {
        normalizedPayload += '=';
      }

      final decoded = utf8.decode(base64Url.decode(normalizedPayload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Checks if a JWT token is expired
  /// Returns true if token is expired or invalid, false if valid
  static bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) {
      return true;
    }

    final payload = decodeToken(token);
    if (payload == null) {
      return true;
    }

    // Check if token has expiration claim
    if (!payload.containsKey('exp')) {
      // If no expiration claim, consider it valid (though this is unusual)
      return false;
    }

    // Get expiration timestamp (Unix timestamp)
    final exp = payload['exp'];
    if (exp == null) {
      return true;
    }

    // Convert to DateTime
    final expirationDate = DateTime.fromMillisecondsSinceEpoch(
      exp is int ? exp * 1000 : (exp as num).toInt() * 1000,
    );

    // Check if token is expired (with 60 second buffer to account for clock skew)
    final now = DateTime.now().add(const Duration(seconds: 60));
    return expirationDate.isBefore(now);
  }

  /// Gets the expiration date of a token
  static DateTime? getTokenExpiration(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    final payload = decodeToken(token);
    if (payload == null || !payload.containsKey('exp')) {
      return null;
    }

    final exp = payload['exp'];
    if (exp == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      exp is int ? exp * 1000 : (exp as num).toInt() * 1000,
    );
  }
}

