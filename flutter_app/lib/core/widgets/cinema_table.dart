import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

class CinemaTableColumn<T> {
  final String label;
  final Widget Function(T row) cellBuilder;
  final double? width;
  final bool numeric;

  const CinemaTableColumn({
    required this.label,
    required this.cellBuilder,
    this.width,
    this.numeric = false,
  });
}

/// Cinema-Tabelle: Mono-Header (uppercase), alternierende Rows, Hover-Highlight.
/// Fuer Admin und kleinere Listen — fuer grosse Datenmengen LazyDataTable bauen.
class CinemaTable<T> extends StatelessWidget {
  final List<CinemaTableColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;

  const CinemaTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MnColors.line),
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        child: Column(
          children: [
            // Header
            Container(
              color: MnColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  for (final c in columns)
                    SizedBox(
                      width: c.width,
                      child: Text(
                        c.label.toUpperCase(),
                        style: MnTypography.mono(
                          size: 11,
                          color: MnColors.mute,
                          letterSpacing: 1.5,
                        ),
                        textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                ],
              ),
            ),
            // Rows
            for (int i = 0; i < rows.length; i++)
              InkWell(
                onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
                child: Container(
                  color: i.isEven ? MnColors.elevated : MnColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: MnColors.line,
                        width: i == rows.length - 1 ? 0 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (final c in columns)
                        SizedBox(width: c.width, child: c.cellBuilder(rows[i])),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
