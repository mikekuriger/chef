// services/dio_client.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chef/constants.dart';

class DioClient {
  static late final Dio dio;
  static PersistCookieJar? _cookieJar;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final appDocDir = await getApplicationDocumentsDirectory();

    _cookieJar = PersistCookieJar(
      storage: FileStorage('${appDocDir.path}/.cookies/'),
      ignoreExpires: false, // keep Flask-Login "remember" cookie until it expires
    );

    dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));

    dio.interceptors.add(CookieManager(_cookieJar!));
  }

  // Added so logout can actually clear the session
  static Future<void> clearCookies() async {
    await _cookieJar?.deleteAll();
  }

  // (optional) if you ever set an auth header, clear it too
  static void removeAuthHeader() {
    dio.options.headers.remove('Authorization');
  }

  static Dio get instance {
    if (!_initialized) {
      throw StateError('DioClient.init() must be called before use.');
    }
    return dio;
  }
}
