import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// Los filtros faciales disponibles. Cada uno es un PNG con fondo
/// transparente que se coloca sobre la cara usando los landmarks de
/// ML Kit (ver face_filter_painter.dart).
/// El orden importa: es el orden en que se dibujan (la calabaza va primero
/// para quedar debajo de lentes, bigote, sombreros, etc.).
enum FaceFilter {
  pumpkin('Calabaza', '🎃', ['assets/filtros/pumpkin.png']),
  glasses('Lentes', '🕶️', ['assets/filtros/glasses.png']),
  mustache('Bigote', '🥸', ['assets/filtros/bigote.png']),
  partyHat('Fiesta', '🥳', ['assets/filtros/party_hat.png']),
  crown('Corona', '👑', ['assets/filtros/crown.png']),
  dog('Perrito', '🐶', ['assets/filtros/dog_ears.png', 'assets/filtros/dog_nose.png']);

  final String label;
  final String emoji;
  final List<String> assets;

  const FaceFilter(this.label, this.emoji, this.assets);
}

/// Imágenes de los filtros ya decodificadas (lo que necesita
/// Canvas.drawImage), indexadas por ruta del asset.
class FaceFilterImages {
  final Map<String, ui.Image> _images;

  FaceFilterImages._(this._images);

  ui.Image? operator [](String asset) => _images[asset];

  /// Carga todos los PNG una sola vez.
  static Future<FaceFilterImages> load() async {
    final images = <String, ui.Image>{};
    for (final filter in FaceFilter.values) {
      for (final asset in filter.assets) {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        images[asset] = (await codec.getNextFrame()).image;
      }
    }
    return FaceFilterImages._(images);
  }
}
