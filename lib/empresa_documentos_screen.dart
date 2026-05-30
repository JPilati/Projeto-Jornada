import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmpresaDocumentosScreen extends StatefulWidget {
  const EmpresaDocumentosScreen({super.key});

  @override
  State<EmpresaDocumentosScreen> createState() =>
      _EmpresaDocumentosScreenState();
}

class _EmpresaDocumentosScreenState extends State<EmpresaDocumentosScreen> {
  final db = FirebaseFirestore.instance;
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

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
  ];

  final List<String> equipamentosEmpresa = [
    'Balancim',
    'Gaiola 1',
    'Gaiola 2',
    'Gaiola 3',
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

    if (vencimentoSemHora.isBefore(
          hojeSemHora.add(const Duration(days: 30)),
        ) ||
        vencimentoSemHora.isAtSameMomentAs(
          hojeSemHora.add(const Duration(days: 30)),
        )) {
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

  Future<XFile?> escolherImagem() async {
    return picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
  }

  Future<Map<String, String>> uploadImagemEmpresa(XFile imagem) async {
    final bytes = await imagem.readAsBytes();

    final arquivoPath =
        'empresa/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage.from('documentos').uploadBinary(
          arquivoPath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
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

  Future<void> abrirFormularioDocumento({
    Map<String, dynamic>? documento,
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

    XFile? imagemSelecionada;
    Uint8List? imagemBytes;
    bool salvando = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> salvar() async {
              if (tipoSelecionadoForm == null ||
                  equipamentoSelecionado == null ||
                  dataEmissao == null ||
                  dataVencimento == null ||
                  (!editando && imagemSelecionada == null)) {
                mostrarErro('Preencha todos os campos obrigatórios.');
                return;
              }

              setModalState(() {
                salvando = true;
              });

              try {
                String? arquivoUrl = documento?['arquivo_url'];
                String? arquivoPath = documento?['arquivo_path'];

                if (imagemSelecionada != null) {
                  if (editando &&
                      arquivoPath != null &&
                      arquivoPath.isNotEmpty) {
                    await deletarArquivoStorage(arquivoPath);
                  }

                  final upload = await uploadImagemEmpresa(imagemSelecionada!);
                  arquivoUrl = upload['url'];
                  arquivoPath = upload['path'];
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
                        final imagem = await escolherImagem();

                        if (imagem != null) {
                          final bytes = await imagem.readAsBytes();

                          setModalState(() {
                            imagemSelecionada = imagem;
                            imagemBytes = bytes;
                          });
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
                            if (imagemBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  imagemBytes!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else if (editando &&
                                documento['arquivo_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  documento['arquivo_url'].toString(),
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              const Icon(
                                Icons.camera_alt_rounded,
                                size: 48,
                                color: Color(0xFFE87722),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              imagemSelecionada == null
                                  ? 'Tirar foto do documento'
                                  : 'Foto selecionada',
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
            onTap: arquivoUrl != null ? () => abrirImagem(arquivoUrl) : null,
            child: arquivoUrl != null && arquivoUrl.isNotEmpty
                ? ClipRRect(
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
                    child: Icon(Icons.business_rounded, color: cor),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: arquivoUrl != null && arquivoUrl.isNotEmpty
                  ? () => abrirImagem(arquivoUrl)
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
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    hintText:
                        'Tipo de documento',
                    filled: true,
                    fillColor: Colors.white,
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Documentos da Empresa',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => abrirFormularioDocumento(),
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : listaDocumentos(),
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