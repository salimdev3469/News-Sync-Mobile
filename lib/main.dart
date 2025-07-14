import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:news_sync_mobile/auth_wrapper.dart';
import 'package:news_sync_mobile/pages/splash_screen.dart';
import 'package:news_sync_mobile/pages/home_page.dart';
import 'package:news_sync_mobile/pages/news_detail_page.dart';
import 'package:news_sync_mobile/pages/login_page.dart';
import 'package:news_sync_mobile/pages/registration_page.dart';
import 'package:news_sync_mobile/pages/saved_news_page.dart';
import 'package:news_sync_mobile/pages/location_page.dart';
import 'package:news_sync_mobile/controllers/theme_controller.dart';
import 'package:intl/date_symbol_data_local.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> initializeNotificationPlugin() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
  InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp();

    tz.initializeTimeZones();

    if (task == "fetchSonDakikaNews") {
      await sendLatestSonDakikaNotification();
    }

    return Future.value(true);
  });
}

Future<void> sendLatestSonDakikaNotification() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('Articles')
      .where('category', isEqualTo: 'Son Dakika')
      .orderBy('created_at_server', descending: true)
      .limit(5)
      .get();

  if (snapshot.docs.isEmpty) {
    print("Son Dakika haberi bulunamadı.");
    return;
  }

  final doc = snapshot.docs.first;
  final haber = doc.data();

  final title = haber['title'] ?? 'Son Dakika';
  final content = haber['content'] ?? 'Detayları görmek için uygulamayı aç.';

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    title,
    content,
    tz.TZDateTime.now(tz.local).add(Duration(seconds: 5)),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'channel_id',
        'channel_name',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );

  print("Bildirim gönderildi: $title");
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
  InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}




void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr_TR', null);
  await initializeNotifications();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  // Sistem çubuğu renklerini ayarla
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully.");

    // Firestore offline cache aktif et
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    print("✅ Firestore offline cache enabled.");
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  try {
    await initializeDateFormatting('tr_TR', null);
    print("✅ Date formatting initialized for tr_TR.");
  } catch (e) {
    print("❌ Error initializing date formatting for tr_TR: $e");
  }

  /// Workmanager başlat
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  /// 2 saatte bir çalışacak şekilde background task kur
  Workmanager().registerPeriodicTask(
    "sonDakikaTask",
    "fetchSonDakikaNews",
    frequency: const Duration(hours: 2),
    initialDelay: const Duration(minutes: 1), // ilk başta biraz beklesin
  );

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setSystemUIOverlayStyle(themeNotifier.value);
    themeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    _setSystemUIOverlayStyle(themeNotifier.value);
  }

  void _setSystemUIOverlayStyle(ThemeMode mode) {
    if (mode == ThemeMode.dark) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ));
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ));
    }
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'News Sync',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/auth_wrapper': (context) => const AuthWrapper(),
            '/home': (context) => const HomePage(),
            '/news_detail': (context) => NewsDetailPage(),
            '/login': (context) => LoginPage(),
            '/register': (context) => RegistrationPage(),
            '/saved_news': (context) => SavedNewsPage(),
            '/location': (context) => LocationPage(),
          },
        );
      },
    );
  }
}
