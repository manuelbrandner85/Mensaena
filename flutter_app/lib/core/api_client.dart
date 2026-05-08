import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'supabase.dart';

/// HTTP-Client für die /api/*-Routen, die weiterhin auf Cloudflare Workers
/// laufen (genauso wie die Web-App sie nutzt). Hängt automatisch das
/// Supabase-JWT als Bearer-Token an, damit RLS und API-Auth funktionieren.
class ApiClient {
  ApiClient() : dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'MensaenaFlutter/${Env.appVersion}',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = sb.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      dio.post<T>(path, data: body, queryParameters: query);

  Future<Response<T>> put<T>(String path, {Object? body}) => dio.put<T>(path, data: body);

  Future<Response<T>> delete<T>(String path) => dio.delete<T>(path);
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
