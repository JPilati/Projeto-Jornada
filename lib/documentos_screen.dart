import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  bool carregando = true;
  bool isAdmin = false;

  List<Map<String, dynamic>> documentos = [];
  List<Map<String, dynamic>> usuarios = [];

  Map<String, Map<String, int>> resumoPorUsuario = {};

  String? usuarioSelecionadoId;
  String? usuarioSelecionadoNome;

  @override
  void initState() {
    super.initState();
    carregarDadosIniciais();
  }

  Future<void> carregarDadosIniciais() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('perfil')
          .eq('id', user.id)
          .single();

      isAdmin = profile['perfil'] == 'Administrador';

      if (isAdmin) {
        await carregarUsuariosParaAdmin();
      } else {
        usuarioSelecionadoId = user.id;
        await carregarDocumentos(user.id);
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
    final profiles = await supabase
        .from('profiles')
        .select('id, nome, matricula, cargo')
        .eq('perfil', 'Operador')
        .order('nome', ascending: true);

    final docs = await supabase.from('documentos').select('usuario_id, status');

    final Map<String, Map<String, int>> contagem = {};

    for (final doc in docs) {
      final usuarioId = doc['usuario_id'];
      final status = doc['status'];

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

    final lista = List<Map<String, dynamic>>.from(profiles);

    lista.sort((a, b) {
      final aResumo = contagem[a['id']] ?? {};
      final bResumo = contagem[b['id']] ?? {};

      final aVencido = aResumo['Vencido'] ?? 0;
      final bVencido = bResumo['Vencido'] ?? 0;

      final aAVencer = aResumo['A vencer'] ?? 0;
      final bAVencer = bResumo['A vencer'] ?? 0;

      final aRegular = aResumo['Regular'] ?? 0;
      final bRegular = bResumo['Regular'] ?? 0;

      if (bVencido != aVencido) return bVencido - aVencido;
      if (bAVencer != aAVencer) return bAVencer - aAVencer;
      if (bRegular != aRegular) return bRegular - aRegular;

      return (a['nome'] ?? '')
          .toString()
          .compareTo((b['nome'] ?? '').toString());
    });

    setState(() {
      usuarios = lista;
      resumoPorUsuario = contagem;
    });
  }

  Future<void> carregarDocumentos(String usuarioId) async {
    final data = await supabase
        .from('documentos')
        .select()
        .eq('usuario_id', usuarioId)
        .order('criado_em', ascending: false);

    setState(() {
      documentos = List<Map<String, dynamic>>.from(data);
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
    final diferenca = validade.difference(hoje).inDays;

    if (diferenca < 0) return 'Vencido';
    if (diferenca <= 30) return 'A vencer';
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

  Future<XFile?> escolherImagem() async {
    return picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
  }

  Future<String?> uploadDocumentoImagem(XFile imagem) async {
    final usuarioId = usuarioSelecionadoId ?? supabase.auth.currentUser?.id;

    if (usuarioId == null) {
      throw 'Usuário não encontrado para upload.';
    }

    final bytes = await imagem.readAsBytes();

    final nomeArquivo =
        '$usuarioId/${DateTime.now().millisecondsSinceEpoch}.jpg';

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
        builder: (_) => VisualizarDocumentoScreen(imageUrl: url),
      ),
    );
  }

  Future<void> abrirFormularioDocumento({
    Map<String, dynamic>? documento,
  }) async {
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

                if (editando) {
                  await editarDocumento(
                    id: documento['id'],
                    titulo: tituloController.text.trim(),
                    categoria: categoriaController.text.trim(),
                    validade: dataValidade!,
                    arquivoUrl: arquivoUrl,
                  );
                } else {
                  await cadastrarDocumento(
                    titulo: tituloController.text.trim(),
                    categoria: categoriaController.text.trim(),
                    validade: dataValidade!,
                    arquivoUrl: arquivoUrl,
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
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw 'Usuário não autenticado.';
    }

    final usuarioId = isAdmin ? usuarioSelecionadoId : user.id;

    if (usuarioId == null) {
      throw 'Usuário selecionado não encontrado.';
    }

    final status = calcularStatus(validade);

    await supabase.from('documentos').insert({
      'usuario_id': usuarioId,
      'titulo': titulo,
      'categoria': categoria,
      'data_validade': validade.toIso8601String().split('T').first,
      'status': status,
      'arquivo_url': arquivoUrl,
    });

    await carregarDocumentos(usuarioId);

    if (isAdmin) {
      await carregarUsuariosParaAdmin();
    }

    mostrarSucesso('Documento lançado com sucesso.');
  }

  Future<void> editarDocumento({
    required String id,
    required String titulo,
    required String categoria,
    required DateTime validade,
    required String? arquivoUrl,
  }) async {
    final status = calcularStatus(validade);

    await supabase.from('documentos').update({
      'titulo': titulo,
      'categoria': categoria,
      'data_validade': validade.toIso8601String().split('T').first,
      'status': status,
      'arquivo_url': arquivoUrl,
    }).eq('id', id);

    if (usuarioSelecionadoId != null) {
      await carregarDocumentos(usuarioSelecionadoId!);
    }

    if (isAdmin) {
      await carregarUsuariosParaAdmin();
    }

    mostrarSucesso('Documento atualizado com sucesso.');
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
                  await supabase.storage
                      .from('documentos')
                      .remove([pathStorage]);
                }

                await supabase
                    .from('documentos')
                    .delete()
                    .eq('id', documento['id']);

                if (usuarioSelecionadoId != null) {
                  await carregarDocumentos(usuarioSelecionadoId!);
                }

                if (isAdmin) {
                  await carregarUsuariosParaAdmin();
                }

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

  Widget resumoCard(String titulo, int quantidade, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              quantidade.toString(),
              style: TextStyle(
                color: cor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              titulo,
              style: TextStyle(
                color: cor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

    final validadeString = documento['data_validade'];
    DateTime? validade;

    if (validadeString != null) {
      validade = DateTime.tryParse(validadeString.toString());
    }

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

  Widget listaUsuariosAdmin() {
    return usuarios.isEmpty
        ? const Center(child: Text('Nenhum operador encontrado.'))
        : ListView(
            padding: const EdgeInsets.all(18),
            children: usuarios.map(usuarioCard).toList(),
          );
  }

  Widget listaDocumentos() {
    final regular =
        documentos.where((doc) => doc['status'] == 'Regular').length;
    final aVencer =
        documentos.where((doc) => doc['status'] == 'A vencer').length;
    final vencidos =
        documentos.where((doc) => doc['status'] == 'Vencido').length;

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
                    'Vencidos',
                    vencidos,
                    const Color(0xFFE53935),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: documentos.isEmpty
              ? const Center(child: Text('Nenhum documento lançado.'))
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: documentos.map(documentoCard).toList(),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminNaListaUsuarios = isAdmin && usuarioSelecionadoId == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
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
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: isAdmin && usuarioSelecionadoId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    usuarioSelecionadoId = null;
                    usuarioSelecionadoNome = null;
                    documentos = [];
                  });
                },
              )
            : null,
      ),
      floatingActionButton: adminNaListaUsuarios
          ? null
          : FloatingActionButton(
              onPressed: () => abrirFormularioDocumento(),
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              child: const Icon(Icons.camera_alt_rounded),
            ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : adminNaListaUsuarios
              ? listaUsuariosAdmin()
              : listaDocumentos(),
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