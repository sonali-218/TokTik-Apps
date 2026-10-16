import 'dart:io' show File;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toktok/domain/entities/video_post.dart';
import 'package:toktok/domain/repositories/posts_repository.dart';
import 'package:toktok/presentation/screens/filters/face_filter_editor_screen.dart';
import 'package:toktok/presentation/screens/filters/live_filter_camera_screen.dart';
import 'package:toktok/presentation/widgets/shared/top_toast.dart';

/// Subir un video o una foto: elegir archivo (galería o cámara), escribir
/// la descripción y publicar con barra de progreso. Al terminar se vuelve
/// al feed, donde la publicación aparece sola gracias al stream.
class UploadScreen extends StatefulWidget {
  final User user;
  final PostsRepository repository;

  const UploadScreen({super.key, required this.user, required this.repository});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _file;

  /// Foto sin filtros: los filtros siempre se aplican sobre la original,
  /// así no se acumulan si se edita varias veces.
  XFile? _originalPhoto;
  PostType _type = PostType.video;
  int _size = 0;

  bool _uploading = false;
  double _progress = 0;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pick(PostType type, ImageSource source) async {
    try {
      final XFile? picked = type == PostType.photo
          ? await _picker.pickImage(
              source: source,
              maxWidth: 1920,
              imageQuality: 85, // comprime un poco para subir más rápido
            )
          : await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 3),
            );
      if (picked == null) return; // canceló
      final size = await picked.length();
      if (!mounted) return;
      setState(() {
        _file = picked;
        _originalPhoto = type == PostType.photo ? picked : null;
        _type = type;
        _size = size;
      });
    } catch (e) {
      _show('No se pudo abrir ${source == ImageSource.camera ? 'la cámara' : 'la galería'}: $e');
    }
  }

  /// Abre el editor de filtros faciales (ML Kit) sobre la foto elegida.
  Future<void> _openFilterEditor() async {
    final original = _originalPhoto;
    if (original == null) return;
    final result = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (_) => FaceFilterEditorScreen(photo: original)),
    );
    if (result == null) return;
    final size = await result.length();
    if (!mounted) return;
    setState(() {
      _file = result;
      _size = size;
    });
  }

  /// Cámara con filtros en vivo: devuelve la foto ya con filtros.
  Future<void> _openLiveCamera() async {
    final result = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (_) => const LiveFilterCameraScreen()),
    );
    if (result == null) return;
    final size = await result.length();
    if (!mounted) return;
    setState(() {
      _file = result;
      // La foto en vivo ya trae los filtros aplicados: no se ofrece volver a
      // editarla (se dibujarían filtros encima de filtros).
      _originalPhoto = null;
      _type = PostType.photo;
      _size = size;
    });
  }

  void _showOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        Widget option(IconData icon, String label, PostType type, ImageSource source) =>
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                Navigator.pop(ctx);
                _pick(type, source);
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(Icons.video_library_outlined, 'Video de la galería',
                  PostType.video, ImageSource.gallery),
              option(Icons.videocam_outlined, 'Grabar video', PostType.video,
                  ImageSource.camera),
              option(Icons.photo_library_outlined, 'Foto de la galería',
                  PostType.photo, ImageSource.gallery),
              option(Icons.photo_camera_outlined, 'Tomar foto', PostType.photo,
                  ImageSource.camera),
              ListTile(
                leading: const Icon(Icons.face_retouching_natural),
                title: const Text('Cámara con filtros en vivo'),
                subtitle: const Text('Lentes, bigote, corona, perrito…'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openLiveCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _publish() async {
    if (_file == null) {
      _show('Primero elige un video o una foto.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      await widget.repository.uploadPost(
        file: _file!,
        type: _type,
        caption: _captionController.text.trim(),
        authorUid: widget.user.uid,
        authorEmail: widget.user.email ?? '',
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      showTopToast(context, '¡Publicado!');
      Navigator.of(context).pop();
    } on PostsFailure catch (e) {
      _show(e.message, isError: true);
    } catch (e) {
      _show('Error inesperado: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) return;
    showTopToast(context, message,
        icon: Icons.info_outline, isError: isError);
  }

  String _sizeText() {
    const mb = 1024 * 1024;
    return _size >= mb
        ? '${(_size / mb).toStringAsFixed(1)} MB'
        : '${(_size / 1024).toStringAsFixed(0)} KB';
  }

  Widget _preview() {
    final file = _file;
    if (file == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 56),
          SizedBox(height: 8),
          Text('Toca para elegir un video o una foto'),
        ],
      );
    }
    if (_type == PostType.video) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_outlined, size: 56),
          const SizedBox(height: 8),
          Text('${file.name}\n${_sizeText()}', textAlign: TextAlign.center),
        ],
      );
    }
    // En web path es una URL blob; en móvil, una ruta local.
    return kIsWeb
        ? Image.network(file.path, fit: BoxFit.cover)
        : Image.file(File(file.path), fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_uploading, // no salir a mitad de una subida
      child: Scaffold(
        appBar: AppBar(title: const Text('Nueva publicación')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: InkWell(
                      onTap: _uploading ? null : _showOptions,
                      child: AspectRatio(aspectRatio: 9 / 12, child: _preview()),
                    ),
                  ),
                ),
                if (_file != null && !_uploading)
                  Row(
                    children: [
                      if (_type == PostType.photo && _originalPhoto != null)
                        TextButton.icon(
                          onPressed: _openFilterEditor,
                          icon: const Icon(Icons.face_retouching_natural),
                          label: const Text('Filtros faciales'),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showOptions,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Cambiar archivo'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _captionController,
                  enabled: !_uploading,
                  maxLength: 150,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Escribe una descripción' : null,
                ),
                const SizedBox(height: 16),
                if (_uploading) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text('Subiendo… ${(_progress * 100).toStringAsFixed(0)} %',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _uploading ? null : _publish,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Publicar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
