import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// The web app's theme pin colors: --color-primary in web/src/app.css, with
// the light/dark variants App.svelte derives as ±16 HSL lightness.
const _defaultPin = Color(0xFF10A15A);

// Logical sizes from .pin / .pin-shape in web/src/lib/Map.svelte: a 20px
// teardrop with a 2px white border, a 3px halo and a 0 2px 6px shadow.
const _innerRadius = 10.0;
const _borderWidth = 2.0;
const _haloWidth = 3.0;
const _outerRadius = _innerRadius + _borderWidth;
// Room for the tip, halo and shadow on every side of the circle's center,
// which is the image's center — the web marker is anchored at its center
// too, so the coordinate sits in the round part rather than at the tip.
const _halfExtent = 28.0;

/// The pin's style-image name for [color] (null means the theme default).
String pinImageName(Color? color) => color == null
    ? 'pin-default'
    : 'pin-${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// Renders the web app's teardrop pin as PNG bytes, at [pixelRatio] physical
/// pixels per logical pixel. MapLibre Android treats added images as being at
/// the screen's density, so passing the device pixel ratio keeps the pin at
/// its web size.
Future<Uint8List> renderPinImage(Color? color, double pixelRatio) async {
  final Color base;
  final Color light;
  final Color dark;
  if (color == null) {
    base = _defaultPin;
    light = _adjustLightness(_defaultPin, 0.16);
    dark = _adjustLightness(_defaultPin, -0.16);
  } else {
    // applyPinColor in Map.svelte: color-mix with 30% white / 25% black.
    base = color;
    light = Color.lerp(color, const Color(0xFFFFFFFF), 0.30)!;
    dark = Color.lerp(color, const Color(0xFF000000), 0.25)!;
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(pixelRatio)
    ..translate(_halfExtent, _halfExtent);

  final outer = _teardrop(_outerRadius);
  final inner = _teardrop(_innerRadius);

  // box-shadow: 0 2px 6px rgba(0,0,0,0.35)
  canvas.drawPath(
    outer.shift(const Offset(0, 2)),
    Paint()
      ..color = const Color(0x59000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  // box-shadow: 0 0 0 3px color-mix(pin 18%, transparent)
  canvas.drawPath(
    outer,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _haloWidth * 2
      ..color = base.withValues(alpha: 0.18),
  );
  // border: 2px solid white
  canvas.drawPath(outer, Paint()..color = const Color(0xFFFFFFFF));
  // linear-gradient(135deg, light, dark) on the element before its -45°
  // rotation, which works out to left-to-right on screen.
  canvas.drawPath(
    inner,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(-_innerRadius, 0),
        const Offset(_innerRadius, 0),
        [light, dark],
      ),
  );

  final size = (_halfExtent * 2 * pixelRatio).ceil();
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// A circle of [radius] around the origin with a point straight below it —
/// a square with `border-radius: 50% 50% 50% 0` rotated -45°.
Path _teardrop(double radius) {
  final tip = Offset(0, radius * math.sqrt2);
  return Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(radius * math.cos(math.pi / 4), radius * math.sin(math.pi / 4))
    // Clockwise is positive with y pointing down, so this sweeps back over
    // the top from the right-hand tangent point to the left-hand one.
    ..arcTo(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      math.pi / 4,
      -1.5 * math.pi,
      false,
    )
    ..close();
}

Color _adjustLightness(Color color, double delta) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}
