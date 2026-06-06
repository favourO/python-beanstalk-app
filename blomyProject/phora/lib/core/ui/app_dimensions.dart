import 'dart:math' as math;

import 'package:flutter/widgets.dart';

@immutable
class AppDimensions {
  const AppDimensions._(this.size);

  factory AppDimensions.of(BuildContext context) {
    return AppDimensions._(MediaQuery.sizeOf(context));
  }

  final Size size;

  double get width => size.width;
  double get height => size.height;

  double scaleWidth(double value, {double min = 0.85, double max = 1.2}) {
    final factor = (width / 430).clamp(min, max);
    return value * factor;
  }

  double scaleHeight(double value, {double min = 0.85, double max = 1.2}) {
    final factor = (height / 932).clamp(min, max);
    return value * factor;
  }

  double scaleText(double value, {double min = 0.9, double max = 1.12}) {
    final shortestSide = math.min(width, height);
    final factor = (shortestSide / 430).clamp(min, max);
    return value * factor;
  }

  double scaleRadius(double value) {
    return scaleWidth(value, min: 0.9, max: 1.1);
  }

  double scaleSpace(double value) {
    return scaleHeight(value, min: 0.88, max: 1.14);
  }
}

extension AppDimensionsX on BuildContext {
  AppDimensions get dims => AppDimensions.of(this);
}
