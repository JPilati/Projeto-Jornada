import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'app_responsive.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'services/mlkit_ocr_service.dart';

class EmpresaDocumentosScreen extends StatefulWidget {
  const EmpresaDocumentosScreen({super.key});

  @override
  State<EmpresaDocumentosScreen> createState() =>
      _EmpresaDocumentosScreenState();
}

class _EmpresaDocumentosScreenState extends State<EmpresaDocumentosScreen> {
  final db = FirebaseFirestore.instance;
  final supabase = Supabase.instance.client;

  bool carregando = true;
  bool isAdmin = false;
  bool mostrarFiltros = false;

  String tipoSelecionado = 'Todos';
  String? filtroStatusSelecionado;
  DateTime? dataInicioFiltro;
  DateTime? dataFimFiltro;

  List<Map<String, dynamic>> documentos = [];

  final List<String> tiposEmpresa = [
    'Todos',
    'ART de Equipamento Especial',
    'Ficha de EPI / OS',
    'Licença',
    'Alvará',
    'Seguro',
    'Certificado',
    'Laudo Técnico',
    'Contrato',
    'Outros',
  ];

  final List<String> equipamentosEmpresa = [
    'Balancim',
    'Gaiola',
    'Gaiola 1',
    'Gaiola 2',
    'Gaiola 3',
    'Gaiola 4',
    'Braço',
    'Geral',
  ];

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<bool> verificarAdminNoFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final profileDoc = await db.collection('users').doc(user.uid).get();
    if (!profileDoc.exists) return false;

