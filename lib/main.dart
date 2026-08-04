import 'dart:io';
import 'dart:math';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:daily_you/config_provider.dart';
import 'package:daily_you/custom_locale_delegates.dart';
import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/device_info_service.dart';
import 'package:daily_you/notification_manager.dart';
import 'package:daily_you/pages/launch_page.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:daily_you/time_manager.dart';
import 'package:daily_you/utils/logging.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:daily_you/layouts/mobile_scaffold.dart';
import 'package:daily_you/layouts/responsive_layout.dart';
import 'package:daily_you/theme_mode_provider.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_range_picker/time_range_picker.dart';
import 'package:provider/provider.dart';

@pragma('vm:entry-point')
void onThisDayCallbackDispatcher() async {
  await ConfigProvider.instance.init();
  // Skip syncing and migration for the alarm background task
  final ready = await AppDatabase.instance
      .init(forceWithoutSync: true, allowMigration: false);

  if (ready) {
    final now = DateTime.now();
    final isJalali = TimeManager.isJalaliCalendarFromPlatform();
    final hasOnThisDayEntries = EntriesProvider.instance.entries.any((e) =>
        TimeManager.isSameCalendarDayOfYear(e.timeCreate, now, isJalali) &&
        TimeManager.calendarYearOf(e.timeCreate, isJalali) !=
            TimeManager.calendarYearOf(now, isJalali));

    if (hasOnThisDayEntries) {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.initialize(
          settings: const InitializationSettings(
              android:
                  AndroidInitializationSettings('@drawable/ic_notification'),
              linux: LinuxInitializationSettings(
                  defaultActionName: 'On This Day')));

      // Localized notification text is stored in SharedPreferences upon startup
      var prefs = await SharedPreferences.getInstance();
      var title = prefs.getString('onThisDayNotificationTitle');
      var description = prefs.getString('onThisDayNotificationDescription');

      var androidDetails = AndroidNotificationDetails(
        'daily_you_on_this_day',
        title ?? 'On This Day',
        icon: '@drawable/ic_notification',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      if (title != null && description != null) {
        await flutterLocalNotificationsPlugin.show(
            id: 1,
            title: title,
            body: description,
            notificationDetails: NotificationDetails(android: androidDetails),
            payload: DateTime.now().toIso8601String());
      }
    }

    AppDatabase.instance.close();
  }

  setOnThisDayAlarm(firstSet: false);
}

@pragma('vm:entry-point')
void callbackDispatcher() async {
  await ConfigProvider.instance.init();
  // Skip syncing and migration for the alarm background task
  final ready = await AppDatabase.instance
      .init(forceWithoutSync: true, allowMigration: false);

  if (ready) {
    if (EntriesProvider.instance.getEntryForDate(DateTime.now()) == null ||
        ConfigProvider.instance.get(ConfigKey.alwaysRemind)) {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin.initialize(
          settings: const InitializationSettings(
              android:
                  AndroidInitializationSettings('@drawable/ic_notification'),
              linux:
                  LinuxInitializationSettings(defaultActionName: 'Log Today')));

      // Localized notification text is stored in SharedPreferences upon startup
      var prefs = await SharedPreferences.getInstance();
      var title = prefs.getString('dailyReminderTitle');
      var description = prefs.getString('dailyReminderDescription');

      var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'daily_you_reminder',
        title ?? "Log Today!",
        icon: '@drawable/ic_notification',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      if (title != null && description != null) {
        await flutterLocalNotificationsPlugin.show(
            id: 0,
            title: title,
            body: description,
            notificationDetails: platformChannelSpecifics,
            payload: DateTime.now().toIso8601String());
      }
    }
    AppDatabase.instance.close();
  }

  setAlarm(firstSet: false);
}

void main() async {
  if (Platform.isLinux || Platform.isWindows) {
    // Initialize FFI
    sqfliteFfiInit();
  }
  databaseFactory = databaseFactoryFfi;
  WidgetsFlutterBinding.ensureInitialized();

  configureLogging();

  // Fast, essential startup: the config is needed by the first frame.
  await ConfigProvider.instance.init();

  final themeProvider = ThemeModeProvider();

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider<ThemeModeProvider>(
      create: (_) => themeProvider,
    ),
    ChangeNotifierProvider<EntriesProvider>(
      create: (_) => EntriesProvider.instance,
    ),
    ChangeNotifierProvider<EntryImagesProvider>(
      create: (_) => EntryImagesProvider.instance,
    ),
    ChangeNotifierProvider<ConfigProvider>(
      create: (_) => ConfigProvider.instance,
    )
  ], builder: (context, child) => const MainApp()));

  // Everything below is not required for the first frame, so it runs after
  // the app is visible instead of blocking startup on platform channels.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeInBackground(themeProvider);
  });
}

