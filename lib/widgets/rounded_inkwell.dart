import 'package:flutter/material.dart';

class RoundedInkWell extends StatelessWidget {
  const RoundedInkWell({
    super.key,
    this.child,
    this.onTap,
    this.shadow,
    this.padding,
    this.margin,
    this.color = Colors.white,
    this.decoration,
    this.borderRadius = 15.0,
  });

  final Color color;
  final BoxDecoration? decoration;
  final double borderRadius;
  final BoxShadow? shadow;
  final Widget? child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  Color? get _color {
    if (decoration?.color != null) {
      return decoration!.color;
    }
    return color;
  }

  BorderRadius get _borderRadius {
    if (decoration?.borderRadius != null) {
      return decoration!.borderRadius!.resolve(TextDirection.ltr);
    }
    return BorderRadius.circular(borderRadius);
  }

  List<BoxShadow> get _shadow {
    if (decoration?.boxShadow?.isNotEmpty ?? false) {
      return decoration!.boxShadow!;
    }
    if (shadow != null) {
      return [shadow!];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _borderRadius,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          boxShadow: _shadow,
          gradient: decoration?.gradient,
          border: decoration?.border,
          borderRadius: decoration?.borderRadius,
        ),
        child: Card(
          color: _color,
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: _borderRadius,
          ),
          child: InkWell(
            borderRadius: _borderRadius,
            onTap: onTap ?? () {},
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child ?? Container(),
            ),
          ),
        ),
      ),
    );
  }
}
