import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

export 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show RecognizedText;

class MlkitOcrService {
  MlkitOcrService._();

  static final Map<String, Future<RecognizedText?>> _cache = {};

  static bool arquivoEhImagem(PlatformFile arquivo) {
    final extensao = arquivo.extension?.toLowerCase();
    return arquivo.path != null &&
        extensao != null &&
        ['jpg', 'jpeg', 'png'].contains(extensao);
  }

  static Future<RecognizedText?> reconhecerTexto(PlatformFile arquivo) {
    if (!arquivoEhImagem(arquivo)) return Future.value(null);

    final cacheKey = arquivo.path!;

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final leitura = _processarImagem(arquivo.path!);
    _cache[cacheKey] = leitura;

    return leitura;
  }

  static Future<RecognizedText?> _processarImagem(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      return await textRecognizer.processImage(inputImage);
    } finally {
      await textRecognizer.close();
    }
  }

  static Future<String?> lerTexto(PlatformFile arquivo) async {
    final recognizedText = await reconhecerTexto(arquivo);
    return recognizedText?.text;
  }
}
