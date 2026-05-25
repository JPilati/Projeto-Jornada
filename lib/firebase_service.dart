import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FirebaseService {
  FirebaseService._();

  static final auth = firebase_auth.FirebaseAuth.instance;
  static final db = FirebaseFirestore.instance;
  static final supabase = Supabase.instance.client;

  static firebase_auth.User? get currentUser => auth.currentUser;
  static String? get currentUid => auth.currentUser?.uid;

  static String emailPorMatricula(String matricula) {
    return '${matricula.trim()}@app.com';
  }

  static String calcularStatus(DateTime validade) {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final validadeSemHora =
        DateTime(validade.year, validade.month, validade.day);

    final dias = validadeSemHora.difference(hojeSemHora).inDays;

    if (dias < 0) return 'Vencido';
    if (dias <= 30) return 'A vencer';
    return 'Regular';
  }

  static String formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  static DateTime? parseData(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.tryParse(value.toString());
  }

  static Future<Map<String, dynamic>?> buscarMeuPerfil() async {
    final uid = currentUid;

    if (uid == null) return null;

    final doc = await db.collection('users').doc(uid).get();

    if (!doc.exists) return null;

    return {
      'id': doc.id,
      ...doc.data()!,
    };
  }

  static Future<Map<String, String>> uploadImagem({
    required XFile imagem,
    required String pasta,
  }) async {
    final uid = currentUid;

    if (uid == null) {
      throw Exception('Usuário não autenticado.');
    }

    final Uint8List bytes = await imagem.readAsBytes();

    final caminho =
        '$pasta/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage.from('documentos').uploadBinary(
          caminho,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    final url = supabase.storage.from('documentos').getPublicUrl(caminho);

    return {
      'url': url,
      'path': caminho,
    };
  }

  static Future<void> deletarArquivoPorPath(String? arquivoPath) async {
    if (arquivoPath == null || arquivoPath.isEmpty) return;

    await supabase.storage.from('documentos').remove([arquivoPath]);
  }
}