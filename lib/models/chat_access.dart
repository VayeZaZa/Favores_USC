import 'chat_model.dart';
import 'favor_model.dart';
import 'objeto_model.dart';

/// El estado de la publicación es la fuente de permisos de escritura.
class ChatAccess {
  static bool puedeEscribir({
    required ChatModel chat,
    required String usuarioId,
    FavorModel? favor,
    ObjetoModel? objeto,
    String? chatActualId,
  }) {
    if (usuarioId.isEmpty || chat.soloLectura ||
        chat.participantes.length != 2 ||
        chat.participantes.toSet().length != 2 ||
        !chat.participantes.contains(usuarioId) ||
        (chatActualId != null && chatActualId != chat.id)) return false;
    if (chat.tipoReferencia == 'favor') {
      return favor != null && favor.id == chat.idReferencia &&
          favor.esAceptado && !favor.soloLectura &&
          chat.participantes.contains(favor.idAutor) &&
          chat.participantes.contains(favor.idAyudante);
    }
    return chat.tipoReferencia == 'objeto' && objeto != null &&
        objeto.id == chat.idReferencia && objeto.esConfirmado &&
        !objeto.casoCerrado && chat.participantes.contains(objeto.idDueno) &&
        chat.participantes.contains(objeto.idReclamante);
  }
}
