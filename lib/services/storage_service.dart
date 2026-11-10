import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';

class StorageService {
  static const _favKey = 'rafeeq.favorites';
  static const _recentKey = 'rafeeq.recent';

  Future<List<Station>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favKey) ?? [];
    return raw
        .map((s) => Station.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFavorite(Station s) async {
    final favs = await getFavorites();
    if (favs.any((f) => f.id == s.id)) return;
    favs.insert(0, s);
    await _saveFavorites(favs);
  }

  Future<void> removeFavorite(String id) async {
    final favs = await getFavorites();
    favs.removeWhere((f) => f.id == id);
    await _saveFavorites(favs);
  }

  Future<bool> isFavorite(String id) async {
    final favs = await getFavorites();
    return favs.any((f) => f.id == id);
  }

  Future<void> _saveFavorites(List<Station> favs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _favKey, favs.map((s) => jsonEncode(s.toJson())).toList());
  }

  Future<List<Station>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentKey) ?? [];
    return raw
        .map((s) => Station.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRecent(Station s) async {
    final recent = await getRecent();
    recent.removeWhere((r) => r.id == s.id);
    recent.insert(0, s);
    if (recent.length > 30) recent.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _recentKey, recent.map((r) => jsonEncode(r.toJson())).toList());
  }
}

final storageServiceProvider = Provider((ref) => StorageService());
