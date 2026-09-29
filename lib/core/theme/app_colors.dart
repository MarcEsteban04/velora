import 'package:flutter/material.dart';

/// Which scene Velora is painted in, in the order of a day.
enum Scene { day, afternoon, night }

/// One complete set of colour tokens. [night] is the Himalayan dusk, [day]
/// the same valley in sunshine, and [afternoon] its golden hour: a low sun,
/// peach sky and sunlit peaks.
///
/// The brand colours come from the mascot: leaf green from the cap and tee,
/// rust and cream from the red panda's fur. In the light scenes accents are
/// a shade deeper so they keep their contrast on light surfaces.
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

  /// The moon at night, the sun by day and in the afternoon.
  final Color moon;
  final Color leaf, leafBright, leafShadow, rust, ember, sky, lilac;
  final Color surface, surfaceRaised;
  final Color textPrimary, textSecondary, textMuted;

  /// Day and Afternoon: light surfaces and dark text.
  bool get isLight => scene != Scene.night;

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

  static const afternoonPalette = Palette(
    scene: Scene.afternoon,
    skyZenith: Color(0xFF7FA3D6),
    skyIndigo: Color(0xFFB4B6DC),
    skyPlum: Color(0xFFF1C3B0),
    skyRose: Color(0xFFFBC48E),
    skyAmber: Color(0xFFFFD27A),
    ridgeFarTop: Color(0xFFE2AE98),
    ridgeFarBase: Color(0xFFC08E8C),
    ridgeMidTop: Color(0xFFB3A873),
    ridgeMidBase: Color(0xFF86895B),
    ridgeNear: Color(0xFF5A6E45),
    night: Color(0xFFF8ECDF),
    mist: Color(0xFFFFE6CC),
    moon: Color(0xFFFFBE5C),
    leaf: Color(0xFF3E9E57),
    leafBright: Color(0xFF2E8A47),
    leafShadow: Color(0xFF256E39),
    rust: Color(0xFFB8471A),
    ember: Color(0xFFC7641A),
    sky: Color(0xFF2F66C4),
    lilac: Color(0xFF7050CC),
    surface: Color(0xFFFFFBF6),
    surfaceRaised: Color(0xFFF5E7D8),
    textPrimary: Color(0xFF2A211B),
    textSecondary: Color(0xFF55483E),
    textMuted: Color(0xFF8A7A6C),
  );

  static Palette of(Scene scene) => switch (scene) {
    Scene.day => dayPalette,
    Scene.afternoon => afternoonPalette,
    Scene.night => nightPalette,
  };
}

/// The theme colour the user picks in Settings: buttons, tabs, selections
/// and highlights. Each has shades for the night scene and deeper ones for
/// Day and Afternoon, so it keeps its contrast on light surfaces. Money
/// coming in, paid and on-track states stay green whatever the accent.
enum AppAccent {
  leaf(
    'Leaf',
    'Velora’s own green',
    night: (Color(0xFF58A765), Color(0xFF6CBF78), Color(0xFF34703F)),
    light: (Color(0xFF3E9E57), Color(0xFF2E8A47), Color(0xFF256E39)),
  ),
  sky(
    'Sky',
    'Clear evening blue',
    night: (Color(0xFF4F86E8), Color(0xFF7DA8FF), Color(0xFF2C4F9E)),
    light: (Color(0xFF3D7BE0), Color(0xFF2F66C4), Color(0xFF234C94)),
  ),
  lilac(
    'Lilac',
    'Soft dusk violet',
    night: (Color(0xFF8F6FE0), Color(0xFFB39BFF), Color(0xFF553C9A)),
    light: (Color(0xFF7E5CD8), Color(0xFF6A48C8), Color(0xFF4E3396)),
  ),
  rose(
    'Rose',
    'Warm blossom pink',
    night: (Color(0xFFD65C8C), Color(0xFFF27BA6), Color(0xFF8E2F57)),
    light: (Color(0xFFD2507F), Color(0xFFBC3F6C), Color(0xFF8C2C50)),
  ),
  ember(
    'Ember',
    'Red panda orange',
    night: (Color(0xFFE0873F), Color(0xFFF5A25E), Color(0xFF9A5220)),
    light: (Color(0xFFD5762A), Color(0xFFC0621A), Color(0xFF8E4612)),
  ),
  teal(
    'Teal',
    'Cool mountain lake',
    night: (Color(0xFF2FA8A2), Color(0xFF4FCBC4), Color(0xFF1B6763)),
    light: (Color(0xFF23968F), Color(0xFF1B827C), Color(0xFF136058)),
  );

  const AppAccent(
    this.label,
    this.description, {
    required this.night,
    required this.light,
  });

  final String label;
  final String description;

  /// (base, bright, shadow) in the night scene.
  final (Color, Color, Color) night;

  /// (base, bright, shadow) in Day and Afternoon.
  final (Color, Color, Color) light;

  (Color, Color, Color) get _shades => AppColors.isLight ? light : night;

  /// The swatch shown in Settings: the bright shade for the current scene.
  Color get swatch => _shades.$2;

  /// The button face and lip, for previews.
  Color get base => _shades.$1;
  Color get shadow => _shades.$3;
}

/// Velora's colour tokens, resolved against the active [Palette].
///
/// Screens reference `AppColors.x`, and the app root switches [palette]
/// when the appearance changes, so every screen follows without knowing
/// which scene is showing. Keep raw hex values in [Palette], nowhere else.
abstract final class AppColors {
  static Palette palette = Palette.nightPalette;

  /// The user's theme colour; the app root sets it from Settings.
  static AppAccent accentChoice = AppAccent.leaf;

  static Scene get scene => palette.scene;

  /// Day and Afternoon: light surfaces and dark text.
  static bool get isLight => palette.isLight;

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

  /// The theme colour, for anything brand or interactive. Use [leaf] only
  /// where green means something: money in, paid, on track.
  static Color get accent => accentChoice.base;
  static Color get accentBright => accentChoice.swatch;
  static Color get accentShadow => accentChoice.shadow;
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

  /// Hairline borders: light lines at night, dark lines in the light scenes.
  static Color hairline([double alpha = 0.08]) =>
      (isLight ? Colors.black : Colors.white).withValues(alpha: alpha);
}
