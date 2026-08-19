import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:net_rastreamento/main.dart';
import 'package:net_rastreamento/password_service.dart';
import 'package:net_rastreamento/preferences.dart';

import 'geolocation_service.dart';
import 'l10n/app_localizations.dart';
import 'settings_screen.dart';
import 'status_screen.dart';
import 'status_service.dart';
import 'widgets/net_status_dashboard.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  bool trackingEnabled = false;
  bool gpsEnabled = false;
  bool gpsPermissionGranted = false;
  bool serverConnected = false;
  String? serverMessage;
  DateTime? lastCommunication;
  Timer? _statusTimer;
  bool _refreshingStatus = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _refreshState();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refreshState();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    if (_refreshingStatus) return;
    _refreshingStatus = true;

    try {
      final status = await StatusService.read();

      if (!mounted) return;

      setState(() {
        trackingEnabled = status.trackingActive;
        gpsEnabled = status.gpsEnabled;
        gpsPermissionGranted = status.hasLocationPermission;
        serverConnected = status.serverConnected;
        serverMessage = status.serverMessage;
        lastCommunication = status.lastCommunication;
      });
    } finally {
      _refreshingStatus = false;
    }
  }

  void refresh() => setState(() {});

  Widget _buildTrackingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.trackingTitle,
              ),
              titleTextStyle:
                  Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.idLabel,
              ),
              subtitle: Text(
                Preferences.instance
                        .getString(Preferences.id) ??
                    '',
              ),
            ),
            if (Platform.isAndroid) ...[
              Text(
                AppLocalizations.of(context)!.disclosureMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.trackingLabel,
              ),
              value: trackingEnabled,
              onChanged: (bool value) async {
                if (await PasswordService.authenticate(context) &&
                    mounted) {
                  if (value) {
                    FirebaseCrashlytics.instance
                        .log('tracking_toggle_start');

                    var started = false;

                    try {
                      await GeolocationService.tracker.start();
                      started = true;
                    } on PlatformException {
                      // permission denied or startup error
                    }

                    if (!mounted) return;

                    if (!started) {
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to start tracking. '
                            'Check location permissions.',
                          ),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }

                    setState(() {
                      trackingEnabled = started;
                    });

                    // Atualiza o painel após iniciar/parar.
                    await _refreshState();
                  } else {
                    FirebaseCrashlytics.instance
                        .log('tracking_toggle_stop');

                    await GeolocationService.tracker.stop();

                    if (mounted) {
                      setState(() {
                        trackingEnabled = false;
                      });
                    }

                    // Atualiza o painel após parar.
                    await _refreshState();
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            OverflowBar(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await GeolocationService.tracker
                          .requestPosition();
                    } on PlatformException {
                      // permission denied or location error
                    }

                    await _refreshState();
                  },
                  child: Text(
                    AppLocalizations.of(context)!.locationButton,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StatusScreen(),
                      ),
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.statusButton,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.settingsTitle,
              ),
              titleTextStyle:
                  Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.urlLabel,
              ),
              subtitle: Text(
                Preferences.instance
                        .getString(Preferences.url) ??
                    '',
              ),
            ),
            const SizedBox(height: 8),
            OverflowBar(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    if (await PasswordService.authenticate(context) &&
                        mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );

                      setState(() {});
                    }
                  },
                  child: Text(
                    AppLocalizations.of(context)!.settingsButton,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2NET Rastreamento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            NetStatusDashboard(
              trackingActive: trackingEnabled,
              gpsEnabled: gpsEnabled,
              gpsPermissionGranted: gpsPermissionGranted,
              serverConnected: serverConnected,
              serverMessage: serverMessage,
              lastUpdate: lastCommunication,
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: Image.asset(
                'assets/2net_logo.png',
                height: 72,
                fit: BoxFit.contain,
              ),
            ),

            _buildTrackingCard(),

            const SizedBox(height: 16),

            _buildSettingsCard(),
          ],
        ),
      ),
    );
  }
}