    return profileDoc.data()?['perfil'] == 'Administrador';
  }

  Future<void> carregarDados() async {
    try {
      final admin = await verificarAdminNoFirestore();

      final snapshot = await db
          .collection('documentos_empresa')
          .orderBy('nome', descending: false)
          .get();

      final lista = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      lista.sort((a, b) {
        final prioridadeA = prioridadeStatusEmpresa(a['status'] ?? 'ok');
        final prioridadeB = prioridadeStatusEmpresa(b['status'] ?? 'ok');

        if (prioridadeA != prioridadeB) {
          return prioridadeA.compareTo(prioridadeB);
        }

        return (a['nome'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['nome'] ?? '').toString().toLowerCase(),
            );
      });

      setState(() {
        isAdmin = admin;
        documentos = lista;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
      });

      mostrarErro('Erro ao carregar documentos da empresa: $e');
    }
  }

  String calcularStatus(DateTime dataVencimento) {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final vencimentoSemHora = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
    );

    if (vencimentoSemHora.isBefore(hojeSemHora)) return 'expired';

    final limite = hojeSemHora.add(Duration(days: appSettings.notificationDays));

    if (vencimentoSemHora.isBefore(limite) ||
        vencimentoSemHora.isAtSameMomentAs(limite)) {
      return 'warning';
    }

    return 'ok';
  }

  Color corStatus(String status) {
    if (status == 'expired') return const Color(0xFFE53935);
    if (status == 'warning') return const Color(0xFFE87722);
    return const Color(0xFF43A047);
  }

  String textoStatus(String status) {
    if (status == 'expired') return 'Vencido';
    if (status == 'warning') return 'A vencer';
    return 'Regular';
  }
  int prioridadeStatusEmpresa(String status) {
    if (status == 'ok') return 1;       // regular
    if (status == 'warning') return 2;  // a vencer
    return 3;                           // vencido
  }

  DateTime? parseData(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  String formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$dia/$mes/$ano';
  }

  DateTime? parseDataDigitada(String value) {
    if (value.length != 10) return null;

    final partes = value.split('/');
    if (partes.length != 3) return null;

    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);

    if (dia == null || mes == null || ano == null) return null;

    final data = DateTime(ano, mes, dia);

    if (data.day != dia || data.month != mes || data.year != ano) {
      return null;
    }

    return data;
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

  Future<PlatformFile?> escolherArquivoDocumentoEmpresa() async {
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

  Future<DateTime?> detectarValidadeEmpresaPorOCR(PlatformFile arquivo) async {
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

  Future<DateTime?> detectarEmissaoEmpresaPorOCR(PlatformFile arquivo) async {
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
        'data de emissão',
        'data emissao',
        'data de emissao',
        'emissão',
        'emissao',
        'emitido em',
        'data do documento',
        'data de realização',
        'data de realizacao',
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

        if (data.isBefore(hojeSemHora) || data.isAtSameMomentAs(hojeSemHora)) {
          pontuacao += 5;
        }

        if (data.year >= 2020 && data.year <= 2035) {
          pontuacao += 2;
        }

        if (pontuacao > melhorPontuacao) {
          melhorPontuacao = pontuacao;
          melhorData = data;
        }
      }

      return melhorData;
  }

  Future<String?> detectarTipoEmpresaPorOCR(PlatformFile arquivo) async {
    final recognizedText = await MlkitOcrService.reconhecerTexto(arquivo);

    if (recognizedText == null) return null;

    final texto = recognizedText.text.toLowerCase();

      final regras = <String, List<String>>{
        'ART de Equipamento Especial': [
        'anotação de responsabilidade técnica',
        'anotacao de responsabilidade tecnica',
        'art nº',
        'art n°',
        'registro art',
        'número da art',
        'numero da art',
        'equipamento especial',
      ],
        'Ficha de EPI / OS': [
          'ficha de epi',
          'ordem de serviço',
          'ordem de servico',
          'os de segurança',
          'os de seguranca',
          'entrega de epi',
          'equipamento de proteção individual',
          'equipamento de protecao individual',
        ],
        'Licença': [
          'licença',
          'licenca',
          'licenciamento',
          'autorização',
          'autorizacao',
        ],
        'Alvará': [
          'alvará',
          'alvara',
          'alvará de funcionamento',
          'alvara de funcionamento',
          'prefeitura',
        ],
        'Seguro': [
          'seguro',
          'apólice',
          'apolice',
          'seguradora',
          'cobertura',
        ],
        'Certificado': [
          'certificado',
          'certificação',
          'certificacao',
          'declaração',
          'declaracao',
          'certificado de conformidade',
          'certificamos que',
          'este certificado',
          'certificado',
          'conformidade',
          'autenticidade',
        ],
        'Laudo Técnico': [
          'laudo técnico',
          'laudo tecnico',
          'parecer técnico',
          'parecer tecnico',
          'inspeção',
          'inspecao',
          'vistoria',
        ],
        'Contrato': [
          'contrato',
          'contratante',
          'contratada',
          'prestação de serviços',
          'prestacao de servicos',
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

      if (!tiposEmpresa.contains(melhorTipo)) {
        return 'Outros';
      }

      return melhorTipo;
  }

  Future<String?> detectarEquipamentoEmpresaPorOCR(PlatformFile arquivo) async {
    final recognizedText = await MlkitOcrService.reconhecerTexto(arquivo);

    if (recognizedText == null) return null;

    final texto = recognizedText.text.toLowerCase();

      final regras = <String, List<String>>{
        'Balancim': [
          'balancim',
          'andaime suspenso',
          'plataforma suspensa',
        ],
        'Gaiola': [
        'gaiola',
        'gaiola de elevação',
        'gaiola de elevacao',
        'gaiola de elevação de pessoas',
        'gaiola de elevacao de pessoas',
      ],
        'Gaiola 1': [
          'gaiola 1',
          'gaiola nº 1',
          'gaiola n° 1',
          'gaiola numero 1',
        ],
        'Gaiola 2': [
          'gaiola 2',
          'gaiola nº 2',
          'gaiola n° 2',
          'gaiola numero 2',
        ],
        'Gaiola 3': [
          'gaiola 3',
          'gaiola nº 3',
          'gaiola n° 3',
          'gaiola numero 3',
        ],
        'Braço': [
          'braço',
          'braco',
          'braço articulado',
          'braco articulado',
        ],
        'Geral': [
          'geral',
          'documento geral',
          'documento da empresa',
        ],
      };

      String? melhorEquipamento;
      int melhorPontuacao = 0;

      regras.forEach((equipamento, palavras) {
        int pontuacao = 0;

        for (final palavra in palavras) {
          if (texto.contains(palavra)) {
            if (palavra.length >= 18) {
              pontuacao += 25;
            } else if (palavra.length >= 10) {
              pontuacao += 15;
            } else {
              pontuacao += 10;
            }
          }
        }

        if (pontuacao > melhorPontuacao) {
          melhorPontuacao = pontuacao;
          melhorEquipamento = equipamento;
        }
      });

      if (melhorPontuacao == 0) return null;

      if (!equipamentosEmpresa.contains(melhorEquipamento)) {
        return null;
      }

      return melhorEquipamento;
  }

  Future<void> abrirFormularioDocumentoEmpresaComArquivo(
    PlatformFile arquivo,
  ) async {
    await abrirFormularioDocumento(arquivoInicial: arquivo);
  }

  Future<Map<String, String>> uploadArquivoEmpresa(PlatformFile arquivo) async {
    final bytes = arquivo.bytes;

    if (bytes == null) {
      throw Exception('Não foi possível ler o arquivo selecionado.');
    }

    final extensao = arquivo.extension?.toLowerCase() ?? 'jpg';
    final arquivoPath =
        'empresa/${DateTime.now().millisecondsSinceEpoch}.$extensao';

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
      throw Exception('Não foi possível gerar URL do documento.');
    }

    return {
      'url': url,
      'path': arquivoPath,
      'tipo': extensao == 'pdf' ? 'pdf' : 'imagem',
      'nome': arquivo.name,
    };
  }

  Future<void> deletarArquivoStorage(String? arquivoPath) async {
    if (arquivoPath == null || arquivoPath.isEmpty) return;

    try {
      await supabase.storage.from('documentos').remove([arquivoPath]);
    } catch (_) {}
  }

  void abrirImagem(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizarDocumentoEmpresaScreen(imageUrl: url),
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
      final file = File('${dir.path}/documento_empresa.pdf');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisualizarPdfEmpresaScreen(pdfPath: file.path),
        ),
      );
    } catch (e) {
      mostrarErro('Erro ao abrir PDF: $e');
    }
  }

  Future<void> abrirFormularioDocumento({
    Map<String, dynamic>? documento,
    PlatformFile? arquivoInicial,
  }) async {
    if (!isAdmin) {
      mostrarErro('Acesso permitido somente para administradores.');
      return;
    }

    final editando = documento != null;

    String? tipoSelecionadoForm = documento?['tipo'];
    String? equipamentoSelecionado = documento?['equipamento'];

    final observacaoController = TextEditingController(
      text: documento?['observacao'] ?? '',
    );

    DateTime? dataEmissao = parseData(documento?['data_emissao']);
    DateTime? dataVencimento = parseData(documento?['data_vencimento']);

    final dataMask = MaskTextInputFormatter(
      mask: '##/##/####',
      filter: {
        '#': RegExp(r'[0-9]'),
      },
    );

    final emissaoController = TextEditingController(
      text: dataEmissao != null ? formatarData(dataEmissao) : '',
    );

    final vencimentoController = TextEditingController(
      text: dataVencimento != null ? formatarData(dataVencimento) : '',
    );

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
                    detectarValidadeEmpresaPorOCR(arquivoInicial),
                    detectarTipoEmpresaPorOCR(arquivoInicial),
                    detectarEmissaoEmpresaPorOCR(arquivoInicial),
                    detectarEquipamentoEmpresaPorOCR(arquivoInicial),
                  ]);

                  final dataDetectada = resultados[0] as DateTime?;
                  final tipoDetectado = resultados[1] as String?;
                  final emissaoDetectada = resultados[2] as DateTime?;
                  final equipamentoDetectado = resultados[3] as String?;

                  setModalState(() {
                    if (dataDetectada != null) {
                      dataVencimento = dataDetectada;
                      vencimentoController.text = formatarData(dataDetectada);
                    }

                    if (tipoDetectado != null) {
                      tipoSelecionadoForm = tipoDetectado;
                    }

                    if (emissaoDetectada != null) {
                      dataEmissao = emissaoDetectada;
                      emissaoController.text = formatarData(emissaoDetectada);
                    }

                    if (equipamentoDetectado != null) {
                      equipamentoSelecionado = equipamentoDetectado;
                    }

                    analisandoOCR = false;
                  });

                  if (dataDetectada != null ||
                      tipoDetectado != null ||
                      emissaoDetectada != null ||
                      equipamentoDetectado != null) {
                    mostrarSucesso('Dados detectados automaticamente.');
                  }

                } catch (e) {
                  setModalState(() {
                    analisandoOCR = false;
                  });
                }
              });
            }
            Future<void> salvar() async {
              dataEmissao = parseDataDigitada(emissaoController.text);
              dataVencimento = parseDataDigitada(vencimentoController.text);

              if (tipoSelecionadoForm == null ||
                  equipamentoSelecionado == null ||
                  dataEmissao == null ||
                  dataVencimento == null ||
                  (!editando && arquivoSelecionado == null)) {
                mostrarErro('Preencha todos os campos obrigatórios.');
                return;
              }

              setModalState(() {
                salvando = true;
              });

              try {
                String? arquivoUrl = documento?['arquivo_url'];
                String? arquivoPath = documento?['arquivo_path'];
                String? arquivoTipo = documento?['arquivo_tipo'];
                String? arquivoNome = documento?['arquivo_nome'];

                if (arquivoSelecionado != null) {
                  if (editando &&
                      arquivoPath != null &&
                      arquivoPath.isNotEmpty) {
                    await deletarArquivoStorage(arquivoPath);
                  }

                  final upload = await uploadArquivoEmpresa(arquivoSelecionado!);
                  arquivoUrl = upload['url'];
                  arquivoPath = upload['path'];
                  arquivoTipo = upload['tipo'];
                  arquivoNome = upload['nome'];
                }

                final nome =
                    '$tipoSelecionadoForm - $equipamentoSelecionado';

                final status = calcularStatus(dataVencimento!);

                final dados = {
                  'nome': nome,
                  'tipo': tipoSelecionadoForm,
                  'equipamento': equipamentoSelecionado,
                  'data_emissao': Timestamp.fromDate(dataEmissao!),
                  'data_vencimento': Timestamp.fromDate(dataVencimento!),
                  'status': status,
                  'arquivo_url': arquivoUrl,
                  'arquivo_path': arquivoPath,
                  'observacao': observacaoController.text.trim(),
                  'arquivo_tipo': arquivoTipo,
                  'arquivo_nome': arquivoNome,
                };

                if (editando) {
                  await db
                      .collection('documentos_empresa')
                      .doc(documento['id'])
                      .update({
                    ...dados,
                    'updated_at': FieldValue.serverTimestamp(),
                  });

                  mostrarSucesso('Documento atualizado com sucesso.');
                } else {
                  await db.collection('documentos_empresa').add({
                    ...dados,
                    'created_at': FieldValue.serverTimestamp(),
                  });

                  mostrarSucesso('Documento lançado com sucesso.');
                }

                await carregarDados();

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
                      editando
                          ? 'Editar documento da empresa'
                          : 'Lançar documento da empresa',
                      style: const TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (analisandoOCR)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE87722),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Analisando documento...',
                                style: TextStyle(
                                  color: Color(0xFFE87722),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      value: tipoSelecionadoForm,
                      hint: const Text('Escolher tipo de documento'),
                      decoration: inputDecoration('Tipo'),
                      items: tiposEmpresa
                          .where((tipo) => tipo != 'Todos')
                          .map((tipo) {
                        return DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tipoSelecionadoForm = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: equipamentoSelecionado,
                      hint: const Text('Escolher equipamento'),
                      decoration: inputDecoration('Equipamento'),
                      items: equipamentosEmpresa.map((equipamento) {
                        return DropdownMenuItem(
                          value: equipamento,
                          child: Text(equipamento),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          equipamentoSelecionado = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emissaoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [dataMask],
                      decoration: inputDecoration('Data de emissão'),
                      onChanged: (value) {
                        dataEmissao = parseDataDigitada(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: vencimentoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        MaskTextInputFormatter(
                          mask: '##/##/####',
                          filter: {
                            '#': RegExp(r'[0-9]'),
                          },
                        ),
                      ],
                      decoration: inputDecoration('Data de vencimento'),
                      onChanged: (value) {
                        dataVencimento = parseDataDigitada(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: observacaoController,
                      maxLines: 3,
                      decoration: inputDecoration('Observação opcional'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final arquivo = await escolherArquivoDocumentoEmpresa();

                        if (arquivo != null) {
                          final tipoArquivo =
                              arquivo.extension?.toLowerCase() == 'pdf' ? 'pdf' : 'imagem';

                          setModalState(() {
                            arquivoSelecionado = arquivo;
                            arquivoBytes = arquivo.bytes;
                            arquivoTipoSelecionado = tipoArquivo;
                          });

                          if (tipoArquivo == 'imagem') {
                            setModalState(() {
                              analisandoOCR = true;
                            });

                            try {
                              final resultados = await Future.wait([
                                detectarValidadeEmpresaPorOCR(arquivo),
                                detectarTipoEmpresaPorOCR(arquivo),
                                detectarEmissaoEmpresaPorOCR(arquivo),
                                detectarEquipamentoEmpresaPorOCR(arquivo),
                              ]);

                              final dataDetectada = resultados[0] as DateTime?;
                              final tipoDetectado = resultados[1] as String?;
                              final emissaoDetectada =
                                  resultados[2] as DateTime?;
                              final equipamentoDetectado =
                                  resultados[3] as String?;

                              setModalState(() {
                                if (dataDetectada != null) {
                                  dataVencimento = dataDetectada;
                                  vencimentoController.text =
                                      formatarData(dataDetectada);
                                }

                                if (tipoDetectado != null) {
                                  tipoSelecionadoForm = tipoDetectado;
                                }

                                if (emissaoDetectada != null) {
                                  dataEmissao = emissaoDetectada;
                                  emissaoController.text =
                                      formatarData(emissaoDetectada);
                                }

                                if (equipamentoDetectado != null) {
                                  equipamentoSelecionado = equipamentoDetectado;
                                }

                                analisandoOCR = false;
                              });

                              if (dataDetectada != null ||
                                  tipoDetectado != null ||
                                  emissaoDetectada != null ||
                                  equipamentoDetectado != null) {
                                mostrarSucesso(
                                  'Dados detectados automaticamente.',
                                );
                              } else {
                                mostrarErro(
                                  'Nenhum dado foi detectado automaticamente.',
                                );
                              }
                            } catch (e) {
                              setModalState(() {
                                analisandoOCR = false;
                              });

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
                          border: Border.all(
                            color: const Color(0xFFDDE3EC),
                          ),
                        ),
                        child: Column(
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
                            if (arquivoBytes != null && arquivoTipoSelecionado == 'imagem')
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  arquivoBytes!,
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else if (editando &&
                                documento['arquivo_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  documento['arquivo_url'].toString(),
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else if (arquivoTipoSelecionado == 'pdf')
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
                              )
                            else
                              const Icon(
                                Icons.camera_alt_rounded,
                                size: 48,
                                color: Color(0xFFE87722),
                              ),
                            const SizedBox(height: 8),
                            if (arquivoSelecionado != null) ...[
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
                            Text(
                              arquivoSelecionado == null
                                  ? 'Selecionar imagem ou PDF'
                                  : arquivoSelecionado!.name,
                              textAlign: TextAlign.center,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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

  Future<void> excluirDocumento(Map<String, dynamic> documento) async {
    if (!isAdmin) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir documento'),
        content: Text('Deseja excluir "${documento['nome']}"?'),
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
                  documento['arquivo_path']?.toString(),
                );

                await db
                    .collection('documentos_empresa')
                    .doc(documento['id'])
                    .delete();

                await carregarDados();

                mostrarSucesso('Documento excluído.');
              } catch (e) {
                mostrarErro('Erro ao excluir documento: $e');
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> selecionarDataInicio() async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataInicioFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
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
      initialDate: dataFimFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (data != null) {
      setState(() {
        dataFimFiltro = data;
      });
    }
  }

  void limparFiltros() {
    setState(() {
      tipoSelecionado = 'Todos';
      dataInicioFiltro = null;
      dataFimFiltro = null;
    });
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

  Widget documentoCard(Map<String, dynamic> documento) {
    final status = documento['status'] ?? 'ok';
    final cor = corStatus(status);

    final vencimento = parseData(documento['data_vencimento']);
    final emissao = parseData(documento['data_emissao']);

    final arquivoUrl = documento['arquivo_url']?.toString();
    final arquivoTipo = documento['arquivo_tipo']?.toString();
    final arquivoPath = documento['arquivo_path']?.toString();

    final arquivoEhPdf = arquivoTipo == 'pdf' ||
        (arquivoPath != null && arquivoPath.toLowerCase().endsWith('.pdf'));

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
                ? () => arquivoEhPdf ? abrirPdf(arquivoUrl) : abrirImagem(arquivoUrl)
                : null,
            child: arquivoUrl != null && arquivoUrl.isNotEmpty
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
                          fit: BoxFit.contain,
                        ),
                      )
                : CircleAvatar(
                    backgroundColor: cor.withOpacity(0.15),
                    child: Icon(Icons.business_rounded, color: cor),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: arquivoUrl != null && arquivoUrl.isNotEmpty
                  ? () => arquivoEhPdf ? abrirPdf(arquivoUrl) : abrirImagem(arquivoUrl)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documento['nome'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    documento['tipo'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Equipamento: ${documento['equipamento'] ?? '-'}',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (emissao != null)
                    Text(
                      'Emissão: ${formatarData(emissao)}',
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                  if (vencimento != null)
                    Text(
                      'Vence em: ${formatarData(vencimento)}',
                      style: TextStyle(
                        color: cor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  textoStatus(status),
                  style: TextStyle(
                    color: cor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'editar') {
                      abrirFormularioDocumento(documento: documento);
                    }

                    if (value == 'excluir') {
                      excluirDocumento(documento);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
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

  Widget listaDocumentos() {
    final regulares =
        documentos.where((doc) => doc['status'] == 'ok').length;

    final aVencer =
        documentos.where((doc) => doc['status'] == 'warning').length;

    final vencidos =
        documentos.where((doc) => doc['status'] == 'expired').length;

    final documentosFiltrados = documentos.where((doc) {
      final statusOk = filtroStatusSelecionado == null ||
          textoStatus(doc['status'] ?? 'ok') ==
              filtroStatusSelecionado;

      final tipoOk =
          tipoSelecionado == 'Todos' ||
          doc['tipo'] == tipoSelecionado;

      final vencimento =
          parseData(doc['data_vencimento']);

      final dataInicioOk = dataInicioFiltro == null ||
          (vencimento != null &&
              !vencimento.isBefore(
                DateTime(
                  dataInicioFiltro!.year,
                  dataInicioFiltro!.month,
                  dataInicioFiltro!.day,
                ),
              ));

      final dataFimOk = dataFimFiltro == null ||
          (vencimento != null &&
              !vencimento.isAfter(
                DateTime(
                  dataFimFiltro!.year,
                  dataFimFiltro!.month,
                  dataFimFiltro!.day,
                ),
              ));

      return statusOk &&
          tipoOk &&
          dataInicioOk &&
          dataFimOk;
    }).toList();

    documentosFiltrados.sort((a, b) {
      final prioridadeA =
          prioridadeStatusEmpresa(a['status'] ?? 'ok');
      final prioridadeB =
          prioridadeStatusEmpresa(b['status'] ?? 'ok');

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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  resumoCard(
                    'Regular',
                    regulares,
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
                borderRadius:
                    BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    mostrarFiltros =
                        !mostrarFiltros;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(14),
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
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        mostrarFiltros
                            ? Icons
                                .keyboard_arrow_up_rounded
                            : Icons
                                .keyboard_arrow_down_rounded,
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
                    hintText:
                        'Tipo de documento',
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                              16),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                  items: tiposEmpresa.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      tipoSelecionado =
                          value ?? 'Todos';
                    });
                  },
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap:
                            selecionarDataInicio,
                        child: Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius
                                    .circular(
                                        14),
                          ),
                          child: Text(
                            dataInicioFiltro ==
                                    null
                                ? 'De:'
                                : 'De: ${formatarData(dataInicioFiltro!)}',
                            style:
                                const TextStyle(
                              color: Color(
                                  0xFF1A202C),
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: InkWell(
                        onTap:
                            selecionarDataFim,
                        child: Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius
                                    .circular(
                                        14),
                          ),
                          child: Text(
                            dataFimFiltro ==
                                    null
                                ? 'Até:'
                                : 'Até: ${formatarData(dataFimFiltro!)}',
                            style:
                                const TextStyle(
                              color: Color(
                                  0xFF1A202C),
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Align(
                  alignment:
                      Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        limparFiltros,
                    icon: const Icon(
                      Icons
                          .filter_alt_off_rounded,
                    ),
                    label: const Text(
                      'Limpar filtros',
                    ),
                    style:
                        TextButton.styleFrom(
                      foregroundColor:
                          Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: documentosFiltrados.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum documento da empresa encontrado.',
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.all(18),
                  children:
                      documentosFiltrados
                          .map(documentoCard)
                          .toList(),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          'Documentos da Empresa',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final arquivo = await escolherArquivoDocumentoEmpresa();

                if (arquivo == null) return;

                abrirFormularioDocumentoEmpresaComArquivo(arquivo);
              },
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : AppResponsiveBody(child: listaDocumentos()),
    );
  }
}

class VisualizarDocumentoEmpresaScreen extends StatelessWidget {
  final String imageUrl;

  const VisualizarDocumentoEmpresaScreen({
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

class VisualizarPdfEmpresaScreen extends StatelessWidget {
  final String pdfPath;

  const VisualizarPdfEmpresaScreen({
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
