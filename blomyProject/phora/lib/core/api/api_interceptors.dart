import 'package:phora/core/api/api_error_mapper.dart';
import 'package:dio/dio.dart';

const kSkipUnauthorizedLogoutKey = 'skip_unauthorized_logout';
const kSkipAuthRefreshKey = 'skip_auth_refresh';
const kRetriedAfterAuthRefreshKey = 'retried_after_auth_refresh';

class ApiErrorInterceptor extends Interceptor {
  ApiErrorInterceptor({
    required this.onUnauthorized,
    required this.onPaywalled,
  });

  final Future<Response<dynamic>?> Function(DioException error) onUnauthorized;
  final Future<void> Function(FeatureGateFailure failure) onPaywalled;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final failure = mapDioError(err);
    final skipUnauthorizedLogout =
        err.requestOptions.extra[kSkipUnauthorizedLogoutKey] == true;
    if (failure is UnauthorizedFailure && !skipUnauthorizedLogout) {
      final retryResponse = await onUnauthorized(err);
      if (retryResponse != null) {
        handler.resolve(retryResponse);
        return;
      }
    } else if (failure is FeatureGateFailure) {
      onPaywalled(failure);
    }
    handler.next(err);
  }
}
