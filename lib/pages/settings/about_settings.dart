import 'package:daily_you/config_provider.dart';
import 'package:daily_you/device_info_service.dart';
import 'package:daily_you/theme_mode_provider.dart';
import 'package:daily_you/widgets/settings_icon_action.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'package:flutter/material.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  final Color pinkAccentColor = const Color(0xffff00d5);
  int versionTapCount = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    final themeProvider = Provider.of<ThemeModeProvider>(context);

    return Stack(
      children: [
        const RicePaperBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(AppLocalizations.of(context)!.settingsAboutTitle),
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
        children: [
          SettingsIconAction(
              title: AppLocalizations.of(context)!.settingsSourceCode,
              hint: "github.com/Molelung/Moyun",
              icon: Icon(Icons.open_in_new_rounded),
              onPressed: () async {
                await launchUrl(Uri.https("github.com", "/Molelung/Moyun"),
                    mode: LaunchMode.externalApplication);
              }),
          SettingsIconAction(
            title: AppLocalizations.of(context)!.settingsHelpTranslate,
            hint: "github.com/Molelung/Moyun/issues",
            icon: Icon(Icons.open_in_new_rounded),
            onPressed: () async {
              await launchUrl(
                  Uri.https("github.com", "/Molelung/Moyun/issues"),
                  mode: LaunchMode.externalApplication);
            },
          ),
          SettingsIconAction(
              title: AppLocalizations.of(context)!.settingsLicense,
              hint: AppLocalizations.of(context)!.licenseGPLv3,
              icon: Icon(Icons.open_in_new_rounded),
              onPressed: () async {
                await launchUrl(
                    Uri.https("github.com",
                        "/Molelung/Moyun/blob/main/LICENSE.txt"),
                    mode: LaunchMode.externalApplication);
              }),
          GestureDetector(
            child: SettingsIconAction(
                title: AppLocalizations.of(context)!.settingsVersion,
                hint: DeviceInfoService().appInfo?.version ?? "0.0.0",
                icon: Icon(Icons.open_in_new_rounded),
                onPressed: () async {
                  await launchUrl(
                      Uri.https("github.com", "/Molelung/Moyun/releases"),
                      mode: LaunchMode.externalApplication);
                }),
            onTap: () async {
              versionTapCount += 1;
              if (versionTapCount > 5) {
                versionTapCount = 0;

                await configProvider.set(ConfigKey.followSystemColor, false);

                themeProvider.accentColor = pinkAccentColor;
                themeProvider.updateAccentColor();

                await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Center(
                          child: Text(AppLocalizations.of(context)!
                              .settingsMadeWithLove)),
                    );
                  },
                );
              }
            },
          ),
      ],
    ),
    ),
    ],
    );
  }
}
