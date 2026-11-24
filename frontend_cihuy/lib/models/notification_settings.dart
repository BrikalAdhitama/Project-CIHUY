class NotificationSettings {
  const NotificationSettings({
    this.enabled = false,
    this.exceeded = true,
    this.mode = 'local',
    this.progressTime = '20:00',
    this.motivationTime = '08:00',
    this.timezone = 'Asia/Makassar',
  });
  final bool enabled;
  final bool exceeded;
  final String mode, progressTime, motivationTime, timezone;

  NotificationSettings copyWith({
    bool? enabled,
    bool? exceeded,
    String? mode,
    String? progressTime,
    String? motivationTime,
    String? timezone,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    exceeded: exceeded ?? this.exceeded,
    mode: mode ?? this.mode,
    progressTime: progressTime ?? this.progressTime,
    motivationTime: motivationTime ?? this.motivationTime,
    timezone: timezone ?? this.timezone,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'exceeded': exceeded,
    'mode': mode,
    'progressTime': progressTime,
    'motivationTime': motivationTime,
    'timezone': timezone,
  };
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (json['enabled'] is! bool ||
        !['local', 'push'].contains(json['mode']) ||
        !time.hasMatch(json['progressTime'] as String? ?? '') ||
        !time.hasMatch(json['motivationTime'] as String? ?? '') ||
        json['timezone'] is! String) {
      throw const FormatException('Pengaturan notifikasi tidak valid.');
    }
    return NotificationSettings(
      enabled: json['enabled'],
      exceeded: json['exceeded'] as bool? ?? true,
      mode: json['mode'],
      progressTime: json['progressTime'],
      motivationTime: json['motivationTime'],
      timezone: json['timezone'],
    );
  }
}

String? notificationDestination(String? kind) => switch (kind) {
  'progress' || 'exceeded' => 'calendar',
  'motivation' => 'home',
  _ => null,
};

String notificationBody(String kind) => switch (kind) {
  'progress' => 'Luangkan waktu sebentar untuk mengisi catatan harianmu.',
  'exceeded' =>
    'Yuk, lihat progresmu hari ini. Masih ada kesempatan untuk langkah berikutnya.',
  _ => 'Satu langkah kecil hari ini tetap berarti. Terus lanjutkan usahamu.',
};
