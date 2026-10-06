import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;
  print('Inicializando colecciones base en Firestore...');

  // 1. users
  await db.collection('users').doc('ejemplo_usuario').set({
    'display_name': 'Valeria Yance',
    'email': 'valeria.yance00@usc.edu.co',
    'phone_number': '3101234567',
    'programa': 'Ingeniería de Sistemas',
    'semestre': 6,
    'verificado': false,
    'intentosFallidos': 0,
    'promedioCalificacion': 5.0,
    'favoresCompletados': 0,
    'favoresPedidos': 0,
    'objetosDevueltos': 0,
    'insignias': ['novato_solidario'],
    'created_time': FieldValue.serverTimestamp(),
  });
  print('Coleccion users creada.');

  // 2. favores
  await db.collection('favores').doc('ejemplo_favor').set({
    'titulo': 'Copias Taller Cálculo',
    'tipoServicio': 'Apuntes',
    'descripcion': 'Llevar 5 copias de cálculo a la Biblioteca Piso 2',
    'ubicacion': 'Bloque 2 - Biblioteca y Aulas Generales',
    'pago': 2000,
    'estado': 'Publicado',
    'nombreAutor': 'Valeria Yance',
    'idAutor': db.collection('users').doc('ejemplo_usuario'),
    'urlFotos': <String>[],
    'fechaCreacion': FieldValue.serverTimestamp(),
    'soloLectura': false,
    'yaAvisado24h': false,
    'calificacionHabilitada': false,
  });
  print('Coleccion favores creada.');

  // 3. objetos
  await db.collection('objetos').doc('ejemplo_objeto').set({
    'tipo': 'perdido',
    'etiquetaColor': 'rojo',
    'titulo': 'Calculadora Casio fx-570',
    'descripcion': 'Dejada en una banca cerca a la cafetería',
    'lugarCampus': 'Bloque 6 - Cafetería Central / Plazoleta',
    'urlFoto': '',
    'idDueno': db.collection('users').doc('ejemplo_usuario'),
    'nombreDueno': 'Valeria Yance',
    'estadoActual': 'Publicado',
    'fechaReporte': FieldValue.serverTimestamp(),
  });
  print('Coleccion objetos creada.');

  // 4. chats
  final chatRef = db.collection('chats').doc('ejemplo_chat');
  await chatRef.set({
    'idReferencia': 'ejemplo_favor',
    'tipoReferencia': 'FAVOR',
    'participantes': [
      db.collection('users').doc('ejemplo_usuario'),
    ],
    'ultimoMensaje': 'Hola, te puedo colaborar con el favor.',
    'ultimaFecha': FieldValue.serverTimestamp(),
    'soloLectura': false,
  });

  await chatRef.collection('mensajes').doc('ejemplo_mensaje').set({
    'texto': 'Hola, te puedo colaborar con el favor.',
    'fechaHora': FieldValue.serverTimestamp(),
    'idEmisor': db.collection('users').doc('ejemplo_usuario'),
  });
  print('Coleccion chats y mensajes creada.');

  print('¡TODAS LAS COLECCIONES RESTAURADAS CON ÉXITO!');
}
