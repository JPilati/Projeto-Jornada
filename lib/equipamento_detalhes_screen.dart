import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'app_responsive.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'services/mlkit_ocr_service.dart';

class EquipamentoDetalhesScreen extends StatefulWidget {
  final String equipamentoId;

  const EquipamentoDetalhesScreen({
    super.key,
    required this.equipamentoId,
  });

  @override
  State<EquipamentoDetalhesScreen> createState() =>
      _EquipamentoDetalhesScreenState();
}

class _EquipamentoDetalhesScreenState extends State<EquipamentoDetalhesScreen> {
  final db = FirebaseFirestore.instance;
  final supabase = Supabase.instance.client;

  bool carregando = true;
  bool isAdmin = false;
  bool mostrarFiltros = false;
  String tipoSelecionado = 'Todos';
  DateTime? dataInicioFiltro;
  DateTime? dataFimFiltro;
  Map<String, dynamic>? equipamento;
  List<Map<String, dynamic>> documentos = [];
  List<Map<String, dynamic>> operadores = [];

  final List<String> tiposDocumentosEquipamento = [
    'Todos',
    'ART',
    'Licença DER',
    'Licença DNIT',
    'Tacógrafo',
    'CRLV',
    'Seguro',
    'Laudo',
    'Outros',
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

    final profile = profileDoc.data();

    return profile?['perfil'] == 'Administrador';
  }

  Future<void> carregarDados() async {
    try {
      final adminFirestore = await verificarAdminNoFirestore();

      final equipamentoDoc =
          await db.collection('equipamentos').doc(widget.equipamentoId).get();

      if (!equipamentoDoc.exists) {
        throw Exception('Veículo não encontrado.');
      }

      List<Map<String, dynamic>> listaOperadores = [];

      if (adminFirestore) {
        final operadoresSnapshot = await db
            .collection('users')
            .where('perfil', isEqualTo: 'Operador')
            .orderBy('nome')
            .get();

        listaOperadores = operadoresSnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      }

      Query<Map<String, dynamic>> query = db
          .collection('documentos')
          .where('equipamentoId', isEqualTo: widget.equipamentoId)
          .where('tipo', isEqualTo: 'equipamento');

      if (!adminFirestore) {
        query = query.where('visivelOperador', isEqualTo: true);
      }

      final documentosSnapshot = await query.get();

      final listaDocs = documentosSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      listaDocs.sort((a, b) {
        final prioridade = {
          'Vencido': 0,
          'A vencer': 1,
          'Regular': 2,
        };

        final statusA = prioridade[a['status']] ?? 3;
        final statusB = prioridade[b['status']] ?? 3;

        if (statusA != statusB) {
          return statusA.compareTo(statusB);
        }

        final validadeA = DateTime.tryParse(
          a['dataValidade']?.toString() ?? '',
        );

        final validadeB = DateTime.tryParse(
          b['dataValidade']?.toString() ?? '',
        );

        if (validadeA != null && validadeB != null) {
          return validadeA.compareTo(validadeB);
        }

        return (a['titulo'] ?? '')
            .toString()
            .compareTo((b['titulo'] ?? '').toString());
      });

            setState(() {
              isAdmin = adminFirestore;
              equipamento = {
                'id': equipamentoDoc.id,
                ...equipamentoDoc.data()!,
              };
              documentos = listaDocs;
              operadores = listaOperadores;
              carregando = false;
            });
          } catch (e) {
            setState(() {
              carregando = false;
            });

            mostrarErro('Erro ao carregar veículo: $e');
          }
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
    final validadeSemHora =
        DateTime(validade.year, validade.month, validade.day);

    final dias = validadeSemHora.difference(hojeSemHora).inDays;

    if (dias < 0) return 'Vencido';
    if (dias <= appSettings.notificationDays) return 'A vencer';
    return 'Regular';
  }

  Color corStatus(String status) {
    if (status == 'Vencido') return const Color(0xFFE53935);
    if (status == 'A vencer') return const Color(0xFFE87722);
    return const Color(0xFF43A047);
  }

