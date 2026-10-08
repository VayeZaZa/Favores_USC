import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

/// Servicio para manejo de compresión de imágenes en el cliente y subida a Cloudinary (RF04, RNF02)
class CloudinaryService {
  // Ajustar con la configuración de Cloudinary del proyecto
  static const String _cloudName = 'favores-usc-cloud'; 
  static const String _uploadPreset = 'favores_preset';

  late final CloudinaryPublic _cloudinary;

  CloudinaryService() {
    _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  /// Comprime una imagen en el cliente antes de subirla para cumplir RNF02 (<2s respuesta, menor transferencia)
  Future<File?> comprimirImagen(File file) async {
    try {
      final tempDir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Compresión balanceada de calidad/peso
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile != null) {
        return File(compressedXFile.path);
      }
      return file;
    } catch (e) {
      debugPrint('Error comprimiendo imagen: $e');
      return file; // Si la compresión falla, retornar archivo original
    }
  }

  /// Sube una lista de imágenes (máximo 3, RF04) a Cloudinary y retorna sus URLs secure_url
  Future<List<String>> subirImagenesFavores(List<File> imagenes) async {
    if (imagenes.isEmpty) return [];

    // Limitar estrictamente a 3 imágenes (RF04)
    final imagenesAProcesar = imagenes.take(3).toList();
    List<String> urlsGuardadas = [];

    for (var i = 0; i < imagenesAProcesar.length; i++) {
      File imagenAProcesar = imagenesAProcesar[i];
      
      // Compresión previa en cliente (RNF02)
      File? imagenComprimida = await comprimirImagen(imagenAProcesar);
      imagenAProcesar = imagenComprimida ?? imagenAProcesar;

      try {
        CloudinaryResponse response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imagenAProcesar.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'favores_fotos',
          ),
        );

        if (response.secureUrl.isNotEmpty) {
          urlsGuardadas.add(response.secureUrl);
        }
      } catch (e) {
        debugPrint('Error subiendo imagen $i a Cloudinary: $e');
        // Lanzamos o continuamos con las subidas exitosas
      }
    }

    return urlsGuardadas;
  }

  /// Sube una única imagen de objeto o de prueba de reclamo con compresión (RF10, RF11, RNF02)
  Future<String?> subirImagenObjeto(File imagen, {String folder = 'objetos_fotos'}) async {
    try {
      // Compresión previa en cliente
      File imagenAProcesar = (await comprimirImagen(imagen)) ?? imagen;

      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imagenAProcesar.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder,
        ),
      );

      return response.secureUrl.isNotEmpty ? response.secureUrl : null;
    } catch (e) {
      debugPrint('Error subiendo imagen a Cloudinary ($folder): $e');
      return null;
    }
  }
}
