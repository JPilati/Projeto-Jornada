import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:flutter/material.dart'; 
import 'package:file_picker/file_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'app_responsive.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'services/mlkit_ocr_service.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState 
  extends State<DocumentosScreen> {
  final db = FirebaseFirestore.instance;
  final supabase = Supabase.instance.client;
  final List<String> tiposDocumentosColaborador = [
  'Todos',
  'ASO',
  'CNH',
  'Toxicológico',
  'NR-06',
  'NR-11',
  'NR-11/18',
  'NR-12',
  'NR-18',
  'NR-35',
  'Direção Defensiva',
  'Integração por Cliente',
  'Cinto Paraquedista / CA',
  'Ficha de EPI / OS',
  'Ficha de EPI / OS',
  'Outros',
];

  bool carregando = true;
  bool isAdmin = false;

  List<Map<String, dynamic>> documentos = [];
  List<Map<String, dynamic>> usuarios = [];

  Map<String, Map<String, int>> resumoPorUsuario = {};

  String? usuarioSelecionadoId;
  String? usuarioSelecionadoNome;
  String? filtroStatusSelecionado;
  String tipoSelecionado = 'Todos';
  DateTime? dataInicioFiltro;
  DateTime? dataFimFiltro;
  bool mostrarFiltros = false;


  @override
  void initState() {
    super.initState();
    carregarDadosIniciais();
  }

  Future<bool> verificarAdminNoFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final profileDoc = await db.collection('users').doc(user.uid).get();

    if (!profileDoc.exists) return false;

    final profile = profileDoc.data();

    return profile?['perfil'] == 'Administrador';
  }

  Future<void> carregarDadosIniciais() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        carregando = false;
      });
      return;
    }

    try {
      final adminFirestore = await verificarAdminNoFirestore();

      isAdmin = adminFirestore;

      if (isAdmin) {
        await carregarUsuariosParaAdmin();
      } else {
        usuarioSelecionadoId = user.uid;
        await carregarDocumentos(user.uid);
      }

      setState(() {
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
      });

      mostrarErro('Erro ao carregar dados: $e');
    }
  }

  Future<void> carregarUsuariosParaAdmin() async {
    final profilesSnapshot = await db
        .collection('users')
        .where('perfil', isEqualTo: 'Operador')
        .orderBy('nome')
        .get();

    final docsSnapshot = await db
        .collection('documentos')
        .where('tipo', isEqualTo: 'operador')
        .get();

    final Map<String, Map<String, int>> contagem = {};

    for (final doc in docsSnapshot.docs) {
      final data = doc.data();

      final usuarioId = data['usuarioId'];
      final status = data['status'];

      if (usuarioId == null || status == null) continue;

      contagem.putIfAbsent(
        usuarioId,
        () => {
          'Regular': 0,
          'A vencer': 0,
          'Vencido': 0,
        },
      );

      contagem[usuarioId]![status] = (contagem[usuarioId]![status] ?? 0) + 1;
    }

    final lista = profilesSnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    lista.sort((a, b) {
      final aResumo = contagem[a['id']] ?? {};
      final bResumo = contagem[b['id']] ?? {};

      final aVencido = aResumo['Vencido'] ?? 0;
      final bVencido = bResumo['Vencido'] ?? 0;

      final aAVencer = aResumo['A vencer'] ?? 0;
      final bAVencer = bResumo['A vencer'] ?? 0;

      int prioridadeA;
      int prioridadeB;

      if (aVencido > 0) {
        prioridadeA = 3;
      } else if (aAVencer > 0) {
        prioridadeA = 2;
      } else {
        prioridadeA = 1;
      }

      if (bVencido > 0) {
        prioridadeB = 3;
      } else if (bAVencer > 0) {
        prioridadeB = 2;
      } else {
        prioridadeB = 1;
      }

      if (prioridadeA != prioridadeB) {
        return prioridadeA.compareTo(prioridadeB);
      }

      return (a['nome'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo(
            (b['nome'] ?? '')
                .toString()
                .toLowerCase(),
          );
    });

    setState(() {
      usuarios = lista;
      resumoPorUsuario = contagem;
    });
  }

  Future<void> carregarDocumentos(String usuarioId) async {
    Query<Map<String, dynamic>> query = db
      .collection('documentos')
      .where('usuarioId', isEqualTo: usuarioId)
      .where('tipo', isEqualTo: 'operador');
      if (!isAdmin) {
        query = query.where(
          'visivelOperador',
          isEqualTo: true,
        );
      }

    final snapshot = await query.get();

    final lista = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    lista.sort((a, b) {
      final statusA = a['status'] ?? 'Regular';
      final statusB = b['status'] ?? 'Regular';

      int prioridadeA;
      int prioridadeB;

      switch (statusA) {
        case 'Vencido':
          prioridadeA = 1;
          break;
        case 'A vencer':
          prioridadeA = 2;
          break;
        default:
          prioridadeA = 3;
      }

      switch (statusB) {
        case 'Vencido':
          prioridadeB = 1;
          break;
        case 'A vencer':
          prioridadeB = 2;
          break;
        default:
          prioridadeB = 3;
      }

      if (prioridadeA != prioridadeB) {
        return prioridadeA.compareTo(prioridadeB);
      }

      return (a['titulo'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo(
            (b['titulo'] ?? '')
                .toString()
                .toLowerCase(),
          );
    });

    setState(() {
      documentos = lista;
    });
  }

  void mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
      ),
    );
  }

  void mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green,
      ),
    );
  }

  String calcularStatus(DateTime validade) {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final validadeSemHora = DateTime(
      validade.year,
      validade.month,
      validade.day,
    );

    final diferenca = validadeSemHora.difference(hojeSemHora).inDays;

    if (diferenca < 0) return 'Vencido';
    if (diferenca <= appSettings.notificationDays) return 'A vencer';
    return 'Regular';
  }

  Color corStatus(String status) {
    if (status == 'Vencido') return const Color(0xFFE53935);
    if (status == 'A vencer') return const Color(0xFFE87722);
    return const Color(0xFF43A047);
  }

  String formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF4F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<PlatformFile?> escolherArquivoDocumento() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (resultado == null || resultado.files.isEmpty) {
      return null;
    }

    return resultado.files.first;
  }

  Future<DateTime?> detectarValidadePorOCR(PlatformFile arquivo) async {
    final recognizedText = await MlkitOcrService.reconhecerTexto(arquivo);

    if (recognizedText == null) return null;

    final textoOriginal = recognizedText.text;
      final texto = textoOriginal.toLowerCase();

      final regexData = RegExp(r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b');
      final matches = regexData.allMatches(textoOriginal).toList();

      if (matches.isEmpty) return null;

      DateTime? converterData(RegExpMatch match) {
        final dia = int.tryParse(match.group(1) ?? '');
        final mes = int.tryParse(match.group(2) ?? '');
        final ano = int.tryParse(match.group(3) ?? '');

        if (dia == null || mes == null || ano == null) return null;
        if (dia < 1 || dia > 31 || mes < 1 || mes > 12 || ano < 2000) {
          return null;
        }

        return DateTime.tryParse(
          '${ano.toString().padLeft(4, '0')}-'
          '${mes.toString().padLeft(2, '0')}-'
          '${dia.toString().padLeft(2, '0')}',
        );
      }

      final palavrasChave = [
        'validade',
        'válido até',
        'valido ate',
        'vencimento',
        'vence em',
        'data de validade',
        'data validade',
      ];

      DateTime? melhorData;
      int melhorPontuacao = -1;

      for (final match in matches) {
        final data = converterData(match);
        if (data == null) continue;

        final inicioData = match.start;
        final fimData = match.end;

        final inicioJanela = (inicioData - 80).clamp(0, texto.length);
        final fimJanela = (fimData + 40).clamp(0, texto.length);

        final contexto = texto.substring(inicioJanela, fimJanela);

        int pontuacao = 0;

        for (final palavra in palavrasChave) {
          if (contexto.contains(palavra)) {
            pontuacao += 10;
          }
        }

        final hoje = DateTime.now();
        final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

        if (data.isAfter(hojeSemHora)) {
          pontuacao += 5;
        } else {
          pontuacao -= 5;
        }

        if (data.year >= 2024 && data.year <= 2035) {
          pontuacao += 2;
        }

        if (pontuacao > melhorPontuacao) {
          melhorPontuacao = pontuacao;
          melhorData = data;
        }
      }

      return melhorData;
  }

  Future<String?> detectarTipoDocumentoPorOCR(PlatformFile arquivo) async {
    final recognizedText = await MlkitOcrService.reconhecerTexto(arquivo);

    if (recognizedText == null) return null;

    final texto = recognizedText.text.toLowerCase();
      final regras = <String, List<String>>{
        'CNH': [
          'carteira nacional de habilitação',
          'carteira nacional de habilitacao',
          'driver license',
          'permiso de conducción',
          'permiso de conducion',
          'habilitação',
          'habilitacao',
          'cnh',
          'nº registro',
          'n registro',
          'doc identidade',
          'data emissão',
          'data emissao',
        ],
        'ASO': [
          'aso',
          'atestado de saúde ocupacional',
          'atestado de saude ocupacional',
          'exame ocupacional',
          'exame clínico',
          'exame clinico',
          'apto',
          'inapto',
          'medicina do trabalho',
          'pcmso',
          'aptidão',
          'aptidao',
          'saúde ocupacional',
          'saude ocupacional',
          'clínica ocupacional',
          'clinica ocupacional',
          'exame admissional',
          'exame demissional',
          'exame periódico',
          'exame periodico',
          'médico do trabalho',
          'medico do trabalho',
        ],
        'Toxicológico': [
          'toxicológico',
          'toxicologico',
          'exame toxicológico',
          'exame toxicologico',
          'janela de detecção',
          'janela de deteccao',
          'laboratório',
          'laboratorio',
          'resultado toxicológico',
          'resultado toxicologico',
          'coleta',
          'laudo toxicológico',
          'laudo toxicologico',
          'cnh toxicológico',
          'cnh toxicologico',
        ],
        'NR-06': [
          'nr-06',
          'nr 06',
          'nr06',
          'equipamento de proteção individual',
          'equipamento de protecao individual',
          'epi',
          'ficha de entrega de epi',
        ],
        'NR-11': [
          'nr-11',
          'nr 11',
          'nr11',
          'empilhadeira',
          'ponte rolante',
          'movimentação de cargas',
          'movimentacao de cargas',
          'transporte movimentação armazenagem',
          'transporte movimentacao armazenagem',
          'guindaste',
          'munck',
          'operador de munck',
          'operador de guindaste',
          'caminhão munck',
          'caminhao munck',
          'içamento',
          'icamento',
          'movimentação e operação',
          'movimentacao e operacao',
        ],
        'NR-11/18': [
          'nr-11/18',
          'nr 11/18',
          'nr11/18',
          'nr-11 e nr-18',
          'nr 11 e nr 18',
        ],
        'NR-12': [
          'nr-12',
          'nr 12',
          'nr12',
          'máquinas e equipamentos',
          'maquinas e equipamentos',
          'segurança no trabalho em máquinas',
          'seguranca no trabalho em maquinas',
          'operação de máquinas',
          'operacao de maquinas',
          'proteções de máquinas',
          'protecoes de maquinas',
          'risco mecânico',
          'risco mecanico',
        ],
        'NR-18': [
          'nr-18',
          'nr 18',
          'nr18',
          'construção civil',
          'construcao civil',
          'indústria da construção',
          'industria da construcao',
          'canteiro de obras',
          'condições de segurança',
          'condicoes de seguranca',
          'obras',
          'segurança na construção',
          'seguranca na construcao',
        ],
        'NR-35': [
          'nr-35',
          'nr 35',
          'nr35',
          'trabalho em altura',
          'certificado de treinamento',
          'norma regulamentadora nr 35',
          'norma regulamentadora nr-35',
          'segurança do trabalho',
          'seguranca do trabalho',
          'altura',
          'trabalho acima de 2 metros',
          'queda',
          'proteção contra quedas',
          'protecao contra quedas',
          'ancoragem',
          'talabarte',
        ],
        'Direção Defensiva': [
          'direção defensiva',
          'direcao defensiva',
          'condução segura',
          'conducao segura',
          'curso de direção defensiva',
          'curso de direcao defensiva',
          'motorista',
          'condutor',
          'trânsito',
          'transito',
          'segurança no trânsito',
          'seguranca no transito',
        ],
        'Integração por Cliente': [
          'integração',
          'integracao',
          'treinamento de integração',
          'treinamento de integracao',
          'integração de segurança',
          'integracao de seguranca',
          'cliente',
          'onboarding',
          'integração operacional',
          'integracao operacional',
          'acesso à obra',
          'acesso a obra',
          'liberação de acesso',
          'liberacao de acesso',
          'cliente contratante',
        ],
        'Cinto Paraquedista / CA': [
          'cinto paraquedista',
          'cinturão paraquedista',
          'cinturao paraquedista',
          'certificado de aprovação',
          'certificado de aprovacao',
          'ca nº',
          'ca n°',
          'ca:',
          'cinturão de segurança',
          'cinturao de seguranca',
          'equipamento contra queda',
          'equipamento contra quedas',
          'certificado ca',
          'ca do equipamento',
        ],
        'Ficha de EPI / OS': [
          'ficha de epi',
          'ordem de serviço',
          'ordem de servico',
          'os de segurança',
          'os de seguranca',
          'ficha de entrega',
          'entrega de epi',
          'uso obrigatório de epi',
          'uso obrigatorio de epi',
          'entrega de equipamentos',
          'recebimento de epi',
          'termo de responsabilidade',
        ],
      };

      String? melhorTipo;
      int melhorPontuacao = 0;

      regras.forEach((tipo, palavras) {
        int pontuacao = 0;

        for (final palavra in palavras) {
          if (texto.contains(palavra)) {
            if (palavra.length >= 25) {
              pontuacao += 30;
            } else if (palavra.length >= 12) {
              pontuacao += 20;
            } else {
              pontuacao += 10;
            }
          }
        }

        if (pontuacao > melhorPontuacao) {
          melhorPontuacao = pontuacao;
          melhorTipo = tipo;
        }
      });

      if (melhorPontuacao == 0) return 'Outros';

      if (!tiposDocumentosColaborador.contains(melhorTipo)) {
        return 'Outros';
      }

      return melhorTipo;
  }

  Future<Map<String, String>> uploadDocumentoArquivo(
    PlatformFile arquivo,
  ) async {
    final usuarioId =
        usuarioSelecionadoId ?? FirebaseAuth.instance.currentUser?.uid;

    if (usuarioId == null) {
      throw Exception('Usuário não encontrado para upload.');
    }

    final bytes = arquivo.bytes;

    if (bytes == null) {
      throw Exception('Não foi possível ler o arquivo selecionado.');
    }

    final extensao = arquivo.extension?.toLowerCase() ?? 'jpg';
    final nomeArquivo =
        '${DateTime.now().millisecondsSinceEpoch}.$extensao';

    final arquivoPath = '$usuarioId/$nomeArquivo';

    final contentType = extensao == 'pdf'
        ? 'application/pdf'
        : 'image/$extensao';

    await supabase.storage.from('documentos').uploadBinary(
          arquivoPath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    final url = supabase.storage.from('documentos').getPublicUrl(arquivoPath);

    if (url.isEmpty) {
      throw Exception('Não foi possível gerar URL do arquivo.');
    }

    return {
      'url': url,
      'path': arquivoPath,
      'tipo': extensao == 'pdf' ? 'pdf' : 'imagem',
      'nome': arquivo.name,
    };
  }

  void abrirImagem(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizarDocumentoScreen(imageUrl: url),
      ),
    );
  }
  Future<void> abrirPdf(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        mostrarErro('Erro ao baixar PDF: ${response.statusCode}');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/documento.pdf');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisualizarPdfScreen(pdfPath: file.path),
        ),
      );
    } catch (e) {
      mostrarErro('Erro ao abrir PDF: $e');
    }
  }
  Future<void> abrirFormularioDocumentoComArquivo(
    PlatformFile arquivo,
  ) async {
    await abrirFormularioDocumento(arquivoInicial: arquivo);
  }

  Future<void> abrirFormularioDocumento({
    Map<String, dynamic>? documento,
    PlatformFile? arquivoInicial,
  }) async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      mostrarErro('Acesso somente leitura para operadores.');
      return;
    }

    final editando = documento != null;

    String? categoriaSelecionada = documento?['categoria'];

    final dataTexto = documento?['dataValidade'];
    DateTime? dataValidade =
        dataTexto != null ? DateTime.tryParse(dataTexto.toString()) : null;

    PlatformFile? arquivoSelecionado = arquivoInicial;
    Uint8List? arquivoBytes = arquivoInicial?.bytes;
    String? arquivoTipoSelecionado = arquivoInicial == null
        ? null
        : arquivoInicial.extension?.toLowerCase() == 'pdf'
            ? 'pdf'
            : 'imagem';
    bool salvando = false;
    bool analisandoOCR = false;
    bool ocrInicialExecutado = false;

    final dataMask = MaskTextInputFormatter(
      mask: '##/##/####',
      filter: {
        "#": RegExp(r'[0-9]'),
      },
    );

    final dataController = TextEditingController(
      text: dataValidade != null
          ? formatarData(dataValidade)
          : '',
    );
    
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      constraints: AppResponsive.modalConstraints(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!ocrInicialExecutado &&
                arquivoInicial != null &&
                arquivoInicial.extension?.toLowerCase() != 'pdf') {
              ocrInicialExecutado = true;

              Future.microtask(() async {
                setModalState(() {
                  analisandoOCR = true;
                });

                try {
                  final resultados = await Future.wait([
                    detectarValidadePorOCR(arquivoInicial),
                    detectarTipoDocumentoPorOCR(arquivoInicial),
                  ]);

                  final dataDetectada = resultados[0] as DateTime?;
                  final tipoDetectado = resultados[1] as String?;

                  setModalState(() {
                    if (dataDetectada != null) {
                      dataValidade = dataDetectada;
                      dataController.text = formatarData(dataDetectada);
                    }

                    if (tipoDetectado != null) {
                      categoriaSelecionada = tipoDetectado;
                    }

                    analisandoOCR = false;
                  });

                  if (dataDetectada != null && tipoDetectado != null) {
                    mostrarSucesso('Tipo e validade detectados automaticamente.');
                  } else if (dataDetectada != null) {
                    mostrarSucesso('Validade detectada: ${formatarData(dataDetectada)}');
                  } else if (tipoDetectado != null) {
                    mostrarSucesso('Tipo detectado: $tipoDetectado');
                  } else {
                    mostrarErro('Nenhum dado foi detectado automaticamente.');
                  }
                } catch (e) {
                  setModalState(() {
                    analisandoOCR = false;
                  });

                  mostrarErro('Erro ao analisar imagem: $e');
                }
              });
            }
            Future<void> salvar() async {
              if (categoriaSelecionada == null ||
                dataValidade == null ||
                (!editando && arquivoSelecionado == null)) {
                mostrarErro(
                  'Preencha todos os campos e selecione o arquivo do documento.',
                );
                return;
              }

              setModalState(() {
                salvando = true;
              });

              try {
                String? arquivoUrl = documento?['arquivoUrl'];
                String? arquivoPath = documento?['arquivoPath'];

                String? arquivoTipo = documento?['arquivoTipo'];
                String? arquivoNome = documento?['arquivoNome'];

                if (arquivoSelecionado != null) {
                  if (editando &&
                      arquivoPath != null &&
                      arquivoPath.isNotEmpty) {
                    await deletarArquivoStorage(arquivoPath);
                  }

                  final upload = await uploadDocumentoArquivo(arquivoSelecionado!);
                  arquivoUrl = upload['url'];
                  arquivoPath = upload['path'];
                  arquivoTipo = upload['tipo'];
                  arquivoNome = upload['nome'];
                }
                if (editando) {
                await editarDocumento(
                  id: documento['id'],
                  titulo: categoriaSelecionada!,
                  categoria: categoriaSelecionada!,
                  validade: dataValidade!,
                  arquivoUrl: arquivoUrl,
                  arquivoPath: arquivoPath,
                  arquivoTipo: arquivoTipo,
                  arquivoNome: arquivoNome,
                );
                } else {
                  await cadastrarDocumento(
                    titulo: categoriaSelecionada!,
                    categoria: categoriaSelecionada!,
                    validade: dataValidade!,
                    arquivoUrl: arquivoUrl,
                    arquivoPath: arquivoPath,
                    arquivoTipo: arquivoTipo,
                    arquivoNome: arquivoNome,
                  );
                }

                if (mounted) Navigator.pop(context);
              } catch (e) {
                mostrarErro('Erro ao salvar documento: $e');
              } finally {
                setModalState(() {
                  salvando = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editando ? 'Editar documento' : 'Lançar documento',
                      style: const TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      value: categoriaSelecionada,
                      hint: const Text('Escolher tipo de documento'),
                      decoration: inputDecoration('Tipo de documento'),
                      items: tiposDocumentosColaborador
                          .where((tipo) => tipo != 'Todos')
                          .map((tipo) {
                        return DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          categoriaSelecionada = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dataController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [dataMask],
                      decoration: inputDecoration('Validade'),
                      onChanged: (value) {
                        if (value.length == 10) {
                          final partes = value.split('/');

                          final dia = int.tryParse(partes[0]);
                          final mes = int.tryParse(partes[1]);
                          final ano = int.tryParse(partes[2]);

                          if (dia != null && mes != null && ano != null) {
                            dataValidade = DateTime(
                              ano,
                              mes,
                              dia,
                            );
                          }
                        }
                      },
                    ),
                    if (analisandoOCR) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Analisando documento para detectar validade...',
                        style: TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final arquivo = await escolherArquivoDocumento();

                        if (arquivo != null) {
                          final tipoArquivo =
                              arquivo.extension?.toLowerCase() == 'pdf' ? 'pdf' : 'imagem';

                          setModalState(() {
                            arquivoSelecionado = arquivo;
                            arquivoBytes = arquivo.bytes;
                            arquivoTipoSelecionado = tipoArquivo;

                            categoriaSelecionada = null;
                            dataValidade = null;
                            dataController.clear();
                          });

                          if (tipoArquivo == 'imagem') {
                            try {
                              final resultados = await Future.wait([
                                detectarValidadePorOCR(arquivo),
                                detectarTipoDocumentoPorOCR(arquivo),
                              ]);

                              final dataDetectada = resultados[0] as DateTime?;
                              final tipoDetectado = resultados[1] as String?;

                              setModalState(() {
                                if (dataDetectada != null) {
                                  dataValidade = dataDetectada;
                                  dataController.text = formatarData(dataDetectada);
                                }

                                if (tipoDetectado != null) {
                                  categoriaSelecionada = tipoDetectado;
                                }
                              });
                            } catch (e) {
                              mostrarErro('Erro ao analisar imagem: $e');
                            }
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDDE3EC)),
                        ),
                        child: Column(
                          children: [
                            if (arquivoBytes != null &&
                                arquivoTipoSelecionado == 'imagem')
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.image_rounded,
                                        color: Color(0xFFE87722),
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Prévia do documento',
                                        style: TextStyle(
                                          color: Color(0xFF1A202C),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      constraints: const BoxConstraints(
                                        minHeight: 260,
                                        maxHeight: 420,
                                      ),
                                      color: Colors.white,
                                      child: InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: Image.memory(
                                          arquivoBytes!,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE87722).withOpacity(0.25),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.touch_app_rounded,
                                          color: Color(0xFFE87722),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Toque aqui para trocar o arquivo selecionado.',
                                            style: TextStyle(
                                              color: Color(0xFF8A4B14),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (arquivoTipoSelecionado == 'pdf')
                              Column(
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        color: Color(0xFFE53935),
                                        size: 22,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'PDF selecionado',
                                        style: TextStyle(
                                          color: Color(0xFF1A202C),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE53935).withOpacity(0.25),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf,
                                          size: 72,
                                          color: Color(0xFFE53935),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          arquivoSelecionado?.name ?? 'Documento PDF',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFF1A202C),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'O PDF será salvo junto ao documento.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF718096),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE87722).withOpacity(0.25),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.touch_app_rounded,
                                          color: Color(0xFFE87722),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Toque aqui para trocar o arquivo selecionado.',
                                            style: TextStyle(
                                              color: Color(0xFF8A4B14),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (editando &&
                                documento['arquivoUrl'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  documento['arquivoUrl'].toString(),
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              const Icon(
                                Icons.upload_file,
                                size: 48,
                                color: Color(0xFFE87722),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              arquivoSelecionado == null
                                ? 'Selecionar imagem ou PDF'
                                : arquivoSelecionado!.name,
                              style: const TextStyle(
                                color: Color(0xFF1A202C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: salvando ? null : salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE87722),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: salvando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              editando
                                  ? 'SALVAR ALTERAÇÕES'
                                  : 'LANÇAR DOCUMENTO',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> cadastrarDocumento({
    required String titulo,
    required String categoria,
    required DateTime validade,
    required String? arquivoUrl,
    required String? arquivoPath,
    required String? arquivoTipo,
    required String? arquivoNome,
  }) async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      throw Exception('Acesso somente leitura para operadores.');
    }

    final usuarioId = usuarioSelecionadoId;

    if (usuarioId == null) {
      throw Exception('Usuário selecionado não encontrado.');
    }

    final status = calcularStatus(validade);

    await db.collection('documentos').add({
      'usuarioId': usuarioId,
      'equipamentoId': null,
      'tipo': 'operador',
      'titulo': titulo,
      'categoria': categoria,
      'dataValidade': validade.toIso8601String().split('T').first,
      'status': status,
      'arquivoUrl': arquivoUrl,
      'arquivoPath': arquivoPath,
      'visivelOperador': true,
      'createdAt': FieldValue.serverTimestamp(),
      'arquivoTipo': arquivoTipo,
      'arquivoNome': arquivoNome,
    });

    await carregarDocumentos(usuarioId);
    await carregarUsuariosParaAdmin();

    mostrarSucesso('Documento lançado com sucesso.');
  }

  Future<void> editarDocumento({
    required String id,
    required String titulo,
    required String categoria,
    required DateTime validade,
    required String? arquivoUrl,
    required String? arquivoPath,
    required String? arquivoTipo,
    required String? arquivoNome,
  }) async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      throw Exception('Acesso somente leitura para operadores.');
    }

    final status = calcularStatus(validade);

    await db.collection('documentos').doc(id).update({
      'titulo': titulo,
      'categoria': categoria,
      'dataValidade': validade.toIso8601String().split('T').first,
      'status': status,
      'arquivoUrl': arquivoUrl,
      'arquivoPath': arquivoPath,
      'arquivoTipo': arquivoTipo,
      'arquivoNome': arquivoNome,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (usuarioSelecionadoId != null) {
      await carregarDocumentos(usuarioSelecionadoId!);
    }

    await carregarUsuariosParaAdmin();

    mostrarSucesso('Documento atualizado com sucesso.');
  }

  Future<void> deletarArquivoStorage(String? arquivoPath) async {
    if (arquivoPath == null || arquivoPath.isEmpty) return;

    try {
      await supabase.storage.from('documentos').remove([arquivoPath]);
    } catch (_) {}
  }

  Future<void> excluirDocumento(Map<String, dynamic> documento) async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      mostrarErro('Acesso somente leitura para operadores.');
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir documento'),
        content: Text('Deseja excluir "${documento['titulo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await deletarArquivoStorage(
                  documento['arquivoPath']?.toString(),
                );

                await db.collection('documentos').doc(documento['id']).delete();

                if (usuarioSelecionadoId != null) {
                  await carregarDocumentos(usuarioSelecionadoId!);
                }

                await carregarUsuariosParaAdmin();

                mostrarSucesso('Documento excluído completamente.');
              } catch (e) {
                mostrarErro('Erro ao excluir: $e');
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> alterarVisibilidadeDocumento(
    Map<String, dynamic> documento,
  ) async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      mostrarErro('Acesso somente leitura para operadores.');
      return;
    }

    final visivelAtual = documento['visivelOperador'] != false;
    final novoValor = !visivelAtual;

    try {
      await db.collection('documentos').doc(documento['id']).update({
        'visivelOperador': novoValor,
      });

      if (usuarioSelecionadoId != null) {
        await carregarDocumentos(usuarioSelecionadoId!);
      }

      await carregarUsuariosParaAdmin();

      mostrarSucesso(
        novoValor
            ? 'Documento visível para o operador.'
            : 'Documento oculto para o operador.',
      );
    } catch (e) {
      mostrarErro('Erro ao alterar visibilidade: $e');
    }
  }

  Widget resumoCard(String titulo, int quantidade, Color cor) {
    final selecionado = filtroStatusSelecionado == titulo;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            filtroStatusSelecionado = selecionado ? null : titulo;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selecionado ? cor : cor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selecionado ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                quantidade.toString(),
                style: TextStyle(
                  color: selecionado ? Colors.white : cor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                titulo,
                style: TextStyle(
                  color: selecionado ? Colors.white : cor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget statusChip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget usuarioCard(Map<String, dynamic> usuario) {
    final resumo = resumoPorUsuario[usuario['id']] ?? {};

    final regular = resumo['Regular'] ?? 0;
    final aVencer = resumo['A vencer'] ?? 0;
    final vencido = resumo['Vencido'] ?? 0;
    final total = regular + aVencer + vencido;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        setState(() {
          usuarioSelecionadoId = usuario['id'];
          usuarioSelecionadoNome = usuario['nome'];
          carregando = true;
        });

        await carregarDocumentos(usuario['id']);

        setState(() {
          carregando = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: vencido > 0
              ? const Color(0xFFFFF5F5)
              : aVencer > 0
                  ? const Color(0xFFFFFAF0)
                  : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: vencido > 0
                ? const Color(0xFFE53935).withOpacity(0.25)
                : aVencer > 0
                    ? const Color(0xFFE87722).withOpacity(0.25)
                    : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: vencido > 0
                      ? const Color(0xFFE53935).withOpacity(0.12)
                      : aVencer > 0
                          ? const Color(0xFFE87722).withOpacity(0.12)
                          : const Color(0xFFE8F5E9),
                  child: Icon(
                    vencido > 0
                        ? Icons.warning_rounded
                        : aVencer > 0
                            ? Icons.schedule_rounded
                            : Icons.person,
                    color: vencido > 0
                        ? const Color(0xFFE53935)
                        : aVencer > 0
                            ? const Color(0xFFE87722)
                            : const Color(0xFF43A047),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario['nome'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFF1A202C),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usuario['cargo'] ?? 'Sem cargo',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Matrícula: ${usuario['matricula']}',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      total.toString(),
                      style: const TextStyle(
                        color: Color(0xFFE87722),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'docs',
                      style: TextStyle(
                        color: Color(0xFFE87722),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (regular > 0)
                    statusChip('$regular regular', const Color(0xFF43A047)),
                  if (aVencer > 0)
                    statusChip('$aVencer a vencer', const Color(0xFFE87722)),
                  if (vencido > 0)
                    statusChip('$vencido vencido', const Color(0xFFE53935)),
                  if (total == 0)
                    statusChip('sem documentos', const Color(0xFF718096)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget documentoCard(Map<String, dynamic> documento) {
    final status = documento['status'] ?? 'Regular';
    final cor = corStatus(status);

    final validadeString = documento['dataValidade'];
    DateTime? validade;

    if (validadeString != null) {
      validade = DateTime.tryParse(validadeString.toString());
    }

    final arquivoUrl = documento['arquivoUrl']?.toString();

    final arquivoTipo = documento['arquivoTipo']?.toString();
    final arquivoPath = documento['arquivoPath']?.toString();

    final arquivoEhPdf = arquivoTipo == 'pdf' ||
        (arquivoPath != null && arquivoPath.toLowerCase().endsWith('.pdf'));

    final visivelOperador = documento['visivelOperador'] != false;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: arquivoUrl != null
                ? () => arquivoEhPdf
                    ? abrirPdf(arquivoUrl)
                    : abrirImagem(arquivoUrl)
                : null,
            child: arquivoUrl != null
                ? arquivoEhPdf
                    ? Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Color(0xFFE53935),
                          size: 34,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          arquivoUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      )
                : CircleAvatar(
                    backgroundColor: cor.withOpacity(0.15),
                    child: Icon(Icons.description, color: cor),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: arquivoUrl != null
                  ? () => arquivoEhPdf
                      ? abrirPdf(arquivoUrl)
                      : abrirImagem(arquivoUrl)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documento['titulo'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    documento['categoria'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: cor),
                      const SizedBox(width: 6),
                      Text(
                        validade == null
                            ? 'Sem validade'
                            : 'Válido até ${formatarData(validade)}',
                        style: TextStyle(
                          color: cor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (arquivoUrl != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      arquivoEhPdf
                          ? 'Toque para abrir PDF'
                          : 'Toque para abrir imagem',
                      style: TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          visivelOperador
                              ? 'Visível para operador'
                              : 'Oculto para operador',
                          style: TextStyle(
                            color: visivelOperador
                                ? const Color(0xFF43A047)
                                : const Color(0xFF718096),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: visivelOperador,
                          activeColor: const Color(0xFF43A047),
                          onChanged: (_) {
                            alterarVisibilidadeDocumento(documento);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: cor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'abrir' && arquivoUrl != null) {
                    arquivoEhPdf ? abrirPdf(arquivoUrl) : abrirImagem(arquivoUrl);
                  }

                  if (value == 'editar') {
                    abrirFormularioDocumento(documento: documento);
                  }

                  if (value == 'excluir') {
                    excluirDocumento(documento);
                  }
                },
                itemBuilder: (_) => [
                  if (arquivoUrl != null)
                    PopupMenuItem(
                      value: 'abrir',
                      child: Text(arquivoEhPdf ? 'Abrir PDF' : 'Abrir imagem'),
                    ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar'),
                    ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget listaUsuariosAdmin() {
    return usuarios.isEmpty
        ? const Center(child: Text('Nenhum operador encontrado.'))
        : ListView(
            padding: const EdgeInsets.all(18),
            children: usuarios.map(usuarioCard).toList(),
          );
  }
  
  Future<void> selecionarDataInicio() async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataInicioFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Selecionar data',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Data',
      fieldHintText: 'dd/mm/aaaa',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE87722),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A202C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (data != null) {
      setState(() {
        dataInicioFiltro = data;
      });
    }
  }

  Future<void> selecionarDataFim() async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataInicioFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Selecionar data',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Data',
      fieldHintText: 'dd/mm/aaaa',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE87722),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A202C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (data != null) {
      setState(() {
        dataFimFiltro = data;
      });
    }
  }

  void limparFiltrosAvancados() {
    setState(() {
      tipoSelecionado = 'Todos';
      dataInicioFiltro = null;
      dataFimFiltro = null;
    });
  }

  Widget listaDocumentos() {
    final regular =
        documentos.where((doc) => doc['status'] == 'Regular').length;
    final aVencer =
        documentos.where((doc) => doc['status'] == 'A vencer').length;
    final vencidos =
        documentos.where((doc) => doc['status'] == 'Vencido').length;
    final documentosFiltrados = documentos.where((doc) {
    final statusOk = filtroStatusSelecionado == null ||
        doc['status'] == filtroStatusSelecionado;

    final tipoOk = tipoSelecionado == 'Todos' ||
        doc['categoria'] == tipoSelecionado;

    final dataTexto = doc['dataValidade'];
    final dataValidade =
        dataTexto != null ? DateTime.tryParse(dataTexto.toString()) : null;

    final dataInicioOk = dataInicioFiltro == null ||
        (dataValidade != null &&
            !dataValidade.isBefore(
              DateTime(
                dataInicioFiltro!.year,
                dataInicioFiltro!.month,
                dataInicioFiltro!.day,
              ),
            ));

    final dataFimOk = dataFimFiltro == null ||
        (dataValidade != null &&
            !dataValidade.isAfter(
              DateTime(
                dataFimFiltro!.year,
                dataFimFiltro!.month,
                dataFimFiltro!.day,
              ),
            ));

    return statusOk && tipoOk && dataInicioOk && dataFimOk;
  }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(26),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAdmin && usuarioSelecionadoNome != null) ...[
                Text(
                  usuarioSelecionadoNome!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  resumoCard(
                    'Regular',
                    regular,
                    const Color(0xFF43A047),
                  ),
                  const SizedBox(width: 10),
                  resumoCard(
                    'A vencer',
                    aVencer,
                    const Color(0xFFE87722),
                  ),
                  const SizedBox(width: 10),
                  resumoCard(
                    'Vencido',
                    vencidos,
                    const Color(0xFFE53935),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    mostrarFiltros = !mostrarFiltros;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Filtros avançados',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        mostrarFiltros
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              if (mostrarFiltros) ...[
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: tipoSelecionado,
                  dropdownColor: AppTheme.surface(context),
                  decoration: InputDecoration(
                    hintText: 'Tipo de documento',
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: tiposDocumentosColaborador.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      tipoSelecionado = value ?? 'Todos';
                    });
                  },
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: selecionarDataInicio,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            dataInicioFiltro == null
                                ? 'De:'
                                : 'De: ${formatarData(dataInicioFiltro!)}',
                            style: const TextStyle(
                              color: Color(0xFF1A202C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: selecionarDataFim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            dataFimFiltro == null
                                ? 'Até:'
                                : 'Até: ${formatarData(dataFimFiltro!)}',
                            style: const TextStyle(
                              color: Color(0xFF1A202C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: limparFiltrosAvancados,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Limpar filtros'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: documentosFiltrados.isEmpty
          ? Center(
              child: Text(
                filtroStatusSelecionado == null
                    ? 'Nenhum documento lançado.'
                    : 'Nenhum documento $filtroStatusSelecionado encontrado.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: documentosFiltrados.map(documentoCard).toList(),
            ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminNaListaUsuarios = isAdmin && usuarioSelecionadoId == null;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: Text(
          adminNaListaUsuarios
              ? 'Operadores'
              : isAdmin
                  ? 'Documentos do Operador'
                  : 'Meus Documentos',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: isAdmin && usuarioSelecionadoId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    usuarioSelecionadoId = null;
                    usuarioSelecionadoNome = null;
                    documentos = [];
                    filtroStatusSelecionado = null;
                    tipoSelecionado = 'Todos';
                    dataInicioFiltro = null;
                    dataFimFiltro = null;
                  });
                },
              )
            : null,
      ),
      floatingActionButton: isAdmin && !adminNaListaUsuarios
        ? FloatingActionButton(
            onPressed: () async {
              final arquivo = await escolherArquivoDocumento();

              if (arquivo == null) return;

              abrirFormularioDocumentoComArquivo(arquivo);
            },
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              child: const Icon(
                Icons.add,
                size: 32,
              ),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : AppResponsiveBody(
              child: adminNaListaUsuarios
                  ? listaUsuariosAdmin()
                  : listaDocumentos(),
            ),
    );
  }
}

class VisualizarDocumentoScreen extends StatelessWidget {
  final String imageUrl;

  const VisualizarDocumentoScreen({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Visualizar documento',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'Erro ao carregar imagem.',
                style: TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
class VisualizarPdfScreen extends StatelessWidget {
  final String pdfPath;

  const VisualizarPdfScreen({
    super.key,
    required this.pdfPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visualizar PDF',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SfPdfViewer.file(
        File(pdfPath),
        onDocumentLoadFailed: (details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao abrir PDF: ${details.description}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }
}
