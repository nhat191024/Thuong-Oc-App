import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:get_storage/get_storage.dart';

class ApiService {
  late Dio _dio;
  final GetStorage _storage = GetStorage();

  static const String baseUrl = 'https://thuong-oc.taiyo.fun/api';

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    // Android 7.1.1 (API 25) and below do not trust modern root CAs
    // (e.g. ISRG Root X1 used by Let's Encrypt), causing CERTIFICATE_VERIFY_FAILED.
    // Allow the connection when the host matches our own server.
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        const trustedHost = 'thuong-oc.taiyo.fun';
        return host == trustedHost;
      };
      return client;
    };

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.read('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
