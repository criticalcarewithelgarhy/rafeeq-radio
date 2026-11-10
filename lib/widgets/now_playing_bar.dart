import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../theme.dart';
import 'eq_bars.dart';
import 'now_playing_sheet.dart';

class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ps = ref.watch(playerProvider);

    return GestureDetector(
      onTap: ps.station != null
          ? () => _showSheet(context)
          : null,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(color: AppColors.gold, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Logo
            _buildLogo(ps.station?.logoUrl, ps.station?.name),
            const SizedBox(width: 12),
            // Station info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ps.station?.name ?? 'رفيق راديو',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusText(ps),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            // EQ bars (only when playing)
            if (ps.playing) ...[
              EqBars(playing: true, barCount: 4, size: 'small'),
              const SizedBox(width: 12),
            ],
            // Play/Pause button
            IconButton(
              onPressed: ps.station != null
                  ? () => ref.read(playerProvider.notifier).togglePlayPause()
                  : null,
              icon: ps.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      ps.playing ? Icons.pause : Icons.play_arrow,
                      color: ps.station != null
                          ? AppColors.gold
                          : AppColors.muted,
                      size: 36,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(PlayerState ps) {
    if (ps.error != null) return ps.error!;
    if (ps.loading) return 'جاري الاتصال...';
    if (ps.playing) return 'جاري التشغيل';
    if (ps.station != null) return 'متوقف';
    return 'اختر محطة للاستماع';
  }

  Widget _buildLogo(String? logoUrl, String? name) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bg,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              errorWidget: (ctx, url, err) =>
                  _fallbackIcon(name),
              placeholder: (ctx, url) => _fallbackIcon(name),
            )
          : _fallbackIcon(name),
    );
  }

  Widget _fallbackIcon(String? name) {
    return Container(
      color: AppColors.bg,
      child: Center(
        child: name != null && name.isNotEmpty
            ? Text(
                name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '♪',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Icon(Icons.music_note,
                color: AppColors.muted, size: 20),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => const NowPlayingSheet(),
      ),
    );
  }
}
