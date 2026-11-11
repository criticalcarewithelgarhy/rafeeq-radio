import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class CategoryBar extends ConsumerWidget {
  const CategoryBar({super.key});

  static const _categories = [
    ('favorites', '★ المفضلة'),
    ('recent', '🕐 سمعتها'),
    ('quran', '☽ القرآن'),
    ('topcharts', '🔥 الأكثر'),
    ('countries_ar', '🗺 عربي'),
    ('countries_world', '🌍 العالم'),
    ('news', '📰 أخبار'),
    ('sports', '⚽ رياضة'),
    ('genres', '🎵 أنواع'),
    ('search', '🔍 بحث'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(appProvider.select((s) => s.categoryId));

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final (id, label) = _categories[i];
          final selected = id == currentId;
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: GestureDetector(
              onTap: () =>
                  ref.read(appProvider.notifier).loadCategory(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.gold.withAlpha(26)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppColors.gold
                        : AppColors.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.gold : AppColors.muted,
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
