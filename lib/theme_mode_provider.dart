import 'dart:async';

import 'package:flutter/material.dart';
import 'package:daily_you/config_provider.dart';
import 'package:system_theme/system_theme.dart';

class ThemeModeProvider with ChangeNotifier {
  // 宣纸风格应用始终以亮色为基底；"跟随系统"仅在系统为亮色时生效，
  // 避免鸿蒙等系统暗色模式下出现"白纸白字"。
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  Color _accentColor = const Color(0xFF5A4D41);
  Color get accentColor => _accentColor;
  bool get usingSystemColor =>
      ConfigProvider.instance.get(ConfigKey.followSystemColor);

  set themeMode(ThemeMode value) {
    _themeMode = value;
    notifyListeners();
  }

  set accentColor(Color color) {
    ConfigProvider.instance.set(ConfigKey.accentColor, color.toARGB32());
    _accentColor = color;
  }

  void updateAccentColor() {
    if (ConfigProvider.instance.get(ConfigKey.followSystemColor)) {
      _accentColor = SystemTheme.accentColor.accent;
    } else {
      _accentColor = Color(ConfigProvider.instance.get(ConfigKey.accentColor));
    }
    notifyListeners();
  }

  Future<void> initializeThemeFromConfig() async {
    await SystemTheme.accentColor.load();
    SystemTheme.fallbackColor = _accentColor;
    if (ConfigProvider.instance.get(ConfigKey.followSystemColor)) {
      _accentColor = SystemTheme.accentColor.accent;
    } else {
      _accentColor = Color(ConfigProvider.instance.get(ConfigKey.accentColor));
    }

    final configTheme = ConfigProvider.instance.get(ConfigKey.theme);
    if (configTheme == 'dark' || configTheme == 'amoled') {
      _themeMode = ThemeMode.dark;
    } else {
      // 'system' 与 'light' 都解析为亮色主题
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }
}
