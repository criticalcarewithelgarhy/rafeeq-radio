class Station {
  final String id;
  final String name;
  final String? logoUrl;
  final List<String> streamUrls;
  final String? country;
  final String? countryCode;
  final String? tags;
  final bool isHls;
  final String? uuid;

  const Station({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.streamUrls,
    this.country,
    this.countryCode,
    this.tags,
    this.isHls = false,
    this.uuid,
  });

  factory Station.fromRadioBrowser(Map<String, dynamic> j) {
    final url = (j['url_resolved'] as String?)?.isNotEmpty == true
        ? j['url_resolved'] as String
        : j['url'] as String? ?? '';
    final codec = (j['codec'] as String? ?? '').toLowerCase();
    return Station(
      id: 'rb-${j['stationuuid']}',
      name: (j['name'] as String? ?? 'Unknown').trim(),
      logoUrl: j['favicon'] as String?,
      streamUrls: url.isNotEmpty ? [url] : [],
      country: j['country'] as String?,
      countryCode: (j['countrycode'] as String?)?.toUpperCase(),
      tags: j['tags'] as String?,
      isHls: codec == 'hls' || url.contains('.m3u8'),
      uuid: j['stationuuid'] as String?,
    );
  }

  factory Station.fromQuran(Map<String, dynamic> j) {
    final url = j['url'] as String? ?? '';
    return Station(
      id: 'mq-${j['id']}',
      name: (j['name'] as String? ?? 'Quran').trim(),
      logoUrl: null,
      streamUrls: url.isNotEmpty ? [url] : [],
      countryCode: 'QR',
      tags: 'quran,قرآن',
      isHls: url.contains('.m3u8'),
    );
  }

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        id: j['id'] as String,
        name: j['name'] as String,
        logoUrl: j['logoUrl'] as String?,
        streamUrls: List<String>.from(j['streamUrls'] as List),
        country: j['country'] as String?,
        countryCode: j['countryCode'] as String?,
        tags: j['tags'] as String?,
        isHls: j['isHls'] as bool? ?? false,
        uuid: j['uuid'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'streamUrls': streamUrls,
        'country': country,
        'countryCode': countryCode,
        'tags': tags,
        'isHls': isHls,
        'uuid': uuid,
      };

  @override
  bool operator ==(Object other) => other is Station && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
