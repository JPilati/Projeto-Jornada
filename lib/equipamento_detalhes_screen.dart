import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  bool carregando = true;
  Map<String, dynamic>? equipamento;
  List<Map<String, dynamic>> documentos = [];

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    try {
      final equipamentoData = await supabase
          .from('equipamentos')
          .select()
          .eq('id', widget.equipamentoId)
          .single();

      final documentosData = await supabase
          .from('documentos')
          .select()
          .eq('equipamento_id', widget.equipamentoId)
          .order('criado_em', ascending: false);

      setState(() {
        equipamento = equipamentoData;
        documentos = List<Map<String, dynamic>>.from(documentosData);
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
    final dias = validade.difference(hoje).inDays;

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

  Future<String?> uploadDocumentoImagem(XFile imagem) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw 'Usuário não autenticado.';
    }

    final bytes = await imagem.readAsBytes();

    final nomeArquivo =
        '${user.id}/equipamentos/${widget.equipamentoId}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('documentos')
        .uploadBinary(
          nomeArquivo,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        )
        .timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw 'Tempo esgotado ao enviar imagem.';
      },
    );

    final url = supabase.storage.from('documentos').getPublicUrl(nomeArquivo);

    if (url.isEmpty) {
      throw 'Não foi possível gerar URL da imagem.';
    }

    return url;
  }

  void abrirImagem(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizarDocumentoEquipamentoScreen(imageUrl: url),
      ),
    );
  }

  Future<void> abrirFormularioDocumento({Map<String, dynamic>? documento}) async {
    final editando = documento != null;

    final tituloController =
        TextEditingController(text: documento?['titulo'] ?? '');
    final categoriaController =
        TextEditingController(text: documento?['categoria'] ?? '');

    final dataTexto = documento?['data_validade'];
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
              if (tituloController.text.trim().isEmpty ||
                  categoriaController.text.trim().isEmpty ||
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
                String? arquivoUrl = documento?['arquivo_url'];

                if (imagemSelecionada != null) {
                  arquivoUrl = await uploadDocumentoImagem(imagemSelecionada!);
                }

                final status = calcularStatus(dataValidade!);

                if (editando) {
                  await supabase.from('documentos').update({
                    'titulo': tituloController.text.trim(),
                    'categoria': categoriaController.text.trim(),
                    'data_validade':
                        dataValidade!.toIso8601String().split('T').first,
                    'status': status,
                    'arquivo_url': arquivoUrl,
                  }).eq('id', documento['id']);
                } else {
                  await supabase.from('documentos').insert({
                    'equipamento_id': widget.equipamentoId,
                    'titulo': tituloController.text.trim(),
                    'categoria': categoriaController.text.trim(),
                    'data_validade':
                        dataValidade!.toIso8601String().split('T').first,
                    'status': status,
                    'arquivo_url': arquivoUrl,
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
                    TextField(
                      controller: tituloController,
                      decoration: inputDecoration('Nome do documento'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoriaController,
                      decoration: inputDecoration('Categoria'),
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
                              editando ? 'SALVAR ALTERAÇÕES' : 'LANÇAR',
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

  String? extrairPathStorage(String? arquivoUrl) {
    if (arquivoUrl == null || arquivoUrl.isEmpty) return null;

    final uri = Uri.parse(arquivoUrl);
    final index = uri.pathSegments.indexOf('documentos');

    if (index == -1 || index + 1 >= uri.pathSegments.length) {
      return null;
    }

    return uri.pathSegments.sublist(index + 1).join('/');
  }

  Future<void> excluirDocumento(Map<String, dynamic> documento) async {
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
                final pathStorage =
                    extrairPathStorage(documento['arquivo_url']?.toString());

                if (pathStorage != null) {
                  await supabase.storage.from('documentos').remove([pathStorage]);
                }

                await supabase
                    .from('documentos')
                    .delete()
                    .eq('id', documento['id']);

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

    final validadeTexto = documento['data_validade'];
    final validade =
        validadeTexto != null ? DateTime.tryParse(validadeTexto.toString()) : null;

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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  const PopupMenuItem(
                    value: 'editar',
                    child: Text('Editar'),
                  ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE87722),
        foregroundColor: Colors.white,
        onPressed: () => abrirFormularioDocumento(),
        child: const Icon(Icons.add),
      ),
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