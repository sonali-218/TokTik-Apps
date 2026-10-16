import 'dart:io' show Directory, File, Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toktok/presentation/filters/face_filter.dart';
import 'package:toktok/presentation/filters/face_filter_painter.dart';
import 'package:toktok/presentation/filters/filter_selector.dart';
import 'package:toktok/presentation/widgets/shared/top_toast.dart';

/// Aplica filtros faciales a una foto antes de publicarla.
///
/// Flujo (el mismo patrón de ML Kit de la Clase 24):
///   archivo → InputImage.fromFile → FaceDetector → landmarks → filtros.
/// Al tocar "Usar foto" se "aplana" la foto + filtros en un PNG nuevo
/// y se devuelve a la pantalla de subida con Navigator.pop.
class FaceFilterEditorScreen extends StatefulWidget {
  final XFile photo;
  final Set<FaceFilter> initialFilters;

  const FaceFilterEditorScreen({
    super.key,
    required this.photo,
    this.initialFilters = const {FaceFilter.glasses},
  });

  @override
  State<FaceFilterEditorScreen> createState() => _FaceFilterEditorScreenState();
}

class _FaceFilterEditorScreenState extends State<FaceFilterEditorScreen> {
  // Un solo detector, creado en initState y cerrado en dispose().
  late final FaceDetector _detector;

  ui.Image? _photo;
  FaceFilterImages? _images;
  List<Face> _faces = [];
  late Set<FaceFilter> _active;

  bool _detecting = true;
  bool _saving = false;
  String _status = 'Detectando rostros…';

  @override
  void initState() {
    super.initState();
    _active = {...widget.initialFilters};
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _detector.close();
    super.dispose();
  }

  /// Lado máximo de la foto que se analiza, se muestra y se publica.
  static const _maxSide = 1600;

  Future<void> _load() async {
    try {
      final photo = await _decodeUpright(widget.photo);
      final images = await FaceFilterImages.load();
      final faces = await _detector.processImage(await _toInputImage(photo));
      if (!mounted) return;

      final complete = faces
          .where((f) =>
              f.landmarks[FaceLandmarkType.leftEye] != null &&
              f.landmarks[FaceLandmarkType.rightEye] != null)
          .length;
      setState(() {
        _photo = photo;
        _images = images;
        _faces = faces;
        _detecting = false;
        _status = faces.isEmpty
            ? 'No se detectó ningún rostro. Prueba con una foto de frente y con buena luz.'
            : complete < faces.length
                ? '${faces.length} rostro(s); ${faces.length - complete} de perfil o tapado(s), ahí no se dibuja el filtro.'
                : '${faces.length} rostro(s) detectado(s). Elige uno o varios filtros.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _status = 'No se pudo procesar la foto: $e';
      });
    }
  }

  /// Decodifica la foto (Flutter ya aplica la orientación EXIF, así que
  /// queda "derecha") y la reduce si es muy grande.
  Future<ui.Image> _decodeUpright(XFile file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final full = (await codec.getNextFrame()).image;
    final scale = _maxSide / math.max(full.width, full.height);
    if (scale >= 1) return full;

    final w = (full.width * scale).round();
    final h = (full.height * scale).round();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      full,
      Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final scaled = await recorder.endRecording().toImage(w, h);
    full.dispose();
    return scaled;
  }

  /// Le pasa a ML Kit EXACTAMENTE la misma imagen que se muestra, para que
  /// las coordenadas de los landmarks coincidan.
  ///   - iOS: píxeles crudos BGRA (el mismo camino que usa la cámara en
  ///     vivo). Con la ruta del archivo, iOS puede entregar la foto
  ///     "acostada" (orientación EXIF) y ML Kit no encuentra la cara.
  ///   - Android: fromBytes solo acepta NV21/YV12, así que se guarda la foto
  ///     ya derecha en un PNG temporal y se usa su ruta.
  Future<InputImage> _toInputImage(ui.Image image) async {
    if (Platform.isIOS) {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw Exception('No se pudo leer la imagen.');
      final bgra = Uint8List.fromList(data.buffer.asUint8List());
      for (var i = 0; i < bgra.length; i += 4) {
        final r = bgra[i];
        bgra[i] = bgra[i + 2]; // B
        bgra[i + 2] = r; // R
      }
      return InputImage.fromBytes(
        bytes: bgra,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.width * 4,
        ),
      );
    }

    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw Exception('No se pudo leer la imagen.');
    final dir = await Directory.systemTemp.createTemp('toktik_detect_');
    final file = File('${dir.path}/detect.png');
    await file.writeAsBytes(png.buffer.asUint8List());
    return InputImage.fromFilePath(file.path);
  }

  void _toggle(FaceFilter filter) {
    setState(() {
      if (!_active.remove(filter)) _active.add(filter);
    });
  }

  /// Dibuja foto + filtros a tamaño real en un PNG temporal.
  Future<void> _useResult() async {
    final photo = _photo;
    final images = _images;
    if (photo == null || images == null) return;

    setState(() => _saving = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintPhotoWithFilters(canvas, photo, _faces, _active, images);
      final rendered =
          await recorder.endRecording().toImage(photo.width, photo.height);
      final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw Exception('No se pudo generar la imagen.');

      final dir = await Directory.systemTemp.createTemp('toktik_');
      final name = 'filtro_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(png.buffer.asUint8List());

      if (!mounted) return;
      Navigator.of(context).pop(XFile(file.path, name: name, mimeType: 'image/png'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopToast(context, 'Error al aplicar filtros: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final images = _images;

    return Scaffold(
      appBar: AppBar(title: const Text('Filtros faciales')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: photo == null || images == null
                  ? (_detecting
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_status, textAlign: TextAlign.center),
                        ))
                  : AspectRatio(
                      aspectRatio: photo.width / photo.height,
                      child: CustomPaint(
                        painter: PhotoFiltersPainter(
                          photo: photo,
                          faces: _faces,
                          active: {..._active},
                          images: images,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(_status, textAlign: TextAlign.center),
          ),
          FilterSelector(active: _active, onToggle: _toggle),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _detecting || _saving || photo == null ? null : _useResult,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Usar esta foto'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
