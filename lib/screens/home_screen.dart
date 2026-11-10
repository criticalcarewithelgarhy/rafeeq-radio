import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/category_bar.dart';
import '../widgets/station_card.dart';
import '../widgets/now_playing_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Timer _clockTimer;
  String _clockText = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    setState(() => _clockText = '$h:$m');
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appProvider);
    final isSearch = appState.categoryId == 'search';

    // When switching away from search, clear the field
    if (!isSearch && _searchCtrl.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchCtrl.clear();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AppBar(clockText: _clockText),
            const CategoryBar(),
            const SizedBox(height: 4),
            // Folder back row
            if (appState.folderId != null)
              _FolderHeader(folderName: appState.folderName),
            // Search bar
            if (isSearch && appState.folderId == null)
              _SearchBar(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onSearch: (q) =>
                    ref.read(appProvider.notifier).doSearch(q),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: _buildBody(appState),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }

  Widget _buildBody(AppState appState) {
    if (appState.loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
          strokeWidth: 2,
        ),
      );
    }

    if (appState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.muted, size: 48),
            const SizedBox(height: 12),
            Text(
              appState.error!,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref
                  .read(appProvider.notifier)
                  .loadCategory(appState.categoryId),
              child: const Text('إعادة المحاولة',
                  style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      );
    }

    // Folders grid
    if (appState.folders.isNotEmpty && appState.folderId == null) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: appState.folders.length,
        itemBuilder: (ctx, i) => FolderCard(item: appState.folders[i]),
      );
    }

    // Stations grid
    if (appState.stations.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: appState.stations.length,
        itemBuilder: (ctx, i) =>
            StationCard(station: appState.stations[i]),
      );
    }

    // Empty states
    return _EmptyState(categoryId: appState.categoryId);
  }
}

class _AppBar extends StatelessWidget {
  final String clockText;
  const _AppBar({required this.clockText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.bg,
      child: Row(
        children: [
          // Brand name (RTL: right side)
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'رفيق ',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'راديو',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              clockText,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderHeader extends ConsumerWidget {
  final String folderName;
  const _FolderHeader({required this.folderName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                color: AppColors.muted, size: 18),
            onPressed: () => ref.read(appProvider.notifier).goBack(),
          ),
          const SizedBox(width: 4),
          Text(
            folderName,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onSearch;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSearch,
        style: const TextStyle(color: AppColors.ink, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'ابحث عن محطة...',
          prefixIcon: const Icon(Icons.search, color: AppColors.gold),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppColors.gold),
            onPressed: () => onSearch(controller.text),
          ),
        ),
      ),
    );
  }
}

class FolderCard extends ConsumerWidget {
  final FolderItem item;
  const FolderCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          ref.read(appProvider.notifier).loadFolder(item.id, item.name),
      child: Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String categoryId;
  const _EmptyState({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final (icon, msg) = switch (categoryId) {
      'favorites' => (Icons.star_border, 'لا توجد محطات مفضلة بعد\nاضغط مطولاً على أي محطة لإضافتها'),
      'recent' => (Icons.history, 'لم تستمع لأي محطة بعد'),
      'search' => (Icons.search, 'ابحث عن المحطة التي تريدها'),
      _ => (Icons.radio, 'لا توجد نتائج'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.muted, size: 64),
            const SizedBox(height: 16),
            Text(
              msg,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
