import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
  }
}