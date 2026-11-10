import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/station.dart';

class RadioService {
  static const _rbServers = [
    'de1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'de2.api.radio-browser.info',
  ];
  static const _headers = {'User-Agent': 'RafeeqRadio/1.0'};
  final _cache = <String, ({DateTime at, List<Station> data})>{};

  List<Station>? _fromCache(String key, Duration ttl) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) return null;
    return entry.data;
  }

  void _toCache(String key, List<Station> data) {
    _cache[key] = (at: DateTime.now(), data: data);
  }

  Future<List<Map<String, dynamic>>> _rb(String path) async {
    for (final server in _rbServers) {
      try {
        final uri = Uri.https(server, '/json$path');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          return List<Map<String, dynamic>>.from(
              jsonDecode(res.body) as List);
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<Station>> fetchTopCharts() async {
    const key = 'topcharts';
    return _fromCache(key, const Duration(hours: 12)) ??
        await () async {
          final data = await _rb('/stations/topvote/60');
          final stations = data
              .map(Station.fromRadioBrowser)
              .where((s) => s.streamUrls.isNotEmpty)
              .toList();
          _toCache(key, stations);
          return stations;
        }();
  }

  Future<List<Station>> fetchByCountry(String isoCode) async {
    final key = 'country_$isoCode';
    return _fromCache(key, const Duration(hours: 12)) ??
        await () async {
          final data = await _rb(
              '/stations/bycountryexact/${Uri.encodeComponent(isoCode)}?limit=60&order=votes&reverse=true&hidebroken=true');
          final stations = data
              .map(Station.fromRadioBrowser)
              .where((s) => s.streamUrls.isNotEmpty)
              .toList();
          _toCache(key, stations);
          return stations;
        }();
  }

  Future<List<Station>> fetchByTag(String tag) async {
    final key = 'tag_$tag';
    return _fromCache(key, const Duration(hours: 12)) ??
        await () async {
          final data = await _rb(
              '/stations/bytag/${Uri.encodeComponent(tag)}?limit=60&order=votes&reverse=true&hidebroken=true');
          final stations = data
              .map(Station.fromRadioBrowser)
              .where((s) => s.streamUrls.isNotEmpty)
              .toList();
          _toCache(key, stations);
          return stations;
        }();
  }

  Future<List<Station>> search(String query) async {
    final data = await _rb(
        '/stations/search?name=${Uri.encodeComponent(query)}&limit=60&order=votes&reverse=true&hidebroken=true');
    return data
        .map(Station.fromRadioBrowser)
        .where((s) => s.streamUrls.isNotEmpty)
        .toList();
  }

  Future<List<Station>> fetchQuran() async {
    const key = 'quran';
    final cached = _fromCache(key, const Duration(hours: 24));
    if (cached != null) return cached;
    try {
      final res = await http
          .get(
            Uri.parse('https://www.mp3quran.net/api/v3/radios?language=Arabic'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
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

  void reportClick(String uuid) {
    final uri = Uri.https(_rbServers[0], '/json/url/$uuid');
    http.get(uri, headers: _headers).ignore();
  }
}

final radioServiceProvider = Provider((ref) => RadioService());