Future<void> _initializeInBackground(ThemeModeProvider themeProvider) async {
  try {
    await themeProvider.initializeThemeFromConfig();
    await DeviceInfoService().init();

    // Notification only supported on android
    if (Platform.isAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
      await NotificationManager.instance.init();
      await AndroidAlarmManager.initialize();
    }
  } catch (error, stackTrace) {
    // Initialization failures must never block the app from running.
    // ignore: avoid_print
    debugPrint('Background initialization failed: $error\n$stackTrace');
  }
}

Future<void> setAlarm({bool firstSet = false}) async {
  DateTime referenceTime = TimeManager.startOfDay(DateTime.now());
  Duration currentTime = DateTime.now().difference(referenceTime);

  Duration reminderTime;
  if (ConfigProvider.instance.get(ConfigKey.setReminderTime)) {
    reminderTime = TimeManager.addTimeOfDay(
            referenceTime, TimeManager.scheduledReminderTime())
        .difference(referenceTime);
    if (!firstSet || reminderTime <= currentTime) {
      reminderTime += Duration(days: 1);
    }
  } else {
    final random = Random();
    TimeRange timeRange = TimeManager.getReminderTimeRange();

    Duration startTime =
        TimeManager.addTimeOfDay(referenceTime, timeRange.startTime)
            .difference(referenceTime);
    Duration endTime =
        TimeManager.addTimeOfDay(referenceTime, timeRange.endTime)
            .difference(referenceTime);

    if (endTime < startTime) {
      // Extend end time to next day
      endTime += Duration(days: 1);
    }

    // Make alarm today if possible
    if (firstSet && (startTime < currentTime) && (endTime > currentTime)) {
      startTime = currentTime;
    }

    int randomTimeInMinutes =
        random.nextInt(endTime.inMinutes - startTime.inMinutes + 1);
    reminderTime = startTime + Duration(minutes: randomTimeInMinutes);

    if (!firstSet || (reminderTime <= currentTime)) {
      reminderTime += Duration(days: 1);
    }
  }

  DateTime reminderDateTime = DateTime.now().add(reminderTime - currentTime);

  await AndroidAlarmManager.oneShotAt(reminderDateTime, 0, callbackDispatcher,
      allowWhileIdle: true, exact: true, rescheduleOnReboot: true);
}

