import 'package:flutter/material.dart';

class AppResponsive {
  AppResponsive._();

  static const double desktopBreakpoint = 900;
  static const double pageMaxWidth = double.infinity;
  static const double modalMaxWidth = 720;

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.zero;
  }

  static BoxConstraints modalConstraints(BuildContext context) {
    if (!isDesktop(context)) {
      return const BoxConstraints();
    }

    return const BoxConstraints(maxWidth: modalMaxWidth);
  }
}

class AppResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppResponsive.pageMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!AppResponsive.isDesktop(context)) {
      return child;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final content = SizedBox(
        height: constraints.maxHeight,
        child: child,
      );

      return Padding(
        padding: AppResponsive.pagePadding(context),
        child: maxWidth.isFinite
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: content,
                ),
              )
            : content,
      );
    });
  }
}
