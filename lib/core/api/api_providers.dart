import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/config_providers.dart';
import 'api_client.dart';

/// Single configured [Dio] instance used by every repository in the app.
///
/// Throws [StateError] when [AppConfig] is missing — the router must surface
/// `MissingConfigScreen` and avoid resolving this provider.
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  return ApiClientFactory.create(config);
});
