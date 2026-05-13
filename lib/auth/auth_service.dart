import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // Keys
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const fullNameKey = 'full_name';
  static const roleKey = 'role';
  static const idkey = 'id';
  static const baseUrlKey = 'base_url';

  // Parking slip heading keys
  static const heading1Key = 'parking_slip_heading1';
  static const heading2Key = 'parking_slip_heading2';
  static const heading3Key = 'parking_slip_heading3';
  static const heading4Key = 'parking_slip_heading4';
  static const footerTextKey = 'parking_slip_footer_text';

  static Future<void> saveBaseUrl(String baseUrl) async {
    await _storage.write(key: baseUrlKey, value: baseUrl);
  }

  /// Get base URL
  static Future<String?> getBaseUrl() async {
    return await _storage.read(key: baseUrlKey);
  }

  /// Save login response
  static Future<void> saveLoginData({
    required String accessToken,
    required String refreshToken,
    required String fullName,
    required String role,
    required String id,
  }) async {
    await _storage.write(key: idkey, value: id);
    await _storage.write(key: accessTokenKey, value: accessToken);
    await _storage.write(key: refreshTokenKey, value: refreshToken);
    await _storage.write(key: fullNameKey, value: fullName);
    await _storage.write(key: roleKey, value: role);
  }

  /// Save parking slip details
  static Future<void> saveParkingSlipDetails({
    required String heading1,
    required String heading2,
    required String heading3,
    required String heading4,
    required String footerText,
  }) async {
    await _storage.write(key: heading1Key, value: heading1);
    await _storage.write(key: heading2Key, value: heading2);
    await _storage.write(key: heading3Key, value: heading3);
    await _storage.write(key: heading4Key, value: heading4);
    await _storage.write(key: footerTextKey, value: footerText);
  }

  // Add this method to SecureStorage class
  static Future<void> saveParkingRates(List<dynamic> parkingRates) async {
    final storage = FlutterSecureStorage();
    await storage.write(key: 'parking_rates', value: jsonEncode(parkingRates));
  }

  static Future<List<dynamic>> getParkingRates() async {
    final storage = FlutterSecureStorage();
    final rates = await storage.read(key: 'parking_rates');
    if (rates != null) {
      return jsonDecode(rates);
    }
    return [];
  }

  /// Get parking slip details
  static Future<Map<String, String>> getParkingSlipDetails() async {
    final heading1 = await _storage.read(key: heading1Key);
    final heading2 = await _storage.read(key: heading2Key);
    final heading3 = await _storage.read(key: heading3Key);
    final heading4 = await _storage.read(key: heading4Key);
    final footerText = await _storage.read(key: footerTextKey);
    final fullName = await _storage.read(key: fullNameKey);
    final id = await _storage.read(key: idkey);

    return {
      'heading1': heading1 ?? '',
      'heading2': heading2 ?? '',
      'heading3': heading3 ?? '',
      'heading4': heading4 ?? '',
      'footerText': footerText ?? '',
      'full_name': fullName ?? '',
      'id': id ?? '',
    };
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: refreshTokenKey);
  }

  static Future<void> clear() async {
    await _storage.deleteAll();
  }
}
