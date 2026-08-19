import 'package:flutter/material.dart';

class NetStatusDashboard extends StatelessWidget {
  const NetStatusDashboard({
    super.key,
    required this.trackingActive,
    required this.gpsEnabled,
    required this.gpsPermissionGranted,
    required this.serverConnected,
    required this.serverMessage,
    this.lastUpdate,
  });

  final bool trackingActive;
  final bool gpsEnabled;
  final bool gpsPermissionGranted;
  final bool serverConnected;
  final String? serverMessage;
  final DateTime? lastUpdate;

  String get gpsText {
    if (!trackingActive) return 'Desativado';
    if (!gpsPermissionGranted) return 'Permissão de localização negada';
    if (!gpsEnabled) return 'Localização desativada';
    return 'Ativo';
  }

  String get serverText {
    if (!trackingActive) return 'Aguardando rastreamento';
    if (serverConnected) {
      return serverMessage == null ? 'Conectado' : 'Conectado • $serverMessage';
    }
    return serverMessage ?? 'Sem comunicação';
  }

  String get communicationText {
    if (lastUpdate == null) return 'Aguardando comunicação';
    final h = lastUpdate!.hour.toString().padLeft(2, '0');
    final m = lastUpdate!.minute.toString().padLeft(2, '0');
    final s = lastUpdate!.second.toString().padLeft(2, '0');
    return 'Última comunicação: $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final gpsActive = trackingActive && gpsEnabled && gpsPermissionGranted;
    final serverActive = trackingActive && serverConnected;
    final communicationActive = trackingActive && lastUpdate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF243A45), Color(0xFF315E69)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset('assets/2net_icon.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2NET Rastreamento',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Monitoramento do dispositivo',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              _Dot(active: trackingActive),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StatusCard(
          icon: Icons.location_on_outlined,
          title: 'Rastreamento',
          value: trackingActive ? 'Ativo' : 'Inativo',
          active: trackingActive,
        ),
        const SizedBox(height: 10),
        _StatusCard(
          icon: Icons.gps_fixed,
          title: 'GPS',
          value: gpsText,
          active: gpsActive,
        ),
        const SizedBox(height: 10),
        _StatusCard(
          icon: Icons.cloud_outlined,
          title: 'Servidor',
          value: serverText,
          active: serverActive,
        ),
        const SizedBox(height: 10),
        _StatusCard(
          icon: Icons.schedule,
          title: 'Comunicação',
          value: communicationText,
          active: communicationActive,
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF61D19A) : Colors.white54,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 25),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value),
              ],
            ),
          ),
          Icon(active ? Icons.check_circle : Icons.info_outline, size: 21),
        ],
      ),
    );
  }
}
