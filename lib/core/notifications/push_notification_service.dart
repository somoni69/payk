import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase_options.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Фоновый обработчик сообщений (должен быть функцией верхнего уровня)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  _log('[PushNotificationService] Background message: ${message.messageId}');
}

/// Сервис управления пуш-уведомлениями (FCM + Local Notifications)
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'payk_notifications',
    'Payk Уведомления',
    description: 'Уведомления о бонусах, транзакциях и новостях программы лояльности',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool _isInitialized = false;
  String? _fcmToken;
  void Function(String route)? _onNotificationTap;

  String? get fcmToken => _fcmToken;

  /// Инициализация Firebase и push-уведомлений
  Future<void> initialize({
    void Function(String route)? onNotificationTap,
    Future<void> Function(String token)? onTokenUpdate,
  }) async {
    if (_isInitialized) return;
    _onNotificationTap = onNotificationTap;

    // 1. Проверяем доступность Firebase в текущем окружении (в тестах или без плагина пропускаем безопасно)
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      _log('[PushNotificationService] Firebase init note: $e');
      return;
    }

    try {
      // 2. Фоновый обработчик сообщений
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Запрос разрешений у пользователя
      await _requestPermissions();

      // 4. Настройка локальных уведомлений для показа поверх приложения (Foreground)
      await _setupLocalNotifications();

      // 5. Обработка уведомлений в Foreground (когда приложение открыто)
      _listenForegroundMessages();

      // 6. Обработка клика по уведомлению (фоновое или закрытое приложение)
      _setupInteractedMessage();

      // 7. Получение FCM-токена и подписка на топик
      await _setupTokenAndTopics(onTokenUpdate);

      _isInitialized = true;
      _log('[PushNotificationService] Initialized successfully');
    } catch (e) {
      _log('[PushNotificationService] Setup skipped or failed: $e');
    }
  }

  /// Запрос разрешений
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _log(
      '[PushNotificationService] Authorization status: ${settings.authorizationStatus}',
    );

    // Для iOS включаем показ баннеров при открытом приложении
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Инициализация канала и плагина локальных уведомлений
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _onNotificationTap?.call(payload);
        }
      },
    );

    // Создаем канал уведомлений на Android
    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(_defaultChannel);
  }

  /// Прослушивание входящих сообщений при открытом приложении
  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log('[PushNotificationService] Foreground message: ${message.data}');
      final notification = message.notification;
      final route = message.data['route'] as String? ?? '/notifications';

      if (notification != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title ?? 'Payk',
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _defaultChannel.id,
              _defaultChannel.name,
              channelDescription: _defaultChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: route,
        );
      }
    });
  }

  /// Обработка клика по пушу (из трея / фонового состояния)
  void _setupInteractedMessage() {
    // 1. Приложение было закрыто и открыто по клику на уведомление
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessageClick(message);
      }
    });

    // 2. Приложение было в фоне и открыто по клику на уведомление
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageClick(message);
    });
  }

  void _handleMessageClick(RemoteMessage message) {
    _log('[PushNotificationService] Notification opened: ${message.data}');
    final route = message.data['route'] as String? ?? '/notifications';
    _onNotificationTap?.call(route);
  }

  /// Получение FCM-токена устройства и подписка на broadcast-топики.
  /// getToken — регистрационный токен для отправки. onRegistered в Messaging 17
  /// отдаёт идентификатор установки, им пуш не послать.
  Future<void> _setupTokenAndTopics(
    Future<void> Function(String token)? onTokenUpdate,
  ) async {
    Future<void> publish(String? token) async {
      if (token == null || token.isEmpty) return;
      _fcmToken = token;
      _log('[PushNotificationService] FCM token ready (${token.length})');
      await onTokenUpdate?.call(token);
    }

    // onRegistered отдаёт идентификатор установки, а не токен отправки.
    // ignore: deprecated_member_use
    _fcm.onTokenRefresh.listen((token) {
      publish(token);
    });

    try {
      // ignore: deprecated_member_use
      await publish(await _fcm.getToken());
    } catch (e) {
      _log('[PushNotificationService] Error reading FCM token: $e');
    }

    try {
      await _fcm.subscribeToTopic('all');
      _log('[PushNotificationService] Subscribed to topic "all"');
    } catch (e) {
      _log('[PushNotificationService] Subscribe to topic error: $e');
    }
  }

  /// Ручная подписка на топик
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      _log('[PushNotificationService] Failed to subscribe to $topic: $e');
    }
  }

  /// Отписка от топика
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
      _log('[PushNotificationService] Failed to unsubscribe from $topic: $e');
    }
  }
}

/// Провайдер для сервиса пуш-уведомлений
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService.instance;
});
