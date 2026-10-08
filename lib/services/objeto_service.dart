import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/objeto_model.dart';
import 'chat_service.dart';
import 'cloudinary_service.dart';

/// Servicio de Firestore para la gestión del ciclo de vida de Objetos (RF07, RF10, RF11, RF12, RF13)
class ObjetoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ChatService _chatService = ChatService();

  CollectionReference<Map<String, dynamic>> get _objetosCol =>
      _firestore.collection('objetos');

  /// 1. Publicar un nuevo objeto perdido o encontrado (RF10)
  /// - Valida obligatoriedad de foto para objetos 'encontrados'
  /// - Foto opcional para objetos 'perdidos'
  /// - Compresión y subida a Cloudinary
  /// - Etiquetado por colores
  Future<ObjetoModel> publicarObjeto({
    required String idDueno,
    required String nombreDueno,
    required String titulo,
    required String descripcion,
    required String tipo, // 'perdido' o 'encontrado'
    required String etiquetaColor,
    required String lugarCampus,
    File? imagenArchivo,
  }) async {
    final tipoNormalizado = tipo.toLowerCase().trim();

    // Validación RF10: Obligatoriedad de foto para objetos "encontrados"
    if (tipoNormalizado == 'encontrado' && imagenArchivo == null) {
      throw ArgumentError(
        'La foto es obligatoria para reportar un objeto encontrado (RF10).',
      );
    }

    String urlFoto = '';
    if (imagenArchivo != null) {
      final subida = await _cloudinaryService.subirImagenObjeto(
        imagenArchivo,
        folder: 'objetos_fotos',
      );
      if (subida != null) {
        urlFoto = subida;
      } else if (tipoNormalizado == 'encontrado') {
        throw Exception(
          'No se pudo subir la foto obligatoria a Cloudinary. Revisa tu conexión.',
        );
      }
    }

    final docRef = _objetosCol.doc();
    final nuevoObjeto = ObjetoModel(
      id: docRef.id,
      idDueno: idDueno,
      nombreDueno: nombreDueno,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      tipo: tipoNormalizado,
      etiquetaColor: etiquetaColor,
      lugarCampus: lugarCampus,
      urlFoto: urlFoto,
      estadoActual: EstadoObjeto.publicado.valor,
      fechaReporte: DateTime.now(),
      soloLectura: false,
    );

    await docRef.set(nuevoObjeto.toMap());
    return nuevoObjeto;
  }

  /// 2. Stream en tiempo real de objetos filtrados por tipo (RF10)
  Stream<List<ObjetoModel>> obtenerObjetosStream({String? filtroTipo}) {
    Query<Map<String, dynamic>> query = _objetosCol;

    if (filtroTipo != null &&
        filtroTipo.isNotEmpty &&
        filtroTipo.toLowerCase() != 'todos') {
      query = query.where('tipo', isEqualTo: filtroTipo.toLowerCase().trim());
    }

    return query
        .orderBy('fechaReporte', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ObjetoModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// 3. Obtener un objeto específico por ID
  Future<ObjetoModel?> obtenerObjetoPorId(String id) async {
    final doc = await _objetosCol.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ObjetoModel.fromMap(doc.data()!, doc.id);
  }

  /// 4. Reclamación de objeto: "Yo tengo el objeto" / "Es mío" (RF11, RF12)
  /// - Exige obligatoriamente foto de prueba para continuar.
  /// - Cambia de estado a "Pendiente" para bloquear las solicitudes de otros usuarios.
  /// - Sube la foto de prueba a Cloudinary.
  /// - Crea sala de chat 1-a-1 e inserta mensaje inicial con la foto.
  Future<void> reclamarObjeto({
    required String idObjeto,
    required String idReclamante,
    required String nombreReclamante,
    required File fotoPrueba,
    String? mensajeAdicional,
  }) async {
    // Validación de foto de prueba obligatoria
    final urlPrueba = await _cloudinaryService.subirImagenObjeto(
      fotoPrueba,
      folder: 'objetos_pruebas',
    );

    if (urlPrueba == null || urlPrueba.isEmpty) {
      throw Exception(
        'Es obligatorio adjuntar una foto de prueba válida para continuar (RF11).',
      );
    }

    // Transacción atómica en Firestore para garantizar bloqueo y evitar condiciones de carrera
    await _firestore.runTransaction((transaction) async {
      final docRef = _objetosCol.doc(idObjeto);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('El objeto reportado ya no existe.');
      }

      final objeto = ObjetoModel.fromMap(snapshot.data()!, snapshot.id);

      if (objeto.idDueno == idReclamante) {
        throw Exception('No puedes reclamar tu propia publicación.');
      }

      // Validar que esté en 'Publicado' para poder bloquear a los demás
      if (objeto.estadoActual != EstadoObjeto.publicado.valor) {
        throw Exception(
          'Este objeto ya no está disponible para reclamar (Estado: ${objeto.estadoActual}).',
        );
      }

      // Máquina de estados: Publicado -> Pendiente
      transaction.update(docRef, {
        'estadoActual': EstadoObjeto.pendiente.valor,
        'idReclamante': idReclamante,
        'nombreReclamante': nombreReclamante,
        'fotoPruebaUrl': urlPrueba,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    });

    // Leer el objeto actualizado para obtener el dueño
    final objetoActualizado = await obtenerObjetoPorId(idObjeto);
    if (objetoActualizado != null) {
      // 5. Crear sala de chat exclusiva 1-a-1 (RF07)
      final chat = await _chatService.obtenerOCrearChat1a1(
        idReferencia: idObjeto,
        tipoReferencia: 'objeto',
        tituloReferencia: objetoActualizado.titulo,
        usuarioAId: objetoActualizado.idDueno,
        usuarioANombre: objetoActualizado.nombreDueno,
        usuarioBId: idReclamante,
        usuarioBNombre: nombreReclamante,
      );

      // 6. Mensaje automático con la foto de prueba al dueño (RF12)
      final textoNotif = mensajeAdicional != null && mensajeAdicional.isNotEmpty
          ? '📸 [Reclamación de Objeto]: "$mensajeAdicional"'
          : '📸 [Reclamación de Objeto]: He adjuntado una fotografía como prueba para verificar la entrega.';

      await _chatService.enviarMensaje(
        chatId: chat.id,
        idEmisor: idReclamante,
        nombreEmisor: nombreReclamante,
        texto: textoNotif,
        urlFoto: urlPrueba,
        esSistema: true,
      );
    }
  }

  /// 7. Control estricto de la máquina de estados del objeto (RF13)
  /// Secuencia: Publicado -> Pendiente -> Confirmado -> Entregado
  /// Retrocesos permitidos: únicamente a 'Publicado' por rechazo o no entrega
  Future<void> cambiarEstadoObjeto({
    required String idObjeto,
    required String nuevoEstadoStr,
    required String idUsuarioAccion,
    bool esRechazo = false,
  }) async {
    final docRef = _objetosCol.doc(idObjeto);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('El objeto especificado no existe.');
    }

    final objeto = ObjetoModel.fromMap(snapshot.data()!, snapshot.id);
    final nuevoEstado = EstadoObjeto.fromString(nuevoEstadoStr);

    // Validación estricta de la máquina de estados
    if (!objeto.validarCambioEstado(nuevoEstadoStr, esRechazo: esRechazo)) {
      throw StateError(
        'Transición no permitida: de "${objeto.estadoActual}" a "$nuevoEstadoStr". (RF13)',
      );
    }

    Map<String, dynamic> actualizacion = {
      'estadoActual': nuevoEstado.valor,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };

    // Si es un retroceso a Publicado (por rechazo o no entrega), se libera el reclamante
    if (nuevoEstado == EstadoObjeto.publicado && esRechazo) {
      actualizacion['idReclamante'] = null;
      actualizacion['nombreReclamante'] = null;
      actualizacion['fotoPruebaUrl'] = null;
    }

    // Si pasa a Entregado, el caso se cierra terminalmente (RF13, RF07)
    if (nuevoEstado == EstadoObjeto.entregado) {
      actualizacion['soloLectura'] = true;
    }

    await docRef.update(actualizacion);

    // Actualizar chat asociado a solo lectura si se entrega (RF07)
    if (nuevoEstado == EstadoObjeto.entregado) {
      await _chatService.cerrarChatDeReferencia(
        idReferencia: idObjeto,
        tipoReferencia: 'objeto',
      );
    }
  }
}
