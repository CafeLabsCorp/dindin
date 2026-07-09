import 'package:flutter/material.dart';

/// Lays out form fields side by side (each at its given [width]) when there's
/// room, matching the desktop/web layout. When the available width can't fit
/// them comfortably, stacks them full-width instead — so on phones every
/// field is the same width rather than wrapping into a ragged mix of sizes.
class ResponsiveFormRow extends StatelessWidget {
  final List<({double width, Widget child})> fields;
  final double spacing;

  const ResponsiveFormRow({super.key, required this.fields, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = fields.fold<double>(0, (sum, f) => sum + f.width) + spacing * (fields.length - 1);
        if (constraints.maxWidth < totalWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                fields[i].child,
              ],
            ],
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final f in fields) SizedBox(width: f.width, child: f.child)],
        );
      },
    );
  }
}
