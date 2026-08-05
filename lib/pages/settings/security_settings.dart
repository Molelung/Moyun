import 'package:daily_you/config_provider.dart';
import 'package:daily_you/device_info_service.dart';
import 'package:daily_you/app_text.dart';
import 'package:daily_you/widgets/auth_popup.dart';
import 'package:daily_you/widgets/settings_icon_action.dart';
import 'package:daily_you/widgets/settings_toggle.dart';
import 'package:daily_you/widgets/settings_dropdown.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'package:flutter/material.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:daily_you/utils/backup_restore_utils.dart';
import 'package:daily_you/utils/export_utils.dart';

class SecuritySettings extends StatefulWidget {
  const SecuritySettings({super.key});

  @override
  State<SecuritySettings> createState() => SecuritySettingsPageState();
}

class SecuritySettingsPageState extends State<SecuritySettings> {
  Future<void> _showExportSelectionPopup() async {
    ExportFormat chosenFormat = ExportFormat.none;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.logFormatTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!
                  .settingsExportFormatDescription),
              Divider(),
              ListTile(
                  title: Text(AppLocalizations.of(context)!.formatMarkdown),
                  onTap: () {
                    chosenFormat = ExportFormat.markdown;
                    Navigator.of(context).pop();
                  }),
              ListTile(
                  title: Text(AppText.exportWord),
                  onTap: () {
                    chosenFormat = ExportFormat.word;
                    Navigator.of(context).pop();
                  }),
              ListTile(
                  title: Text(AppText.exportPdf),
                  onTap: () {
                    chosenFormat = ExportFormat.pdf;
                    Navigator.of(context).pop();
                  }),
            ],
          ),
        );
      },
    );

    if (chosenFormat != ExportFormat.none) {
      ValueNotifier<String> statusNotifier = ValueNotifier<String>("");

      BackupRestoreUtils.showLoadingStatus(context, statusNotifier);

      if (chosenFormat == ExportFormat.markdown) {
        await ExportUtils.exportToMarkdown(context, (status) {
          statusNotifier.value = status;
        });
      } else if (chosenFormat == ExportFormat.word) {
        await ExportUtils.exportToWord(context, (status) {
          statusNotifier.value = status;
        });
      } else if (chosenFormat == ExportFormat.pdf) {
        await ExportUtils.exportToPdf(context, (status) {
          statusNotifier.value = status;
        });
      }

      Navigator.of(context).pop();
    }
  }

  Future<void> _backupData(BuildContext context) async {
    ValueNotifier<String> statusNotifier = ValueNotifier<String>("");

    BackupRestoreUtils.showLoadingStatus(context, statusNotifier);

    bool success = await BackupRestoreUtils.backupToZip(context, (status) {
      statusNotifier.value = status;
    });

    Navigator.of(context).pop();

    if (!success) {
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Text(AppLocalizations.of(context)!.errorTitle),
                actions: [
                  TextButton(
                    child:
                        Text(MaterialLocalizations.of(context).okButtonLabel),
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                  ),
                ],
                content:
                    Text(AppLocalizations.of(context)!.backupErrorDescription));
          });
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    ValueNotifier<String> statusNotifier = ValueNotifier<String>("");

    BackupRestoreUtils.showLoadingStatus(context, statusNotifier);

    bool success = await BackupRestoreUtils.restoreFromZip(context, (status) {
      statusNotifier.value = status;
    });

    Navigator.of(context).pop();

    if (!success) {
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Text(AppLocalizations.of(context)!.errorTitle),
                actions: [
                  TextButton(
                    child:
                        Text(MaterialLocalizations.of(context).okButtonLabel),
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                  ),
                ],
                content: Text(
                    AppLocalizations.of(context)!.restoreErrorDescription));
          });
    }
  }

  Future<void> _showRestoreWarning() async {
    bool confirmed = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.warningTitle),
          content: Text(
              AppLocalizations.of(context)!.settingsRestorePromptDescription),
          actions: [
            TextButton(
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              onPressed: () async {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
              onPressed: () async {
                confirmed = true;
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
    if (confirmed) {
      await _restoreData(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    final LocalAuthentication auth = LocalAuthentication();

    return Stack(
      children: [
        const RicePaperBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(AppLocalizations.of(context)!.settingsSecurityTitle),
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: GlassActionButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  iconSize: 20,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          SettingsToggle(
              title:
                  AppLocalizations.of(context)!.settingsSecurityRequirePassword,
              settingsKey: ConfigKey.requirePassword,
              onChanged: (value) async {
                if (!configProvider.get(ConfigKey.requirePassword)) {
                  // Set a password
                  bool setPassword = false;
                  await showDialog(
                      context: context,
                      builder: (context) => AuthPopup(
                            mode: AuthPopupMode.setPassword,
                            title: AppLocalizations.of(context)!
                                .settingsSecuritySetPassword,
                            showBiometrics: false,
                            dismissable: true,
                            onSuccess: () {
                              setPassword = true;
                            },
                          ));
                  await configProvider.set(
                      ConfigKey.requirePassword, setPassword);
                } else {
                  // Disable password
                  await showDialog(
                      context: context,
                      builder: (context) => AuthPopup(
                            mode: AuthPopupMode.unlock,
                            title: AppLocalizations.of(context)!
                                .settingsSecurityEnterPassword,
                            showBiometrics: false,
                            dismissable: true,
                            onSuccess: () {
                              configProvider.set(
                                  ConfigKey.requirePassword, false);
                            },
                          ));
                }
              }),
          if (configProvider.get(ConfigKey.requirePassword))
            SettingsIconAction(
                title: AppLocalizations.of(context)!
                    .settingsSecurityChangePassword,
                icon: Icon(Icons.edit_rounded),
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (context) => AuthPopup(
                            mode: AuthPopupMode.changePassword,
                            title: AppLocalizations.of(context)!
                                .settingsSecurityChangePassword,
                            showBiometrics: false,
                            dismissable: true,
                            onSuccess: () {},
                          ));
                }),
          if (configProvider.get(ConfigKey.requirePassword) &&
              (DeviceInfoService().supportsBiometrics ?? false))
            SettingsToggle(
                title: AppLocalizations.of(context)!
                    .settingsSecurityBiometricUnlock,
                settingsKey: ConfigKey.biometricUnlock,
                onChanged: (value) async {
                  await showDialog(
                      context: context,
                      builder: (context) => AuthPopup(
                            mode: AuthPopupMode.unlock,
                            title: AppLocalizations.of(context)!
                                .settingsSecurityEnterPassword,
                            showBiometrics: false,
                            dismissable: true,
                            onSuccess: () async {
                              bool success = true;
                              // Only require biometric authentication when enabling biometric unlock
                              if (value == true) {
                                try {
                                  final bool didAuthenticate =
                                      await auth.authenticate(
                                          persistAcrossBackgrounding: false,
                                          biometricOnly: true,
                                          localizedReason:
                                              AppLocalizations.of(context)!
                                                  .unlockAppPrompt);
                                  success = didAuthenticate;
                                } on PlatformException {
                                  success = false;
                                }
                              }

                              if (success) {
                                configProvider.set(
                                    ConfigKey.biometricUnlock, value);
                              }
                            },
                          ));
                }),
          SettingsDropdown<String>(
              title: AppLocalizations.of(context)!.settingsImageQuality,
              value: configProvider.get(ConfigKey.imageQualityLevel),
              options: [
                DropdownMenuItem<String>(
                    value: ImageQuality.noCompression,
                    child: Text(AppLocalizations.of(context)!
                        .imageQualityNoCompression)),
                DropdownMenuItem<String>(
                    value: ImageQuality.high,
                    child:
                        Text(AppLocalizations.of(context)!.imageQualityHigh)),
                DropdownMenuItem<String>(
                    value: ImageQuality.medium,
                    child:
                        Text(AppLocalizations.of(context)!.imageQualityMedium)),
                DropdownMenuItem<String>(
                    value: ImageQuality.low,
                    child: Text(AppLocalizations.of(context)!.imageQualityLow)),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  configProvider.set(ConfigKey.imageQualityLevel, newValue);
                }
              }),
          SettingsToggle(
            title: AppText.backupEncryption,
            settingsKey: ConfigKey.encryptBackup,
            onChanged: (value) async {
              if (value) {
                // Turn on encryption, prompt for password
                bool setPassword = false;
                await showDialog(
                    context: context,
                    builder: (context) => AuthPopup(
                          mode: AuthPopupMode.setPassword,
                          title: AppText.setBackupPassword,
                          showBiometrics: false,
                          dismissable: true,
                          targetConfigKey: ConfigKey.backupPassword,
                          onSuccess: () {
                            setPassword = true;
                          },
                        ));
                await configProvider.set(ConfigKey.encryptBackup, setPassword);
              } else {
                // Disable encryption
                await configProvider.set(ConfigKey.encryptBackup, false);
                await configProvider.set(ConfigKey.backupPassword, "");
              }
            },
          ),
          if (configProvider.get(ConfigKey.encryptBackup))
            SettingsIconAction(
              title: AppText.changeBackupPassword,
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (context) => AuthPopup(
                          mode: AuthPopupMode.changePassword,
                          title: AppText.changeBackupPassword,
                          showBiometrics: false,
                          dismissable: true,
                          targetConfigKey: ConfigKey.backupPassword,
                          onSuccess: () {},
                        ));
              },
            ),
          SettingsIconAction(
              title: AppLocalizations.of(context)!.settingsBackup,
              icon: Icon(Icons.backup_rounded),
              onPressed: () async {
                await _backupData(context);
              }),
          SettingsIconAction(
              title: AppLocalizations.of(context)!.settingsRestore,
              icon: Icon(Icons.restore_rounded),
              onPressed: () async {
                await _showRestoreWarning();
              }),
          SettingsIconAction(
              title:
                  AppLocalizations.of(context)!.settingsExportToAnotherFormat,
              icon: Icon(Icons.upload_rounded),
              onPressed: () async {
                await _showExportSelectionPopup();
              }),
          ],
        ),
      ),
    ],
    );
  }
}
