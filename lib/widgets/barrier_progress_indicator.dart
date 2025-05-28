import 'package:flutter/material.dart';

class BarrierProgressIndicator extends StatelessWidget {
  const BarrierProgressIndicator({
    super.key,
    required this.isActive,
    this.barrierOpacity = 0.65,
    this.progressColor = Colors.white,
    this.message,
    required this.child,
  });

  final bool isActive;
  final double barrierOpacity;
  final Color progressColor;
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !isActive,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: isActive ? 1.0 : 0.0,
              curve: Curves.fastOutSlowIn,
              child: Container(
                color: Colors.black.withOpacity(barrierOpacity),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (message?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 90),
                      ],
                      CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                      if (message?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 40),
                        Text(
                          message ?? "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
