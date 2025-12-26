import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  Future<void> showLowStockNotification(String materialName, double currentStock, double minStock) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'low_stock_channel',
      'Nízky stav zásob',
      channelDescription: 'Upozornenia na nízky stav zásob',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Nízky stav zásob',
      '$materialName: ${currentStock.toStringAsFixed(1)} (min: ${minStock.toStringAsFixed(1)})',
      details,
    );
  }

  Future<void> showAutoOrderNotification(String materialName, double suggestedQuantity) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'auto_order_channel',
      'Automatické objednávky',
      channelDescription: 'Upozornenia na navrhované objednávky',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Navrhovaná objednávka',
      '$materialName: ${suggestedQuantity.toStringAsFixed(1)}',
      details,
    );
  }

  Future<void> scheduleDailyStockCheck(DateTime time) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'daily_check_channel',
      'Denná kontrola',
      channelDescription: 'Pravidelné kontroly stavu zásob',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      0,
      'Denná kontrola zásob',
      'Skontrolujte stav zásob a nízke stavy',
      tz.TZDateTime.from(time, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}







