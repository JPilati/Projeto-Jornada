import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  final picker = ImagePicker();

  bool carregando = true;
  bool isAdmin = false;

  Map<String, dynamic>? equipamento;
  List<Map<String, dynamic>> documentos = [];
  String tipoSelecionado = 'Todos';
  DateTime? dataInicioFiltro;
  DateTime? dataFimFiltro;
  bool mostrarFiltros = false;

  final List<String> tiposDocumentosEquipamento = [
    'Todos',
    'ART',
    'Licença DER',
    'Licença DNIT',
    'Tacógrafo',
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

      final documentosSnapshot = await db
          .collection('documentos')
          .where('equipamentoId', isEqualTo: widget.equipamentoId)
          .where('tipo', isEqualTo: 'equipamento')
          .get();

      final listaDocs = documentosSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      listaDocs.sort((a, b) {
        final aCreated = a['createdAt'];
        final bCreated = b['createdAt'];

        if (aCreated is Timestamp && bCreated is Timestamp) {
          return bCreated.compareTo(aCreated);
        }

        return 0;
      });

      setState(() {
        isAdmin = adminFirestore;
        equipamento = {
          'id': equipamentoDoc.id,
          ...equipamentoDoc.data()!,
        };
        documentos = listaDocs;
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
    if (dias <= 30) return 'A vencer';
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

  Future<XFile?> escolherImagem() async {
    return picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
  }

  Future<Map<String, String>> uploadDocumentoImagem(XFile imagem) async {
    final bytes = await imagem.readAsBytes();

    final arquivoPath =
        'equipamentos/${widget.equipamentoId}/${DateTime.now().millisecondsSinceEpoch}.jpg';

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
      throw Exception('Não foi possível gerar URL da imagem.');
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
        builder: (_) => VisualizarDocumentoEquipamentoScreen(imageUrl: url),
      ),
    );
  }

  Future<void> abrirFormularioDocumento({
    Map<String, dynamic>? documento,
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
              if (tipoDocumentoSelecionado == null ||
                  dataValidade == null ||
                  (!editando && imagemSelecionada == null)) {
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

                if (imagemSelecionada != null) {
                  if (editando &&
                      arquivoPath != null &&
                      arquivoPath.isNotEmpty) {
                    await deletarArquivoStorage(arquivoPath);
                  }

                  final upload = await uploadDocumentoImagem(imagemSelecionada!);
                  arquivoUrl = upload['url'];
                  arquivoPath = upload['path'];
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
                    'createdAt': FieldValue.serverTimestamp(),
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
                          border: Border.all(color: const Color(0xFFDDE3EC)),
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
          Text(
            equipamento?['nome'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
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

  Widget qrCard() {
    final qrTexto = 'EQUIPAMENTO:${widget.equipamentoId}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          QrImageView(
            data: qrTexto,
            version: QrVersions.auto,
            size: 190,
          ),
          const SizedBox(height: 12),
          const Text(
            'QR Code do veículo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            qrTexto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF718096),
              fontSize: 12,
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
            child: arquivoUrl != null
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
                    child: Icon(Icons.description, color: cor),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: arquivoUrl != null ? () => abrirImagem(arquivoUrl) : null,
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
                  if (arquivoUrl != null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Toque para abrir imagem',
                      style: TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 11,
                      ),
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
                    abrirImagem(arquivoUrl);
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
                    const PopupMenuItem(
                      value: 'abrir',
                      child: Text('Abrir imagem'),
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Detalhes do Veículo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              onPressed: () => abrirFormularioDocumento(),
              child: const Icon(Icons.add),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                infoCard(),
                qrCard(),
                documentosSection(),
              ],
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