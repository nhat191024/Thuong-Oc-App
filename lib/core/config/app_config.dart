abstract final class AppConfig {
  static const pusherAppKey = String.fromEnvironment('PUSHER_APP_KEY');
  static const pusherHost = String.fromEnvironment(
    'PUSHER_HOST',
    defaultValue: 'soketi-realtime.taiyo.fun',
  );
  static const pusherCluster = String.fromEnvironment(
    'PUSHER_APP_CLUSTER',
    defaultValue: 'mt1',
  );
  static const pusherWssPort = int.fromEnvironment(
    'PUSHER_PORT',
    defaultValue: 443,
  );

  static void validatePusher() {
    if (pusherAppKey.isEmpty) {
      throw const FormatException(
        'Thiếu PUSHER_APP_KEY. Hãy truyền cấu hình bằng --dart-define '
        'hoặc --dart-define-from-file.',
      );
    }
  }
}
