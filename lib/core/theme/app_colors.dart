import 'package:flutter/material.dart';

/// Which scene Velora is painted in.
enum Scene { night, day }

/// One complete set of colour tokens. [night] is the Himalayan dusk;
/// [day] is the same valley in sunshine.
///
/// The brand colours come from the mascot: leaf green from the cap and tee,
/// rust and cream from the red panda's fur. In Day, accents are a shade
/// deeper so they keep their contrast on light surfaces.
class Palette {
  const Palette({
    required this.scene,
    required this.skyZenith,
    required this.skyIndigo,
    required this.skyPlum,
    required this.skyRose,
    required this.skyAmber,
    required this.ridgeFarTop,
    required this.ridgeFarBase,
    required this.ridgeMidTop,
    required this.ridgeMidBase,
    required this.ridgeNear,
    required this.night,
    required this.mist,
    required this.moon,
    required this.leaf,
    required this.leafBright,
    required this.leafShadow,
    required this.rust,
    required this.ember,
    required this.sky,
    required this.lilac,
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Scene scene;
  final Color skyZenith, skyIndigo, skyPlum, skyRose, skyAmber;
  final Color ridgeFarTop, ridgeFarBase, ridgeMidTop, ridgeMidBase, ridgeNear;

  /// The page's base colour, and the tint of scrims over the scene.
  final Color night;
  final Color mist;

  /// The moon at night, the sun by day.
  final Color moon;
  final Color leaf, leafBright, leafShadow, rust, ember, sky, lilac;
  final Color surface, surfaceRaised;
  final Color textPrimary, textSecondary, textMuted;

  bool get isDay => scene == Scene.day;

  static const nightPalette = Palette(
    scene: Scene.night,
    skyZenith: Color(0xFF0B0D2A),
    skyIndigo: Color(0xFF1D1A4A),
    skyPlum: Color(0xFF4B2B62),
    skyRose: Color(0xFFA2485E),
    skyAmber: Color(0xFFF09A5A),
    ridgeFarTop: Color(0xFF7A4F7A),
    ridgeFarBase: Color(0xFF3A2A58),
    ridgeMidTop: Color(0xFF3A2856),
    ridgeMidBase: Color(0xFF221A40),
    ridgeNear: Color(0xFF16102A),
    night: Color(0xFF0A0818),
    mist: Color(0xFFD9C6E8),
    moon: Color(0xFFFFF4E0),
    leaf: Color(0xFF58A765),
    leafBright: Color(0xFF6CBF78),
    leafShadow: Color(0xFF34703F),
    rust: Color(0xFFD2682E),
    ember: Color(0xFFF0A15E),
    sky: Color(0xFF8AB4FF),
    lilac: Color(0xFFB79CFF),
    surface: Color(0xFF15122B),
    surfaceRaised: Color(0xFF1F1B3A),
    textPrimary: Color(0xFFFBF7F1),
    textSecondary: Color(0xFFD8D1E4),
    textMuted: Color(0xFF9D95B3),
  );

  static const dayPalette = Palette(
    scene: Scene.day,
    skyZenith: Color(0xFF5FB2EE),
    skyIndigo: Color(0xFF8CCBF4),
    skyPlum: Color(0xFFC3E6F8),
    skyRose: Color(0xFFFBE2CB),
    skyAmber: Color(0xFFFFD49A),
    ridgeFarTop: Color(0xFFB9D3E3),
    ridgeFarBase: Color(0xFF9DBFD2),
    ridgeMidTop: Color(0xFF9CC6A6),
    ridgeMidBase: Color(0xFF79AA86),
    ridgeNear: Color(0xFF4F8563),
    night: Color(0xFFF6F1E8),
    mist: Color(0xFFFFFFFF),
    moon: Color(0xFFFFE08A),
    leaf: Color(0xFF3E9E57),
    leafBright: Color(0xFF2E8A47),
    leafShadow: Color(0xFF256E39),
    rust: Color(0xFFC0501F),
    ember: Color(0xFFD1701F),
    sky: Color(0xFF2F6FD6),
    lilac: Color(0xFF7355D6),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1ECE4),
    textPrimary: Color(0xFF1C2630),
    textSecondary: Color(0xFF46505C),
    textMuted: Color(0xFF7A838F),
  );
}

/// Velora's colour tokens, resolved against the active [Palette].
///
/// Screens reference `AppColors.x`, and the app root switches [palette]
/// when the appearance changes, so every screen follows without knowing
/// which scene is showing. Keep raw hex values in [Palette], nowhere else.
abstract final class AppColors {
  static Palette palette = Palette.nightPalette;

  static bool get isDay => palette.isDay;

  static Color get skyZenith => palette.skyZenith;
  static Color get skyIndigo => palette.skyIndigo;
  static Color get skyPlum => palette.skyPlum;
  static Color get skyRose => palette.skyRose;
  static Color get skyAmber => palette.skyAmber;
  static Color get ridgeFarTop => palette.ridgeFarTop;
  static Color get ridgeFarBase => palette.ridgeFarBase;
  static Color get ridgeMidTop => palette.ridgeMidTop;
  static Color get ridgeMidBase => palette.ridgeMidBase;
  static Color get ridgeNear => palette.ridgeNear;
  static Color get night => palette.night;
  static Color get mist => palette.mist;
  static Color get moon => palette.moon;
  static Color get leaf => palette.leaf;
  static Color get leafBright => palette.leafBright;
  static Color get leafShadow => palette.leafShadow;
  static Color get rust => palette.rust;
  static Color get ember => palette.ember;
  static Color get sky => palette.sky;
  static Color get lilac => palette.lilac;
  static Color get surface => palette.surface;
  static Color get surfaceRaised => palette.surfaceRaised;
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;

  // The same in both scenes.
  static const cream = Color(0xFFFBF1E4);
  static const textOnLight = Color(0xFF1B2A20);

  /// Text and icons on brand-coloured fills (account cards, green buttons)
  /// stay white in both scenes.
  static const onBrand = Color(0xFFFFFFFF);

  /// Hairline borders: light lines at night, dark lines by day.
  static Color hairline([double alpha = 0.08]) =>
      (isDay ? Colors.black : Colors.white).withValues(alpha: alpha);
}
