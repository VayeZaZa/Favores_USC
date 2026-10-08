import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_model.dart';
import '../models/favor_model.dart';
import '../models/objeto_model.dart';

class FirestoreDataService {
  FirestoreDataService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _favores =>
      _firestore.collection('favores');
  CollectionReference<Map<String, dynamic>> get _objetos =>
      _firestore.collection('objetos');
  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  Future<void> guardarFavor(FavorModel favor) =>
      _favores.doc(favor.id).set(favor.toMap());

  Stream<List<FavorModel>> escucharFavores() {
    return _favores
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FavorModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> guardarObjeto(ObjetoModel objeto) =>
      _objetos.doc(objeto.id).set(objeto.toMap());

  Stream<List<ObjetoModel>> escucharObjetos() {
    return _objetos
        .orderBy('fechaReporte', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObjetoModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> guardarChat(ChatModel chat) =>
      _chats.doc(chat.id).set(chat.toMap());

  Stream<List<ChatModel>> escucharChats() {
    return _chats.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }
}