Future<void> setOnThisDayAlarm({bool firstSet = false}) async {
  DateTime referenceTime = TimeManager.startOfDay(DateTime.now());
  Duration currentTime = DateTime.now().difference(referenceTime);

  int hour = ConfigProvider.instance.get(ConfigKey.onThisDayNotificationHour);
  int minute =
      ConfigProvider.instance.get(ConfigKey.onThisDayNotificationMinute);
  Duration reminderTime = TimeManager.addTimeOfDay(
          referenceTime, TimeOfDay(hour: hour, minute: minute))
      .difference(referenceTime);

  if (!firstSet || reminderTime <= currentTime) {
    reminderTime += const Duration(days: 1);
  }

  DateTime reminderDateTime = DateTime.now().add(reminderTime - currentTime);
  await AndroidAlarmManager.oneShotAt(
      reminderDateTime, 1, onThisDayCallbackDispatcher,
      allowWhileIdle: true, exact: true, rescheduleOnReboot: true);
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeModeProvider = Provider.of<ThemeModeProvider>(context);
    final configProvider = Provider.of<ConfigProvider>(context);
    // 涓枃瀛椾綋锛氫豢瀹嬶紙榛樿锛夋垨妤蜂功锛屽彲鍦?澶栬 璁剧疆涓垏鎹?
    final cjkFont = configProvider.get(ConfigKey.cjkFont) == 'kaishu'
        ? 'XuandongKaishu'
        : 'SotyrFangsong';
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      ThemeData lightTheme;
      ThemeData darkTheme;

      if (themeModeProvider.usingSystemColor && lightDynamic != null) {
        bool noChroma = (lightDynamic.primary.r == lightDynamic.primary.b) &&
            (lightDynamic.primary.b == lightDynamic.primary.g);
        lightTheme = ThemeData(
            useMaterial3: true,
            fontFamily: 'Courgette',
            fontFamilyFallback: [cjkFont],
            scaffoldBackgroundColor: const Color(0xFFF7F4ED),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                // Predictive back gesture on Android 14+; FadeForwards is
                // the modern default transition everywhere else.
                TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              },
            ),
            colorScheme: ColorScheme.fromSeed(
                seedColor: lightDynamic.primary,
                primaryContainer: lightDynamic.primaryContainer,
                dynamicSchemeVariant: noChroma
                    ? DynamicSchemeVariant.fidelity
                    : DynamicSchemeVariant.tonalSpot,
                brightness: Brightness.light,
                surface: const Color(0xFFF7F4ED),
                onSurface: const Color(0xFF2C2A29)));
      } else {
        lightTheme = ThemeData(
            useMaterial3: true,
            fontFamily: 'Courgette',
            fontFamilyFallback: [cjkFont],
            scaffoldBackgroundColor: const Color(0xFFF7F4ED),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                // Predictive back gesture on Android 14+; FadeForwards is
                // the modern default transition everywhere else.
                TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              },
            ),
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF5A4D41),
                brightness: Brightness.light,
                surface: const Color(0xFFF7F4ED),
                onSurface: const Color(0xFF2C2A29)));
      }

      if (themeModeProvider.usingSystemColor && darkDynamic != null) {
        bool noChroma = (darkDynamic.primary.r == darkDynamic.primary.b) &&
            (darkDynamic.primary.b == darkDynamic.primary.g);
        darkTheme = ThemeData(
            useMaterial3: true,
            fontFamily: 'Courgette',
            fontFamilyFallback: [cjkFont],
            scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                // Predictive back gesture on Android 14+; FadeForwards is
                // the modern default transition everywhere else.
                TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              },
            ),
            colorScheme: ColorScheme.fromSeed(
                seedColor: darkDynamic.primary,
                primaryContainer: darkDynamic.primaryContainer,
                dynamicSchemeVariant: noChroma
                    ? DynamicSchemeVariant.fidelity
                    : DynamicSchemeVariant.tonalSpot,
                brightness: Brightness.dark,
                surface: const Color(0xFF1E1E1E),
                onSurface: const Color(0xFFD4D4D4)));
      } else {
        darkTheme = ThemeData(
          useMaterial3: true,
          fontFamily: 'Courgette',
          fontFamilyFallback: [cjkFont],
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
              TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
            },
          ),
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5A4D41),
              brightness: Brightness.dark,
              surface: const Color(0xFF1E1E1E),
              onSurface: const Color(0xFFD4D4D4)),
        );
      }

      // amoled override
      if (ConfigProvider.instance.get(ConfigKey.theme) == 'amoled') {
        darkTheme = ThemeData(
            useMaterial3: true,
            fontFamily: 'Courgette',
            fontFamilyFallback: [cjkFont],
            materialTapTargetSize: MaterialTapTargetSize.padded,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                // Predictive back gesture on Android 14+; FadeForwards is
                // the modern default transition everywhere else.
                TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              },
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeModeProvider.accentColor,
              brightness: Brightness.dark,
              surfaceContainerLowest: Colors.black,
              surfaceContainerLow: Colors.black,
              surfaceContainerHighest: Colors.black,
              surfaceContainerHigh: Colors.black,
              surfaceBright: Colors.black,
              surfaceDim: Colors.black,
              surface: Colors.black,
              surfaceContainer: Colors.black,
              onSurface: Colors.white,
              surfaceTint: Colors.black,
              primaryContainer: Colors.black,
              secondaryContainer: Colors.black,
              tertiaryContainer: Colors.black,
              inverseSurface: Colors.black,
              inversePrimary: Colors.black,
              scrim: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.black);
      }

      return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: MaterialApp(
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context)!.appTitle,
                title: 'Daily You',
                themeMode: themeModeProvider.themeMode,
                debugShowCheckedModeBanner: false,
                localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                  AppLocalizations.delegate,
                  CustomMaterialLocalizationsDelegate(),
                  CustomCupertinoLocalizationsDelegate(),
                  CustomWidgetsLocalizationsDelegate(),
                ],
                locale: configProvider.getOverrideLanguage(),
                supportedLocales: [
                  Locale("en"),
                  ...AppLocalizations.supportedLocales
                      .where((locale) => locale.languageCode != "en")
                ],
                localeResolutionCallback: (locale, supportedLocales) {
                  final override = configProvider.getOverrideLanguage();
                  if (override != null) return override;

                  if (locale != null) {
                    for (final supported in supportedLocales) {
                      if (supported.languageCode == locale.languageCode) {
                        return supported;
                      }
                    }
                  }

                  return const Locale('en');
                },
                theme: lightTheme,
                darkTheme: darkTheme,
                home: LaunchPage(
                    nextPage: ResponsiveLayout(
                  mobileScaffold: MobileScaffold(),
                  tabletScaffold: MobileScaffold(),
                  desktopScaffold: MobileScaffold(),
                ))));
    });
  }
}
