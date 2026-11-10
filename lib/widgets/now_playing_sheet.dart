import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'eq_bars.dart';

class NowPlayingSheet extends ConsumerStatefulWidget {
  const NowPlayingSheet({super.key});

  @override
  ConsumerState<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends ConsumerState<NowPlayingSheet> {
  bool? _isFav;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  Future<void> _loadFav() async {
    final station = ref.read(playerProvider).station;
    if (station == null) return;
    final fav =
        await ref.read(storageServiceProvider).isFavorite(station.id);
    if (mounted) setState(() => _isFav = fav);
  }

  String _formatSleep(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(playerProvider);
    final station = ps.station;

    return Container(
      color: AppColors.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (station == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'لا يوجد شيء قيد التشغيل',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                children: [
                  // Logo with glow
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bg,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withAlpha(80),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildLogo(station.logoUrl, station.name),
                  ),
                  const SizedBox(height: 20),
                  // Name
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (station.tags != null && station.tags!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      station.tags!,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.muted),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // EQ bars
                  EqBars(
                      playing: ps.playing,
                      barCount: 5,
                      size: 'large'),
                  const SizedBox(height: 16),
                  // Sleep timer status
                  if (ps.sleepRemaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.teal.withAlpha(80)),
                      ),
                      child: Text(
                        'ينتهي في ${_formatSleep(ps.sleepRemaining!)}',
                        style: const TextStyle(
                            color: AppColors.teal, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Favorite
                      _IconBtn(
                        icon: (_isFav ?? false)
                            ? Icons.star
                            : Icons.star_border,
                        color: (_isFav ?? false)
                            ? AppColors.gold
                            : AppColors.muted,
                        onTap: () async {
                          final ss = ref.read(storageServiceProvider);
                          if (_isFav ?? false) {
                            await ss.removeFavorite(station.id);
                            setState(() => _isFav = false);
                          } else {
                            await ss.addFavorite(station);
                            setState(() => _isFav = true);
                          }
                          ref
                              .read(appProvider.notifier)
                              .refreshFavorites();
                        },
                      ),
                      // Sleep timer
                      _IconBtn(
                        icon: Icons.timer_outlined,
                        color: ps.sleepRemaining != null
                            ? AppColors.teal
                            : AppColors.muted,
                        onTap: () => _showSleepTimer(context, ref, ps),
                      ),
                      // Play/Pause big button
                      GestureDetector(
                        onTap: () =>
                            ref.read(playerProvider.notifier).togglePlayPause(),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold,
                          ),
                          child: ps.loading
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    color: AppColors.bg,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(
                                  ps.playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: AppColors.bg,
                                  size: 32,
                                ),
                        ),
                      ),
                      // Share
                      _IconBtn(
                        icon: Icons.share_outlined,
                        color: AppColors.muted,
                        onTap: () {},
                      ),
                      // Report broken
                      _IconBtn(
                        icon: Icons.block_outlined,
                        color: AppColors.muted,
                        onTap: () => _reportBroken(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo(String? logoUrl, String name) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.cover,
        errorWidget: (ctx, url, err) => _fallback(name),
        placeholder: (ctx, url) => _fallback(name),
      );
    }
    return _fallback(name);
  }

  Widget _fallback(String name) {
    final trimmed = name.trim();
    final char = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '♪';
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Text(
          char,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 42,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showSleepTimer(
      BuildContext context, WidgetRef ref, PlayerState ps) {
    showDialog(
      context: context,
      builder: (ctx) => _SleepTimerDialog(
        currentRemaining: ps.sleepRemaining,
        onSet: (d) {
          if (d == null) {
            ref.read(playerProvider.notifier).cancelSleepTimer();
          } else {
            ref.read(playerProvider.notifier).setSleepTimer(d);
          }
        },
      ),
    );
  }

  void _reportBroken(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم الإبلاغ عن المحطة المعطلة')),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _SleepTimerDialog extends StatelessWidget {
  final Duration? currentRemaining;
  final void Function(Duration?) onSet;

  const _SleepTimerDialog(
      {this.currentRemaining, required this.onSet});

  static const _options = [
    (15, '١٥ دقيقة'),
    (30, '٣٠ دقيقة'),
    (45, '٤٥ دقيقة'),
    (60, 'ساعة'),
    (90, 'ساعة ونصف'),
    (120, 'ساعتان'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text(
        'مؤقت النوم',
        style: TextStyle(color: AppColors.ink, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._options.map((opt) {
            final (minutes, label) = opt;
            return ListTile(
              title: Text(label,
                  style: const TextStyle(color: AppColors.ink)),
              onTap: () {
                onSet(Duration(minutes: minutes));
                Navigator.pop(context);
              },
            );
          }),
          if (currentRemaining != null)
            ListTile(
              leading: const Icon(Icons.cancel_outlined,
                  color: AppColors.danger),
              title: const Text('إلغاء المؤقت',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                onSet(null);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}
