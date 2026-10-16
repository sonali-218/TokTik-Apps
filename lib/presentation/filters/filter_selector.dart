import 'package:flutter/material.dart';
import 'package:toktok/presentation/filters/face_filter.dart';

/// Fila deslizable de filtros; se pueden combinar varios a la vez.
class FilterSelector extends StatelessWidget {
  final Set<FaceFilter> active;
  final ValueChanged<FaceFilter> onToggle;

  const FilterSelector({super.key, required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: FaceFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final filter = FaceFilter.values[i];
          final selected = active.contains(filter);
          final color = Theme.of(context).colorScheme.primary;
          return GestureDetector(
            onTap: () => onToggle(filter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                    border: Border.all(
                      color: selected ? color : Colors.white24,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: Text(filter.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(height: 4),
                Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
