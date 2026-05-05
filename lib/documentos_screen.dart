import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final supabase = Supabase.instance.client;

  bool carregando = true;
  bool isAdmin = false;

  List<Map<String, dynamic>> documentos = [];
  List<Map<String, dynamic>> usuarios = [];
  Map<String, int> totalDocsPorUsuario = {};

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> carregarUsuariosParaAdmin() async {
    final profiles = await supabase
        .from('profiles')
        .select('id, nome, matricula, cargo, perfil, status')
        .eq('perfil', 'Operador')
        .order('nome', ascending: true);

    final docs = await supabase.from('documentos').select('usuario_id');

    final Map<String, int> contagem = {};

    for (final doc in docs) {
      final usuarioId = doc['usuario_id'];
      if (usuarioId != null) {
        contagem[usuarioId] = (contagem[usuarioId] ?? 0) + 1;
      }
    }

    setState(() {
      usuarios = List<Map<String, dynamic>>.from(profiles);
      totalDocsPorUsuario = contagem;
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

  Future<void> abrirFormularioDocumento({Map<String, dynamic>? documento}) async {
    final editando = documento != null;

    final tituloController =
        TextEditingController(text: documento?['titulo'] ?? '');
    final categoriaController =
        TextEditingController(text: documento?['categoria'] ?? '');

    DateTime? dataValidade = documento?['data_validade'] != null
        ? DateTime.tryParse(documento!['data_validade'])
        : null;

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
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: () async {
                        if (tituloController.text.trim().isEmpty ||
                            categoriaController.text.trim().isEmpty ||
                            dataValidade == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preencha todos os campos.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (editando) {
                          await editarDocumento(
                            id: documento['id'],
                            titulo: tituloController.text.trim(),
                            categoria: categoriaController.text.trim(),
                            validade: dataValidade!,
                          );
                        } else {
                          await cadastrarDocumento(
                            titulo: tituloController.text.trim(),
                            categoria: categoriaController.text.trim(),
                            validade: dataValidade!,
                          );
                        }

                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE87722),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        editando ? 'SALVAR ALTERAÇÕES' : 'LANÇAR DOCUMENTO',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final usuarioId = isAdmin ? usuarioSelecionadoId : user.id;

    if (usuarioId == null) return;

    try {
      final status = calcularStatus(validade);

      await supabase.from('documentos').insert({
        'usuario_id': usuarioId,
        'titulo': titulo,
        'categoria': categoria,
        'data_validade': validade.toIso8601String().split('T').first,
        'status': status,
      });

      await carregarDocumentos(usuarioId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento lançado com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao lançar documento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editarDocumento({
    required String id,
    required String titulo,
    required String categoria,
    required DateTime validade,
  }) async {
    try {
      final status = calcularStatus(validade);

      await supabase.from('documentos').update({
        'titulo': titulo,
        'categoria': categoria,
        'data_validade': validade.toIso8601String().split('T').first,
        'status': status,
      }).eq('id', id);

      if (usuarioSelecionadoId != null) {
        await carregarDocumentos(usuarioSelecionadoId!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento atualizado com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao editar documento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                await supabase
                    .from('documentos')
                    .delete()
                    .eq('id', documento['id']);

                if (usuarioSelecionadoId != null) {
                  await carregarDocumentos(usuarioSelecionadoId!);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Documento excluído.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao excluir: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
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

  Widget usuarioCard(Map<String, dynamic> usuario) {
    final total = totalDocsPorUsuario[usuario['id']] ?? 0;

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
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(
                Icons.person,
                color: Color(0xFF43A047),
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
      ),
    );
  }

  Widget documentoCard(Map<String, dynamic> documento) {
    final status = documento['status'] ?? 'Regular';
    final cor = corStatus(status);

    final validadeString = documento['data_validade'];
    DateTime? validade;

    if (validadeString != null) {
      validade = DateTime.tryParse(validadeString);
    }

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
          CircleAvatar(
            backgroundColor: cor.withOpacity(0.15),
            child: Icon(Icons.description, color: cor),
          ),
          const SizedBox(width: 14),
          Expanded(
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
              ],
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
              child: const Icon(Icons.add),
            ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : adminNaListaUsuarios
              ? listaUsuariosAdmin()
              : listaDocumentos(),
    );
  }
}