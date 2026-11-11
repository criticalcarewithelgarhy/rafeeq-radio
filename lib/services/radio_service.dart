import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/station.dart';

class CountryItem {
  final String code;
  final String name;
  final int count;
  const CountryItem({required this.code, required this.name, required this.count});
}

class RadioService {
  static const _rbServers = [
    'de1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'de2.api.radio-browser.info',
  ];
  static const _headers = {'User-Agent': 'RafeeqRadio/1.0'};

  final _stationCache = <String, ({DateTime at, List<Station> data})>{};
  ({DateTime at, List<CountryItem> data})? _countriesCache;

  List<Station>? _fromCache(String key, Duration ttl) {
    final entry = _stationCache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) return null;
    return entry.data;
  }

  void _toCache(String key, List<Station> data) {
    _stationCache[key] = (at: DateTime.now(), data: data);
  }

  Future<List<Map<String, dynamic>>> _rb(String path) async {
    for (final server in _rbServers) {
      try {
        // Use Uri.parse to correctly handle query parameters in path
        final uri = Uri.parse('https://$server/json$path');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body is List) return List<Map<String, dynamic>>.from(body);
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<Station>> fetchTopCharts() async {
    const key = 'topcharts';
    return _fromCache(key, const Duration(hours: 12)) ?? await () async {
      final data = await _rb('/stations/topvote/60');
      final stations = data.map(Station.fromRadioBrowser).where((s) => s.streamUrls.isNotEmpty).toList();
      _toCache(key, stations);
      return stations;
    }();
  }

  Future<List<Station>> fetchByCountry(String isoCode) async {
    final code = isoCode.toUpperCase();
    final key = 'country_$code';
    return _fromCache(key, const Duration(hours: 12)) ?? await () async {
      final data = await _rb('/stations/bycountrycodeexact/$code?limit=60&order=votes&reverse=true&hidebroken=true');
      final stations = data.map(Station.fromRadioBrowser).where((s) => s.streamUrls.isNotEmpty).toList();
      _toCache(key, stations);
      return stations;
    }();
  }

  Future<List<Station>> fetchByTag(String tag) async {
    final key = 'tag_$tag';
    return _fromCache(key, const Duration(hours: 12)) ?? await () async {
      final encoded = Uri.encodeComponent(tag);
      final data = await _rb('/stations/bytag/$encoded?limit=60&order=votes&reverse=true&hidebroken=true');
      final stations = data.map(Station.fromRadioBrowser).where((s) => s.streamUrls.isNotEmpty).toList();
      _toCache(key, stations);
      return stations;
    }();
  }

  Future<List<Station>> search(String query) async {
    final encoded = Uri.encodeComponent(query);
    final data = await _rb('/stations/search?name=$encoded&limit=60&order=votes&reverse=true&hidebroken=true');
    return data.map(Station.fromRadioBrowser).where((s) => s.streamUrls.isNotEmpty).toList();
  }

  Future<List<Station>> fetchQuran() async {
    const key = 'quran';
    final cached = _fromCache(key, const Duration(hours: 24));
    if (cached != null) return cached;
    try {
      final res = await http
          .get(Uri.parse('https://www.mp3quran.net/api/v3/radios?language=Arabic'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final radios = (json['radios'] as List?) ?? [];
        final stations = radios
            .cast<Map<String, dynamic>>()
            .map(Station.fromQuran)
            .where((s) => s.streamUrls.isNotEmpty)
            .toList();
        _toCache(key, stations);
        return stations;
      }
    } catch (_) {}
    return [];
  }

  Future<List<CountryItem>> fetchCountries() async {
    final cached = _countriesCache;
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(hours: 24)) {
      return cached.data;
    }
    // /countries returns {name, iso_3166_1, stationcount}
    final data = await _rb('/countries?order=stationcount&reverse=true&hidebroken=true');
    final result = data
        .where((c) {
          final code = (c['iso_3166_1'] as String? ?? '').trim();
          final count = c['stationcount'] as int? ?? 0;
          return code.isNotEmpty && count > 5;
        })
        .map((c) => CountryItem(
              code: (c['iso_3166_1'] as String).trim().toUpperCase(),
              name: (c['name'] as String? ?? '').trim(),
              count: c['stationcount'] as int? ?? 0,
            ))
        .toList();
    _countriesCache = (at: DateTime.now(), data: result);
    return result;
  }

  void reportClick(String uuid) {
    final uri = Uri.parse('https://${_rbServers[0]}/json/url/$uuid');
    http.get(uri, headers: _headers).ignore();
  }
}

final radioServiceProvider = Provider((ref) => RadioService());
