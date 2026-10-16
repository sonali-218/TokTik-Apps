import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:toktok/presentation/filters/face_filter.dart';

/// Dibuja los filtros activos sobre UN rostro. El canvas debe estar ya en
/// las coordenadas de la imagen que procesó ML Kit (se escala una vez y
/// luego se usan directamente los píxeles de los landmarks).
///
/// Geometría común a todos los filtros, a partir de los dos ojos:
///   - centro de los ojos  → punto de referencia de la cara
///   - distancia entre ojos → tamaño (más cerca de la cámara = más grande)
///   - ángulo entre ojos    → inclinación de la cabeza
///   - "arriba" de la cara  → perpendicular a la línea de los ojos
void paintFaceFilters({
  required Canvas canvas,
  required Face face,
  required Set<FaceFilter> active,
  required FaceFilterImages images,
}) {
  if (active.isEmpty) return;

  Offset? point(FaceLandmarkType type) {
    final p = face.landmarks[type]?.position;
    return p == null ? null : Offset(p.x.toDouble(), p.y.toDouble());
  }

  final eyeA = point(FaceLandmarkType.leftEye);
  final eyeB = point(FaceLandmarkType.rightEye);
  // Sin los dos ojos (rostro de perfil o tapado) no hay referencia fiable.
  if (eyeA == null || eyeB == null) return;

  // ML Kit llama leftEye al ojo izquierdo DE LA PERSONA, que en la foto
  // aparece a la derecha. Se ordenan por X en la imagen para que el ángulo
  // quede entre -90° y 90° y los filtros no se dibujen de cabeza.
  final (left, right) = eyeA.dx <= eyeB.dx ? (eyeA, eyeB) : (eyeB, eyeA);
  final eyeCenter = (left + right) / 2;
  final eyeVector = right - left;
  final eyeDistance = eyeVector.distance;
  final angle = math.atan2(eyeVector.dy, eyeVector.dx);
  // Vector unitario hacia arriba de la cara (perpendicular a los ojos).
  final up = Offset(math.sin(angle), -math.cos(angle));

  // Orden fijo del enum (no el orden en que se tocaron).
  for (final filter in FaceFilter.values.where(active.contains)) {
    switch (filter) {
      case FaceFilter.glasses:
        _draw(canvas, images[filter.assets[0]], eyeCenter, angle,
            width: eyeDistance * 2.3);

      case FaceFilter.mustache:
        final mouthA = point(FaceLandmarkType.leftMouth);
        final mouthB = point(FaceLandmarkType.rightMouth);
        if (mouthA == null || mouthB == null) break;
        final mouthCenter = (mouthA + mouthB) / 2;
        final nose = point(FaceLandmarkType.noseBase);
        // Entre la base de la nariz y la boca; si no hay nariz, se estima.
        final center = nose != null
            ? (nose + mouthCenter) / 2
            : mouthCenter + up * (eyeDistance * 0.2);
        _draw(canvas, images[filter.assets[0]], center, angle,
            width: (mouthB - mouthA).distance * 1.7);

      case FaceFilter.partyHat:
        // La base del sombrero (borde inferior del PNG) sobre la frente.
        _draw(canvas, images[filter.assets[0]],
            eyeCenter + up * (eyeDistance * 1.25), angle,
            width: eyeDistance * 1.8, anchorY: 1.0);

      case FaceFilter.crown:
        _draw(canvas, images[filter.assets[0]],
            eyeCenter + up * (eyeDistance * 1.15), angle,
            width: eyeDistance * 2.3, anchorY: 1.0);

      case FaceFilter.dog:
        _draw(canvas, images[filter.assets[0]],
            eyeCenter + up * (eyeDistance * 1.0), angle,
            width: eyeDistance * 3.2, anchorY: 1.0);
        final nose = point(FaceLandmarkType.noseBase);
        final noseCenter = nose ?? eyeCenter - up * (eyeDistance * 0.8);
        _draw(canvas, images[filter.assets[1]], noseCenter, angle,
            width: eyeDistance * 0.75);

      case FaceFilter.pumpkin:
        // Cubre toda la cara: centrada un poco debajo de los ojos y con el
        // ancho del rostro detectado (boundingBox).
        final faceWidth = math.max(face.boundingBox.width, eyeDistance * 2.4);
        _draw(canvas, images[filter.assets[0]],
            eyeCenter - up * (eyeDistance * 0.35), angle,
            width: faceWidth * 1.35);
    }
  }
}

/// Dibuja [overlay] rotado [angle] y escalado a [width] píxeles de ancho.
/// [anchorX]/[anchorY] indican qué punto del PNG cae en [position]
/// (0.5/0.5 = su centro; 0.5/1.0 = el centro de su borde inferior).
void _draw(
  Canvas canvas,
  ui.Image? overlay,
  Offset position,
  double angle, {
  required double width,
  double anchorX = 0.5,
  double anchorY = 0.5,
}) {
  if (overlay == null || width <= 0) return;
  final scale = width / overlay.width;
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(angle);
  canvas.scale(scale);
  canvas.drawImage(
    overlay,
    Offset(-overlay.width * anchorX, -overlay.height * anchorY),
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
}

/// Pinta una foto completa con los filtros encima (pantalla de edición).
class PhotoFiltersPainter extends CustomPainter {
  final ui.Image photo;
  final List<Face> faces;
  final Set<FaceFilter> active;
  final FaceFilterImages images;

  PhotoFiltersPainter({
    required this.photo,
    required this.faces,
    required this.active,
    required this.images,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / photo.width, size.height / photo.height);
    paintPhotoWithFilters(canvas, photo, faces, active, images);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PhotoFiltersPainter old) =>
      old.photo != photo ||
      old.faces != faces ||
      !setEquals(old.active, active) ||
      old.images != images;
}

/// La foto + los filtros, en coordenadas de la foto. La usan el painter de
/// la pantalla y el render final que se sube a Firebase, así lo que se ve
/// es exactamente lo que se publica.
void paintPhotoWithFilters(
  Canvas canvas,
  ui.Image photo,
  List<Face> faces,
  Set<FaceFilter> active,
  FaceFilterImages images,
) {
  canvas.drawImage(photo, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  for (final face in faces) {
    paintFaceFilters(canvas: canvas, face: face, active: active, images: images);
  }
}

/// Pinta solo los filtros encima del CameraPreview (filtros en vivo).
class LiveFiltersPainter extends CustomPainter {
  final List<Face> faces;
  final Size frameSize;
  final bool mirror;
  final Set<FaceFilter> active;
  final FaceFilterImages images;

  LiveFiltersPainter({
    required this.faces,
    required this.frameSize,
    required this.mirror,
    required this.active,
    required this.images,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // La cámara frontal se ve como espejo, pero ML Kit entrega coordenadas
    // sin espejar: se refleja el canvas en X para que coincidan.
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(size.width / frameSize.width, size.height / frameSize.height);
    for (final face in faces) {
      paintFaceFilters(canvas: canvas, face: face, active: active, images: images);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiveFiltersPainter old) =>
      old.faces != faces ||
      old.frameSize != frameSize ||
      old.mirror != mirror ||
      !setEquals(old.active, active) ||
      old.images != images;
}
