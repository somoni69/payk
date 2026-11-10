import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase_options.dart';

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
  debugPrint('[PushNotificationService] Background message: ${message.messageId}');
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
      debugPrint('[PushNotificationService] Firebase init note: $e');
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
      debugPrint('[PushNotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[PushNotificationService] Setup skipped or failed: $e');
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

    debugPrint(
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
      debugPrint('[PushNotificationService] Foreground message: ${message.data}');
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
    debugPrint('[PushNotificationService] Notification opened: ${message.data}');
    final route = message.data['route'] as String? ?? '/notifications';
    _onNotificationTap?.call(route);
  }

  /// Получение FCM-токена устройства и подписка на broadcast-топики
  Future<void> _setupTokenAndTopics(
    Future<void> Function(String token)? onTokenUpdate,
  ) async {
    // Слушаем регистрацию токена (firebase_messaging 17+)
    _fcm.onRegistered.listen((token) {
      _fcmToken = token;
      debugPrint('[PushNotificationService] FCM Token registered: $token');
      onTokenUpdate?.call(token);
    });

    try {
      await _fcm.register();
    } catch (e) {
      debugPrint('[PushNotificationService] Error registering FCM: $e');
    }

    // Подписываемся на общий топик "all" для массовых рассылок без явной базы токенов
    try {
      await _fcm.subscribeToTopic('all');
      debugPrint('[PushNotificationService] Subscribed to topic "all"');
    } catch (e) {
      debugPrint('[PushNotificationService] Subscribe to topic error: $e');
    }
  }

  /// Ручная подписка на топик
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to subscribe to $topic: $e');
    }
  }

  /// Отписка от топика
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to unsubscribe from $topic: $e');
    }
  }
}

/// Провайдер для сервиса пуш-уведомлений
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService.instance;
});
