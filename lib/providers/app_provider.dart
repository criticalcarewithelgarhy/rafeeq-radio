import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../services/radio_service.dart';
import '../services/storage_service.dart';

class FolderItem {
  final String id;
  final String name;
  final String emoji;
  const FolderItem(
      {required this.id, required this.name, required this.emoji});
}

class AppState {
  final String categoryId;
  final String? folderId;
  final String folderName;
  final String searchQuery;
  final List<Station> stations;
  final List<FolderItem> folders;
  final bool loading;
  final String? error;

  const AppState({
    this.categoryId = 'favorites',
    this.folderId,
    this.folderName = '',
    this.searchQuery = '',
    this.stations = const [],
    this.folders = const [],
    this.loading = false,
    this.error,
  });

  AppState copyWith({
    String? categoryId,
    String? folderId,
    String? folderName,
    String? searchQuery,
    List<Station>? stations,
    List<FolderItem>? folders,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearFolder = false,
  }) =>
      AppState(
        categoryId: categoryId ?? this.categoryId,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        folderName: clearFolder ? '' : (folderName ?? this.folderName),
        searchQuery: searchQuery ?? this.searchQuery,
        stations: stations ?? this.stations,
        folders: folders ?? this.folders,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AppNotifier extends StateNotifier<AppState> {
  final Ref _ref;

  static const arabicCountries = [
    FolderItem(id: 'EG', name: 'مصر', emoji: '🇪🇬'),
    FolderItem(id: 'SA', name: 'السعودية', emoji: '🇸🇦'),
    FolderItem(id: 'AE', name: 'الإمارات', emoji: '🇦🇪'),
    FolderItem(id: 'MA', name: 'المغرب', emoji: '🇲🇦'),
    FolderItem(id: 'DZ', name: 'الجزائر', emoji: '🇩🇿'),
    FolderItem(id: 'TN', name: 'تونس', emoji: '🇹🇳'),
    FolderItem(id: 'LY', name: 'ليبيا', emoji: '🇱🇾'),
    FolderItem(id: 'IQ', name: 'العراق', emoji: '🇮🇶'),
    FolderItem(id: 'SY', name: 'سوريا', emoji: '🇸🇾'),
    FolderItem(id: 'JO', name: 'الأردن', emoji: '🇯🇴'),
    FolderItem(id: 'LB', name: 'لبنان', emoji: '🇱🇧'),
    FolderItem(id: 'KW', name: 'الكويت', emoji: '🇰🇼'),
    FolderItem(id: 'QA', name: 'قطر', emoji: '🇶🇦'),
    FolderItem(id: 'BH', name: 'البحرين', emoji: '🇧🇭'),
    FolderItem(id: 'OM', name: 'عُمان', emoji: '🇴🇲'),
    FolderItem(id: 'YE', name: 'اليمن', emoji: '🇾🇪'),
    FolderItem(id: 'PS', name: 'فلسطين', emoji: '🇵🇸'),
    FolderItem(id: 'SD', name: 'السودان', emoji: '🇸🇩'),
    FolderItem(id: 'SO', name: 'الصومال', emoji: '🇸🇴'),
    FolderItem(id: 'MR', name: 'موريتانيا', emoji: '🇲🇷'),
    FolderItem(id: 'DJ', name: 'جيبوتي', emoji: '🇩🇯'),
    FolderItem(id: 'KM', name: 'جزر القمر', emoji: '🇰🇲'),
  ];

  static const genres = [
    FolderItem(id: 'arabic music', name: 'موسيقى عربية', emoji: '🎵'),
    FolderItem(id: 'quran', name: 'قرآن', emoji: '☽'),
    FolderItem(id: 'news', name: 'أخبار', emoji: '📰'),
    FolderItem(id: 'sports', name: 'رياضة', emoji: '⚽'),
    FolderItem(id: 'pop', name: 'بوب', emoji: '🎤'),
    FolderItem(id: 'rock', name: 'روك', emoji: '🎸'),
    FolderItem(id: 'jazz', name: 'جاز', emoji: '🎷'),
    FolderItem(id: 'classical', name: 'كلاسيك', emoji: '🎻'),
    FolderItem(id: 'talk', name: 'حوارات', emoji: '🎙'),
    FolderItem(id: 'kids', name: 'أطفال', emoji: '🎠'),
  ];

  AppNotifier(this._ref) : super(const AppState()) {
    loadCategory('favorites');
  }

  Future<void> loadCategory(String id) async {
    state = state.copyWith(
      categoryId: id,
      loading: true,
      clearError: true,
      clearFolder: true,
      stations: [],
      folders: [],
    );
    try {
      final rs = _ref.read(radioServiceProvider);
      final ss = _ref.read(storageServiceProvider);
      switch (id) {
        case 'favorites':
          final favs = await ss.getFavorites();
          state = state.copyWith(stations: favs, loading: false);
        case 'recent':
          final recent = await ss.getRecent();
          state = state.copyWith(stations: recent, loading: false);
        case 'quran':
          final stations = await rs.fetchQuran();
          state = state.copyWith(stations: stations, loading: false);
        case 'topcharts':
          final stations = await rs.fetchTopCharts();
          state = state.copyWith(stations: stations, loading: false);
        case 'countries_ar':
          state = state.copyWith(
              folders: arabicCountries, loading: false);
        case 'genres':
          state = state.copyWith(folders: genres, loading: false);
        case 'news':
          final stations = await rs.fetchByTag('news');
          state = state.copyWith(stations: stations, loading: false);
        case 'sports':
          final stations = await rs.fetchByTag('sport');
          state = state.copyWith(stations: stations, loading: false);
        case 'search':
          state = state.copyWith(stations: [], loading: false);
        default:
          state = state.copyWith(loading: false);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: 'خطأ في التحميل');
    }
  }

  Future<void> loadFolder(String id, String name) async {
    state = state.copyWith(
      folderId: id,
      folderName: name,
      loading: true,
      clearError: true,
      stations: [],
    );
    try {
      final rs = _ref.read(radioServiceProvider);
      List<Station> stations;
      if (state.categoryId == 'countries_ar') {
        stations = await rs.fetchByCountry(id);
      } else {
        stations = await rs.fetchByTag(id);
      }
      state = state.copyWith(stations: stations, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'خطأ في التحميل');
    }
  }

  Future<void> doSearch(String query) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(
        searchQuery: query,
        loading: true,
        clearError: true,
        stations: []);
    try {
      final stations =
          await _ref.read(radioServiceProvider).search(query);
      state = state.copyWith(stations: stations, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'خطأ في البحث');
    }
  }

  void goBack() {
    state = state.copyWith(
        clearFolder: true, stations: [], folders: []);
    if (state.categoryId == 'countries_ar') {
      state = state.copyWith(folders: AppNotifier.arabicCountries);
    } else if (state.categoryId == 'genres') {
      state = state.copyWith(folders: AppNotifier.genres);
    }
  }

  Future<void> refreshFavorites() async {
    if (state.categoryId == 'favorites') {
      final favs =
          await _ref.read(storageServiceProvider).getFavorites();
      state = state.copyWith(stations: favs);
    }
  }
}

final appProvider =
    StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(ref),
);
