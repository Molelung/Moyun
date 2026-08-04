import 'package:daily_you/config_provider.dart';
import 'package:daily_you/time_manager.dart';
import 'package:daily_you/widgets/color_picker_dialog.dart';
import 'package:daily_you/widgets/settings_dropdown.dart';
import 'package:daily_you/widgets/settings_icon_action.dart';
import 'package:daily_you/widgets/settings_toggle.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'package:flutter/material.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:daily_you/theme_mode_provider.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key});

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettings> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _showAccentColorPopup(ThemeModeProvider themeProvider) async {
    final initialColor =
        Color(ConfigProvider.instance.get(ConfigKey.accentColor));
    final result = await showDialog<ColorPickerResult>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: initialColor),
    );
    if (result?.color != null) {
      themeProvider.accentColor = result!.color!;
      themeProvider.updateAccentColor();
    }
  }



  List<DropdownMenuItem<String>> _buildFirstDayOfWeekDropdownItems(
      BuildContext context) {
    final dayLabels = TimeManager.daysOfWeekLabels(context);
    List<DropdownMenuItem<String>> dropdownItems = List.empty(growable: true);
    dropdownItems.add(DropdownMenuItem<String>(
      value: "system",
      child: Text(AppLocalizations.of(context)!.themeSystem),
    ));

    var dropdownDays = List.generate(7, (index) {
      return DropdownMenuItem<String>(
        value: TimeManager.dayOfWeekIndexMapping[index],
        child: Text(
          dayLabels[index],
        ),
      );
    });
    dropdownItems.addAll(dropdownDays);
    return dropdownItems;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeModeProvider>(context);
    final configProvider = Provider.of<ConfigProvider>(context);

    return Stack(
      children: [
        const RicePaperBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(AppLocalizations.of(context)!.settingsAppearanceTitle),
            centerTitle: true,
            leading: Center(
              child: GlassActionButton(
                icon: Icons.arrow_back_ios_new_rounded,
                iconSize: 20,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsDropdown<String>(
              title: AppLocalizations.of(context)!.settingsTheme,
              value: configProvider.get(ConfigKey.theme),
              options: [
                DropdownMenuItem<String>(
                    value: "system",
                    child: Text(AppLocalizations.of(context)!.themeSystem)),
                DropdownMenuItem<String>(
                    value: "dark",
                    child: Text(AppLocalizations.of(context)!.themeDark)),
                DropdownMenuItem<String>(
                    value: "light",
                    child: Text(AppLocalizations.of(context)!.themeLight)),
                DropdownMenuItem<String>(
                    value: "amoled",
                    child: Text(AppLocalizations.of(context)!.themeAmoled)),
              ],
              onChanged: (String? newValue) {
                ThemeMode themeMode = ThemeMode.system;
                switch (newValue) {
                  case "system":
                    themeMode = ThemeMode.system;
                    break;
                  case "light":
                    themeMode = ThemeMode.light;
                    break;
                  case "dark":
                  case "amoled":
                    themeMode = ThemeMode.dark;
                    break;
                  default:
                    themeMode = ThemeMode.system;
                    break;
                }
                themeProvider.themeMode = themeMode;
                configProvider.set(ConfigKey.theme, newValue);
              }),
          SettingsToggle(
              title: AppLocalizations.of(context)!.settingsUseSystemAccentColor,
              settingsKey: ConfigKey.followSystemColor,
              onChanged: (value) {
                configProvider.set(ConfigKey.followSystemColor, value);
                themeProvider.updateAccentColor();
              }),
          if (!configProvider.get(ConfigKey.followSystemColor))
            SettingsIconAction(
              title: AppLocalizations.of(context)!.settingsCustomAccentColor,
              icon: Icon(Icons.colorize_rounded),
              onPressed: () async {
                _showAccentColorPopup(themeProvider);
              },
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SettingsDropdown<String>(
                title: "正文字体",
                value: configProvider.get(ConfigKey.cjkFont),
                options: [
                  DropdownMenuItem<String>(
                      value: "sotyr",
                      child: Text("仿宋", style: const TextStyle(fontFamily: 'SotyrFangsong'))),
                  DropdownMenuItem<String>(
                      value: "kaishu",
                      child: Text("楷书", style: const TextStyle(fontFamily: 'XuandongKaishu'))),
                ],
                onChanged: (String? newValue) async {
                  await configProvider.set(ConfigKey.cjkFont, newValue);
                }),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SettingsDropdown<String>(
                title: AppLocalizations.of(context)!.settingsFirstDayOfWeek,
                value: configProvider.get(ConfigKey.startingDayOfWeek),
                options: _buildFirstDayOfWeekDropdownItems(context),
                onChanged: (String? newValue) async {
                  await configProvider.set(
                      ConfigKey.startingDayOfWeek, newValue);
                }),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SettingsDropdown<String>(
                title: AppLocalizations.of(context)!.settingsCalendarSystem,
                value: configProvider.get(ConfigKey.calendarSystem),
                options: [
                  DropdownMenuItem<String>(
                      value: "system",
                      child: Text(AppLocalizations.of(context)!.themeSystem)),
                  DropdownMenuItem<String>(
                      value: "gregorian",
                      child: Text(AppLocalizations.of(context)!
                          .calendarSystemGregorian)),
                  DropdownMenuItem<String>(
                      value: "jalali",
                      child: Text(
                          AppLocalizations.of(context)!.calendarSystemJalali)),
                ],
                onChanged: (String? newValue) async {
                  await configProvider.set(ConfigKey.calendarSystem, newValue);
                }),
          ),
          ],
        ),
      ),
    ],
    );
  }
}
