// budgetly/lib/widgets/scalable_text.dart
import 'package:flutter/material.dart';

/// A text widget that automatically scales down to fit within its constraints
/// Useful for preventing overflow errors with large accessibility font sizes
class ScalableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool enableScaling;

  const ScalableText(
      this.text, {
        super.key,
        this.style,
        this.textAlign,
        this.maxLines,
        this.overflow,
        this.enableScaling = true,
      });

  @override
  Widget build(BuildContext context) {
    if (!enableScaling) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: _getAlignment(),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }

  Alignment _getAlignment() {
    switch (textAlign) {
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }
}

/// A currency text widget that handles scaling for monetary values
class CurrencyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showSign;
  final bool isExpense;
  final int decimalPlaces;

  const CurrencyText(
      this.amount, {
        super.key,
        this.style,
        this.showSign = false,
        this.isExpense = true,
        this.decimalPlaces = 2,
      });

  @override
  Widget build(BuildContext context) {
    final sign = showSign
        ? (isExpense ? '-' : '+')
        : '';

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '$sign\$${amount.abs().toStringAsFixed(decimalPlaces)}',
        style: style,
      ),
    );
  }
}

/// A widget that ensures its child takes up appropriate space even with large fonts
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Decoration? decoration;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      color: color,
      decoration: decoration,
      width: width,
      height: height,
      alignment: alignment,
      child: child,
    );
  }
}

/// Row that handles overflow by wrapping children when needed
class AdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;
  final double runSpacing;

  const AdaptiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we have plenty of space, use a regular Row
        if (constraints.maxWidth > 400) {
          return Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: _addSpacing(children, spacing),
          );
        }

        // Otherwise, wrap to handle overflow
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: _wrapAlignment(mainAxisAlignment),
          crossAxisAlignment: _wrapCrossAlignment(crossAxisAlignment),
          children: children,
        );
      },
    );
  }

  List<Widget> _addSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) return widgets;

    final List<Widget> spacedChildren = [];
    for (int i = 0; i < widgets.length; i++) {
      spacedChildren.add(widgets[i]);
      if (i < widgets.length - 1) {
        spacedChildren.add(SizedBox(width: spacing));
      }
    }
    return spacedChildren;
  }

  WrapAlignment _wrapAlignment(MainAxisAlignment mainAxisAlignment) {
    switch (mainAxisAlignment) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.end:
        return WrapAlignment.end;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return WrapAlignment.spaceEvenly;
    }
  }

  WrapCrossAlignment _wrapCrossAlignment(CrossAxisAlignment crossAxisAlignment) {
    switch (crossAxisAlignment) {
      case CrossAxisAlignment.start:
        return WrapCrossAlignment.start;
      case CrossAxisAlignment.end:
        return WrapCrossAlignment.end;
      case CrossAxisAlignment.center:
        return WrapCrossAlignment.center;
      case CrossAxisAlignment.stretch:
      case CrossAxisAlignment.baseline:
        return WrapCrossAlignment.center;
    }
  }
}