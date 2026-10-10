enum ExternalCalendarSource {
  google,
  apple,
  outlook,
  deviceNative;
}

class ExternalCalendarEvent {
  final String externalId;
  final String calendarId;
  final ExternalCalendarSource source;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? recurrenceRule;
  final DateTime lastModified;
  final String? etag;

  const ExternalCalendarEvent({
    required this.externalId,
    required this.calendarId,
    required this.source,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.recurrenceRule,
    required this.lastModified,
    this.etag,
  });

  Map<String, dynamic> toJson() => {
        'external_id': externalId,
        'calendar_id': calendarId,
        'source': source.name,
        'title': title,
        'description': description,
        'location': location,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_all_day': isAllDay,
        'recurrence_rule': recurrenceRule,
        'last_modified': lastModified.toIso8601String(),
        'etag': etag,
      };

  factory ExternalCalendarEvent.fromJson(Map<String, dynamic> json) {
    return ExternalCalendarEvent(
      externalId: json['external_id'] as String,
      calendarId: json['calendar_id'] as String,
      source: ExternalCalendarSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => ExternalCalendarSource.deviceNative,
      ),
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      isAllDay: json['is_all_day'] as bool? ?? false,
      recurrenceRule: json['recurrence_rule'] as String?,
      lastModified: DateTime.parse(json['last_modified'] as String),
      etag: json['etag'] as String?,
    );
  }
}