  Color corEquipamento(String status) {
    if (status == 'Manutenção') return const Color(0xFFE87722);
    if (status == 'Inativo') return const Color(0xFFE53935);
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

  Future<PlatformFile?> escolherArquivoDocumentoEquipamento() async {
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

  Future<Map<String, String>> uploadDocumentoEquipamento(
    PlatformFile arquivo,
  ) async {
    final bytes = arquivo.bytes;

    if (bytes == null) {
      throw Exception('Não foi possível ler o arquivo selecionado.');
    }

    final extensao = arquivo.extension?.toLowerCase() ?? 'jpg';

    final arquivoPath =
        'equipamentos/${widget.equipamentoId}/${DateTime.now().millisecondsSinceEpoch}.$extensao';

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
        builder: (_) => VisualizarDocumentoEquipamentoScreen(imageUrl: url),
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
      final file = File('${dir.path}/documento_frota.pdf');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisualizarPdfEquipamentoScreen(pdfPath: file.path),
        ),
      );
    } catch (e) {
      mostrarErro('Erro ao abrir PDF: $e');
    }
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
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await carregarDados();

      mostrarSucesso(
        novoValor
            ? 'Documento visível para operador.'
            : 'Documento oculto para operador.',
      );
    } catch (e) {
      mostrarErro('Erro ao alterar visibilidade: $e');
    }
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

    String? tipoDocumentoSelecionado = documento?['categoria'];

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

    Future<String?> detectarTipoDocumentoEquipamento(
      String texto,
    ) async {
      final t = texto.toLowerCase();

      final regras = <String, List<String>>{
        'CRLV': [
          'crlv',
          'certificado de registro e licenciamento',
          'certificado de registro',
          'licenciamento de veículo',
          'licenciamento de veiculo',
          'renavam',
        ],
        'Tacógrafo': [
          'tacógrafo',
          'tacografo',
          'cronotacógrafo',
          'cronotacografo',
          'inmetro',
          'certificado de verificação',
          'certificado de verificacao',
        ],
        'Licença DNIT': [
          'dnit',
          'departamento nacional de infraestrutura',
          'autorização especial de trânsito',
          'autorizacao especial de transito',
          'aet',
        ],
        'Licença DER': [
          'der',
          'departamento de estradas de rodagem',
          'licença especial',
          'licenca especial',
          'autorização especial',
          'autorizacao especial',
        ],
        'Seguro': [
          'seguro',
          'apólice',
          'apolice',
          'seguradora',
          'cobertura',
        ],
        'Laudo': [
          'laudo',
          'inspeção',
          'inspecao',
          'vistoria',
          'parecer técnico',
          'parecer tecnico',
        ],
        'ART': [
          'anotação de responsabilidade técnica',
          'anotacao de responsabilidade tecnica',
          'art nº',
          'art n°',
          'registro art',
          'número da art',
          'numero da art',
          'crea',
        ],
      };

      String melhorTipo = 'Outros';
      int melhorPontuacao = 0;

      regras.forEach((tipo, palavras) {
        int pontuacao = 0;

        for (final palavra in palavras) {
          if (t.contains(palavra)) {
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

      return melhorPontuacao == 0 ? 'Outros' : melhorTipo;
    }

    Future<void> analisarDocumentoEquipamento(
      PlatformFile arquivo,
      void Function(void Function()) setModalState,
    ) async {
      setModalState(() {
        analisandoOCR = true;
      });

      try {
        final recognizedText = await MlkitOcrService.reconhecerTexto(arquivo);

        if (recognizedText == null) {
          setModalState(() {
            analisandoOCR = false;
          });
          return;
        }

        final textoOriginal = recognizedText.text;
        final texto = textoOriginal.toLowerCase();

        final tipoDetectado = await detectarTipoDocumentoEquipamento(texto);

        final regexData = RegExp(r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b');
        final matches = regexData.allMatches(textoOriginal).toList();

        DateTime? melhorData;

        for (final match in matches) {
          final dia = int.tryParse(match.group(1) ?? '');
          final mes = int.tryParse(match.group(2) ?? '');
          final ano = int.tryParse(match.group(3) ?? '');

          if (dia == null || mes == null || ano == null) continue;
          if (dia < 1 || dia > 31 || mes < 1 || mes > 12 || ano < 2000) {
            continue;
          }

          final data = DateTime.tryParse(
            '${ano.toString().padLeft(4, '0')}-'
            '${mes.toString().padLeft(2, '0')}-'
            '${dia.toString().padLeft(2, '0')}',
          );

          if (data == null) continue;

          final inicio = (match.start - 80).clamp(0, texto.length);
          final fim = (match.end + 40).clamp(0, texto.length);
          final contexto = texto.substring(inicio, fim);

          int pontuacao = 0;

          if (contexto.contains('validade')) pontuacao += 15;
          if (contexto.contains('vencimento')) pontuacao += 15;
          if (contexto.contains('vence')) pontuacao += 10;
          if (contexto.contains('válido até')) pontuacao += 15;
          if (contexto.contains('valido ate')) pontuacao += 15;

          final hoje = DateTime.now();
          final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

          if (data.isAfter(hojeSemHora)) {
            pontuacao += 5;
          } else {
            pontuacao -= 5;
          }

          if (melhorData == null || pontuacao > 0) {
            melhorData = data;
          }
        }

        setModalState(() {
          if (tipoDetectado != null) {
            tipoDocumentoSelecionado = tipoDetectado;
          }

          if (melhorData != null) {
            dataValidade = melhorData;
          }

          analisandoOCR = false;
        });

        if (tipoDetectado != null || melhorData != null) {
          mostrarSucesso('Dados detectados automaticamente.');
        }
      } catch (e) {
        setModalState(() {
          analisandoOCR = false;
        });

        mostrarErro('Erro ao analisar documento: $e');
      }
    }

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
                await analisarDocumentoEquipamento(
                  arquivoInicial,
                  setModalState,
                );
              });
            }

            Future<void> salvar() async {
              if (tipoDocumentoSelecionado == null ||
                  dataValidade == null ||
                  (!editando && arquivoSelecionado == null)) {
                mostrarErro(
                  'Preencha todos os campos e tire a foto do documento.',
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

                  final upload = await uploadDocumentoEquipamento(
                    arquivoSelecionado!,
                  );

                  arquivoUrl = upload['url'];
                  arquivoPath = upload['path'];
                  arquivoTipo = upload['tipo'];
                  arquivoNome = upload['nome'];
                }

                final status = calcularStatus(dataValidade!);

                if (editando) {
                  await db.collection('documentos').doc(documento['id']).update({
                    'titulo': tipoDocumentoSelecionado,
                    'categoria': tipoDocumentoSelecionado,
                    'dataValidade':
                        dataValidade!.toIso8601String().split('T').first,
                    'status': status,
                    'arquivoUrl': arquivoUrl,
                    'arquivoPath': arquivoPath,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'arquivoTipo': arquivoTipo,
                    'arquivoNome': arquivoNome,
                  });
                } else {
                  await db.collection('documentos').add({
                    'usuarioId': null,
                    'equipamentoId': widget.equipamentoId,
                    'tipo': 'equipamento',
                    'titulo': tipoDocumentoSelecionado,
                    'categoria': tipoDocumentoSelecionado,
                    'dataValidade':
                        dataValidade!.toIso8601String().split('T').first,
                    'status': status,
                    'arquivoUrl': arquivoUrl,
                    'arquivoPath': arquivoPath,
                    'visivelOperador': true,
                    'createdAt': FieldValue.serverTimestamp(),
                    'arquivoTipo': arquivoTipo,
                    'arquivoNome': arquivoNome,
                  });
                }

                await carregarDados();

                if (mounted) Navigator.pop(context);

                mostrarSucesso(
                  editando
                      ? 'Documento atualizado com sucesso.'
                      : 'Documento lançado com sucesso.',
                );
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
                      editando ? 'Editar documento' : 'Documento do veículo',
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
                      value: tipoDocumentoSelecionado,
                      hint: const Text('Escolher tipo de documento'),
                      decoration: inputDecoration('Tipo de documento'),
                      items: tiposDocumentosEquipamento
                          .where((tipo) => tipo != 'Todos')
                          .map((tipo) {
                        return DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tipoDocumentoSelecionado = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    InkWell(
                      onTap: () async {
                        final data = await showDatePicker(
                          context: context,
                          initialDate: dataValidade ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );

                        if (data != null) {
                          setModalState(() {
                            dataValidade = data;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          dataValidade == null
                              ? 'Selecionar data de validade'
                              : 'Validade: ${formatarData(dataValidade!)}',
                          style: TextStyle(
                            color: dataValidade == null
                                ? const Color(0xFF718096)
                                : const Color(0xFF1A202C),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    InkWell(
                      onTap: () async {
                        final arquivo = await escolherArquivoDocumentoEquipamento();

                        if (arquivo != null) {
                          final tipoArquivo =
                              arquivo.extension?.toLowerCase() == 'pdf' ? 'pdf' : 'imagem';

                          setModalState(() {
                            arquivoSelecionado = arquivo;
                            arquivoBytes = arquivo.bytes;
                            arquivoTipoSelecionado = tipoArquivo;
                          });
                          if (tipoArquivo == 'imagem') {
                            await analisarDocumentoEquipamento(arquivo, setModalState);
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
                            else if (editando && documento['arquivoUrl'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  documento['arquivoUrl'].toString(),
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else
                              const Icon(
                                Icons.upload_file_rounded,
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
                              editando ? 'SALVAR ALTERAÇÕES' : 'LANÇAR',
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
                final adminExcluir = await verificarAdminNoFirestore();

                if (!adminExcluir) {
                  throw Exception('Acesso somente leitura para operadores.');
                }

                await deletarArquivoStorage(
                  documento['arquivoPath']?.toString(),
                );

                await db.collection('documentos').doc(documento['id']).delete();

                await carregarDados();

                mostrarSucesso('Documento excluído completamente.');
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
  Future<void> abrirFormularioVeiculo() async {
    final nomeController = TextEditingController(text: equipamento?['nome'] ?? '');
    final tipoController = TextEditingController(text: equipamento?['tipo'] ?? '');
    final placaController = TextEditingController(text: equipamento?['placa'] ?? '');
    final capacidadeController =
        TextEditingController(text: equipamento?['capacidade'] ?? '');

    String statusSelecionado = equipamento?['status'] ?? 'Ativo';

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
                    const Text(
                      'Editar veículo',
                      style: TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: nomeController,
                      decoration: inputDecoration('Nome do veículo'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: tipoController,
                      decoration: inputDecoration('Tipo'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: placaController,
                      decoration: inputDecoration('Placa'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: capacidadeController,
                      decoration: inputDecoration('Capacidade'),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: statusSelecionado,
                      decoration: inputDecoration('Status'),
                      items: const [
                        DropdownMenuItem(value: 'Ativo', child: Text('Ativo')),
                        DropdownMenuItem(
                          value: 'Manutenção',
                          child: Text('Manutenção'),
                        ),
                        DropdownMenuItem(value: 'Inativo', child: Text('Inativo')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          statusSelecionado = value ?? 'Ativo';
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    ElevatedButton(
                      onPressed: () async {
                        if (nomeController.text.trim().isEmpty ||
                            tipoController.text.trim().isEmpty ||
                            placaController.text.trim().isEmpty) {
                          mostrarErro('Preencha os campos principais.');
                          return;
                        }

                        try {
                          await db
                              .collection('equipamentos')
                              .doc(widget.equipamentoId)
                              .update({
                            'nome': nomeController.text.trim(),
                            'tipo': tipoController.text.trim(),
                            'placa': placaController.text.trim(),
                            'capacidade': capacidadeController.text.trim(),
                            'status': statusSelecionado,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          await carregarDados();

                          if (mounted) Navigator.pop(context);

                          mostrarSucesso('Veículo atualizado com sucesso.');
                        } catch (e) {
                          mostrarErro('Erro ao atualizar veículo: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE87722),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'SALVAR ALTERAÇÕES',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  
  Future<void> excluirVeiculo() async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      mostrarErro('Acesso somente leitura para operadores.');
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir veículo'),
        content: Text('Deseja excluir "${equipamento?['nome'] ?? 'veículo'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final docs = await db
                    .collection('documentos')
                    .where('equipamentoId', isEqualTo: widget.equipamentoId)
                    .where('tipo', isEqualTo: 'equipamento')
                    .get();

                if (docs.docs.isNotEmpty) {
                  mostrarErro(
                    'Não é possível excluir: este veículo possui documentos vinculados.',
                  );
                  return;
                }

                await db
                    .collection('equipamentos')
                    .doc(widget.equipamentoId)
                    .delete();

                mostrarSucesso('Veículo excluído.');

                if (mounted) Navigator.pop(context);
              } catch (e) {
                mostrarErro('Erro ao excluir veículo: $e');
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Widget infoCard() {
    final status = equipamento?['status'] ?? 'Ativo';
    final cor = corEquipamento(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF12365A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  equipamento?['nome'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                  ),
                  onSelected: (value) {
                    if (value == 'editar') {
                      abrirFormularioVeiculo();
                    }

                    if (value == 'excluir') {
                      excluirVeiculo();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar veículo'),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir veículo'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            equipamento?['tipo'] ?? '',
            style: const TextStyle(
              color: Color(0xFFCBD5E0),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: infoItem('Placa', equipamento?['placa'] ?? '-'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: infoItem(
                  'Capacidade',
                  equipamento?['capacidade'] ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget infoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2F46),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E0),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget documentoCard(Map<String, dynamic> documento) {
    final status = documento['status'] ?? 'Regular';
    final cor = corStatus(status);

    final validadeTexto = documento['dataValidade'];
    final validade = validadeTexto != null
        ? DateTime.tryParse(validadeTexto.toString())
        : null;

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
                ? () => arquivoEhPdf ? abrirPdf(arquivoUrl) : abrirImagem(arquivoUrl)
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
                  ? () => arquivoEhPdf ? abrirPdf(arquivoUrl) : abrirImagem(arquivoUrl)
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
                  Text(
                    validade == null
                        ? 'Sem validade'
                        : 'Validade: ${formatarData(validade)}',
                    style: TextStyle(
                      color: cor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (arquivoUrl != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      arquivoEhPdf ? 'PDF anexado' : 'Toque para abrir imagem',
                      style: const TextStyle(
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
  Future<void> gerenciarOperadoresAutorizados() async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      mostrarErro('Acesso somente leitura para operadores.');
      return;
    }

    List<String> operadoresSelecionados =
        List<String>.from(equipamento?['operadoresPermitidos'] ?? []);

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
                    const Text(
                      'Gerenciar operadores',
                      style: TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecione os operadores que podem acessar este veículo.',
                      style: TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (operadores.isEmpty)
                      const Text(
                        'Nenhum operador cadastrado.',
                        style: TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 13,
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: operadores.map((operador) {
                            final operadorId = operador['id'].toString();
                            final nomeOperador =
                                operador['nome'] ?? 'Operador';

                            final selecionado =
                                operadoresSelecionados.contains(operadorId);

                            return CheckboxListTile(
                              value: selecionado,
                              activeColor: const Color(0xFFE87722),
                              title: Text(
                                nomeOperador,
                                style: const TextStyle(
                                  color: Color(0xFF1A202C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                operador['cargo'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF718096),
                                  fontSize: 12,
                                ),
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == true) {
                                    operadoresSelecionados.add(operadorId);
                                  } else {
                                    operadoresSelecionados.remove(operadorId);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 22),

                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await db
                              .collection('equipamentos')
                              .doc(widget.equipamentoId)
                              .update({
                            'operadoresPermitidos': operadoresSelecionados,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          await carregarDados();

                          if (mounted) Navigator.pop(context);

                          mostrarSucesso(
                            'Operadores atualizados com sucesso.',
                          );
                        } catch (e) {
                          mostrarErro('Erro ao atualizar operadores: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE87722),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'SALVAR OPERADORES',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  Widget operadoresAutorizadosSection() {
    final operadoresPermitidos =
        List<String>.from(equipamento?['operadoresPermitidos'] ?? []);

    final operadoresVinculados = operadores.where((operador) {
      return operadoresPermitidos.contains(operador['id'].toString());
    }).toList();

    final total = operadoresVinculados.length;
    final primeiros = operadoresVinculados.take(3).toList();
    final restantes = total - primeiros.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operadores autorizados',
                      style: TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quem pode acessar este veículo.',
                      style: TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: gerenciarOperadoresAutorizados,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE87722),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Gerenciar'),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (total == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Nenhum operador autorizado.',
                style: TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 13,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...primeiros.map((operador) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      operador['nome'] ?? 'Operador',
                      style: const TextStyle(
                        color: Color(0xFF43A047),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),

                if (restantes > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '+$restantes operadores',
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget documentosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documentos do veículo',
          style: TextStyle(
            color: Color(0xFF1A202C),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        if (documentos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Nenhum documento lançado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718096)),
            ),
          )
        else
          ...documentos.map(documentoCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          'Detalhes do Veículo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              onPressed: () async {
                final arquivo = await escolherArquivoDocumentoEquipamento();

                if (arquivo == null) return;

                await abrirFormularioDocumento(arquivoInicial: arquivo);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : AppResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  infoCard(),
                  if (isAdmin) operadoresAutorizadosSection(),
                  documentosSection(),
                ],
              ),
            ),
    );
  }
}

class VisualizarDocumentoEquipamentoScreen extends StatelessWidget {
  final String imageUrl;

  const VisualizarDocumentoEquipamentoScreen({
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

              return const CircularProgressIndicator(
                color: Colors.white,
              );
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
class VisualizarPdfEquipamentoScreen extends StatelessWidget {
  final String pdfPath;

  const VisualizarPdfEquipamentoScreen({
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
