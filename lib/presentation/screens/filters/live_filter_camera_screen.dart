import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toktok/presentation/filters/face_filter.dart';
import 'package:toktok/presentation/filters/face_filter_painter.dart';
import 'package:toktok/presentation/filters/filter_selector.dart';
import 'package:toktok/presentation/widgets/shared/top_toast.dart';
import 'package:toktok/presentation/screens/filters/face_filter_editor_screen.dart';

/// Cámara con filtros en tiempo real (basada en la demo de la Clase 24).
/// Cada frame se convierte en InputImage y pasa por el FaceDetector; los
/// filtros se pintan encima del CameraPreview. Al tomar la foto se abre el
/// editor con los mismos filtros para ajustarlos y publicarla.
class LiveFilterCameraScreen extends StatefulWidget {
  const LiveFilterCameraScreen({super.key});

  @override
  State<LiveFilterCameraScreen> createState() => _LiveFilterCameraScreenState();
}

class _LiveFilterCameraScreenState extends State<LiveFilterCameraScreen> {
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  CameraController? _controller;

  FaceFilterImages? _images;
  final Set<FaceFilter> _active = {FaceFilter.glasses};

  List<Face> _faces = [];
  Size? _frameSize;
  bool _isProcessing = false;
  bool _capturing = false;
  String? _error;

  // En video conviene el modo "fast": importa más la latencia.
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    // Vertical fijo: la rotación del frame es siempre la del sensor.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    FaceFilterImages.load().then((images) {
      if (mounted) setState(() => _images = images);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los filtros: $e');
    });
    _initCameras();
  }

  @override
  void dispose() {
    _stopCamera();
    _detector.close();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _error =
              'Este dispositivo no tiene cámara (el simulador de iOS no tiene). '
              'Prueba en un iPhone real o en el emulador de Android.');
        }
        return;
      }
      final front =
          _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraIndex = front >= 0 ? front : 0;
      await _startCamera();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la cámara: $e');
    }
  }

  Future<void> _startCamera() async {
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      // ML Kit acepta NV21 en Android y BGRA8888 en iOS como bytes crudos.
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _controller = controller;
    await controller.initialize();
    if (!mounted) return;
    await controller.startImageStream(_processFrame);
    setState(() {});
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCamera();
    if (!mounted) return;
    setState(() {
      _faces = [];
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    try {
      await _startCamera();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la cámara: $e');
    }
  }

  /// Se llama por cada frame (~30 por segundo). Si ML Kit sigue ocupado
  /// con el anterior, el frame se descarta.
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    final input = _toInputImage(image);
    if (input == null) return;

    _isProcessing = true;
    try {
      final faces = await _detector.processImage(input);
      if (!mounted) return;
      final rotation = input.metadata!.rotation;
      // En Android el frame llega "acostado" y ML Kit responde en
      // coordenadas ya rotadas (se invierten ancho y alto). En iOS el
      // plugin de cámara ya entrega el frame vertical.
      final rotated = Platform.isAndroid &&
          (rotation == InputImageRotation.rotation90deg ||
              rotation == InputImageRotation.rotation270deg);
      setState(() {
        _faces = faces;
        _frameSize = rotated
            ? Size(image.height.toDouble(), image.width.toDouble())
            : Size(image.width.toDouble(), image.height.toDouble());
      });
    } catch (e) {
      debugPrint('Error al detectar rostros: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _cameras[_cameraIndex];
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Toma la foto y abre el editor con los mismos filtros (ahí se vuelve a
  /// detectar con el modo "accurate" sobre la foto en alta calidad).
  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final shot = await controller.takePicture();
      final filters = {..._active};
      await _stopCamera();
      if (!mounted) return;

      final result = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) =>
              FaceFilterEditorScreen(photo: shot, initialFilters: filters),
        ),
      );
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(result); // de vuelta a la pantalla de subida
        return;
      }
      // Si regresó sin usar la foto, se vuelve a encender la cámara.
      setState(() => _faces = []);
      await _startCamera();
    } catch (e) {
      // Si la foto falla, se reanuda la vista previa con filtros.
      if (_controller == controller &&
          controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        try {
          await controller.startImageStream(_processFrame);
        } catch (_) {}
      }
      if (mounted) {
        showTopToast(context, 'No se pudo tomar la foto: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final images = _images;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Cámara con filtros'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Cambiar cámara',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: ready && !_capturing ? _switchCamera : null,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    )
                  : !ready
                      ? const CircularProgressIndicator()
                      : AspectRatio(
                          // previewSize viene en horizontal; en vertical se invierte.
                          aspectRatio: 1 / controller.value.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(controller),
                              if (_frameSize != null && images != null)
                                CustomPaint(
                                  painter: LiveFiltersPainter(
                                    faces: _faces,
                                    frameSize: _frameSize!,
                                    // En iOS el frame de la cámara frontal ya
                                    // viene espejado; en Android hay que espejar.
                                    mirror: Platform.isAndroid &&
                                        controller.description.lensDirection ==
                                            CameraLensDirection.front,
                                    active: {..._active},
                                    images: images,
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 8),
          FilterSelector(
            active: _active,
            onToggle: (f) => setState(() {
              if (!_active.remove(f)) _active.add(f);
            }),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: GestureDetector(
                onTap: ready && !_capturing ? _capture : null,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    color: _capturing ? Colors.white54 : Colors.white24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
