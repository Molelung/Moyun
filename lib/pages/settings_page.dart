import 'dart:io';
import 'package:daily_you/pages/settings/about_settings.dart';
import 'package:daily_you/pages/settings/appearance_settings.dart';
import 'package:daily_you/pages/settings/language_settings.dart';
import 'package:daily_you/pages/settings/notification_settings.dart';
import 'package:daily_you/pages/settings/security_settings.dart';
import 'package:daily_you/widgets/glass_container.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:flutter/material.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        const RicePaperBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(
              AppLocalizations.of(context)!.pageSettingsTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            leading: Center(
              child: GlassActionButton(
                icon: Icons.arrow_back_ios_new_rounded,
                iconSize: 20,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    children: [
                      _SettingsTile(
                        icon: Icons.palette_rounded,
                        title: AppLocalizations.of(context)!
                            .settingsAppearanceTitle,
                        page: const AppearanceSettings(),
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        title: AppLocalizations.of(context)!
                            .settingsLanguageTitle,
                        page: const LanguageSettings(),
                      ),
                      if (Platform.isAndroid) ...[
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.notifications_rounded,
                          title: AppLocalizations.of(context)!
                              .settingsNotificationsTitle,
                          page: const NotificationSettings(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.security_rounded,
                        title: AppLocalizations.of(context)!
                            .settingsSecurityTitle,
                        page: const SecuritySettings(),
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.info_rounded,
                        title:
                            AppLocalizations.of(context)!.settingsAboutTitle,
                        page: const AboutSettings(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget page;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            allowSnapshotting: false,
            builder: (context) => page,
          ));
        },
      ),
    );
  }
}