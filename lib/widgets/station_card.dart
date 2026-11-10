import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../providers/player_provider.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'eq_bars.dart';

class StationCard extends ConsumerWidget {
  final Station station;

  const StationCard({super.key, required this.station});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final isPlaying = playerState.station?.id == station.id;
    final isActive = isPlaying && playerState.playing;

    return GestureDetector(
      onTap: () {
        ref.read(playerProvider.notifier).play(station);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showOptions(context, ref);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(color: AppColors.gold, width: 1.5)
              : Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: AppColors.gold.withAlpha(40),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StationLogo(
                  logoUrl: station.logoUrl, name: station.name),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      station.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                    ),
                    if (station.tags != null &&
                        station.tags!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        station.tags!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isPlaying) ...[
                const SizedBox(height: 6),
                EqBars(playing: isActive, barCount: 4, size: 'small'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _StationOptions(station: station),
    );
  }
}

class _StationLogo extends StatelessWidget {
  final String? logoUrl;
  final String name;

  const _StationLogo({this.logoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bg,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              errorWidget: (ctx, url, err) => _Fallback(name: name),
              placeholder: (ctx, url) => _Fallback(name: name),
            )
          : _Fallback(name: name),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String name;
  const _Fallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final char = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '♪';
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Text(
          char,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StationOptions extends ConsumerStatefulWidget {
  final Station station;
  const _StationOptions({required this.station});

  @override
  ConsumerState<_StationOptions> createState() => _StationOptionsState();
}

class _StationOptionsState extends ConsumerState<_StationOptions> {
  bool? _isFav;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  Future<void> _loadFav() async {
    final fav = await ref
        .read(storageServiceProvider)
        .isFavorite(widget.station.id);
    if (mounted) setState(() => _isFav = fav);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.station.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            if (_isFav == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2),
              )
            else ...[
              ListTile(
                leading: Icon(
                  _isFav! ? Icons.star : Icons.star_border,
                  color: AppColors.gold,
                ),
                title: Text(
                  _isFav! ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  style: const TextStyle(color: AppColors.ink),
                ),
                onTap: () async {
                  final ss = ref.read(storageServiceProvider);
                  if (_isFav!) {
                    await ss.removeFavorite(widget.station.id);
                  } else {
                    await ss.addFavorite(widget.station);
                  }
                  await ref.read(appProvider.notifier).refreshFavorites();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppColors.muted),
                title: const Text('مشاركة',
                    style: TextStyle(color: AppColors.ink)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
