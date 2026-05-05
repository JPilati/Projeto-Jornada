import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ColaboradoresScreen extends StatefulWidget {
  const ColaboradoresScreen({super.key});

  @override
  State<ColaboradoresScreen> createState() => _ColaboradoresScreenState();
}

class _ColaboradoresScreenState extends State<ColaboradoresScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> colaboradores = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregarColaboradores();
  }

  Future<void> carregarColaboradores() async {
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .order('nome', ascending: true);

      setState(() {
        colaboradores = List<Map<String, dynamic>>.from(data);
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar colaboradores: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirFormularioCadastro({Map<String, dynamic>? usuarioEditando}) {
    final nomeController =
        TextEditingController(text: usuarioEditando?['nome'] ?? '');
    final matriculaController =
        TextEditingController(text: usuarioEditando?['matricula'] ?? '');
    final cargoController =
        TextEditingController(text: usuarioEditando?['cargo'] ?? '');
    final senhaController = TextEditingController();

    String perfilSelecionado = usuarioEditando?['perfil'] ?? 'Operador';
    String statusSelecionado = usuarioEditando?['status'] ?? 'Ativo';

    final bool editando = usuarioEditando != null;

    showModalBottomSheet(
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
                      editando ? 'Editar usuário' : 'Novo usuário',
                      style: const TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: nomeController,
                      decoration: _inputDecoration('Nome completo'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: matriculaController,
                      enabled: !editando,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Matrícula / CPF'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: cargoController,
                      decoration: _inputDecoration('Cargo / Função'),
                    ),
                    const SizedBox(height: 12),

                    if (!editando)
                      TextField(
                        controller: senhaController,
                        obscureText: true,
                        decoration: _inputDecoration('Senha provisória'),
                      ),

                    if (!editando) const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: perfilSelecionado,
                      decoration: _inputDecoration('Tipo de acesso'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Operador',
                          child: Text('Operador'),
                        ),
                        DropdownMenuItem(
                          value: 'Administrador',
                          child: Text('Administrador'),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          perfilSelecionado = value ?? 'Operador';
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: statusSelecionado,
                      decoration: _inputDecoration('Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Ativo',
                          child: Text('Ativo'),
                        ),
                        DropdownMenuItem(
                          value: 'Inativo',
                          child: Text('Inativo'),
                        ),
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
                            matriculaController.text.trim().isEmpty ||
                            cargoController.text.trim().isEmpty ||
                            (!editando &&
                                senhaController.text.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preencha todos os campos.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (editando) {
                          await _editarUsuario(
                            id: usuarioEditando['id'],
                            nome: nomeController.text.trim(),
                            cargo: cargoController.text.trim(),
                            perfil: perfilSelecionado,
                            status: statusSelecionado,
                          );
                        } else {
                          await _cadastrarUsuario(
                            nome: nomeController.text.trim(),
                            matricula: matriculaController.text.trim(),
                            senha: senhaController.text.trim(),
                            cargo: cargoController.text.trim(),
                            perfil: perfilSelecionado,
                            status: statusSelecionado,
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
                        editando ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR USUÁRIO',
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

  Future<void> _cadastrarUsuario({
    required String nome,
    required String matricula,
    required String senha,
    required String cargo,
    required String perfil,
    required String status,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: '$matricula@app.com',
        password: senha,
      );

      final user = response.user;

      if (user == null) {
        throw 'Não foi possível criar o usuário no Auth.';
      }

      await supabase.from('profiles').insert({
        'id': user.id,
        'nome': nome,
        'matricula': matricula,
        'cargo': cargo,
        'perfil': perfil,
        'status': status,
        'precisa_trocar_senha': true,
      });

      await carregarColaboradores();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário cadastrado com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cadastrar usuário: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editarUsuario({
    required String id,
    required String nome,
    required String cargo,
    required String perfil,
    required String status,
  }) async {
    try {
      await supabase.from('profiles').update({
        'nome': nome,
        'cargo': cargo,
        'perfil': perfil,
        'status': status,
      }).eq('id', id);

      await carregarColaboradores();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário atualizado com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao editar usuário: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _alternarStatus(Map<String, dynamic> usuario) async {
    final novoStatus = usuario['status'] == 'Ativo' ? 'Inativo' : 'Ativo';

    try {
      await supabase.from('profiles').update({
        'status': novoStatus,
      }).eq('id', usuario['id']);

      await carregarColaboradores();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao alterar status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excluirUsuario(Map<String, dynamic> usuario) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Deseja excluir ${usuario['nome']} da lista?'),
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
                    .from('profiles')
                    .delete()
                    .eq('id', usuario['id']);

                await carregarColaboradores();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usuário removido da lista.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao excluir usuário: $e'),
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

  InputDecoration _inputDecoration(String label) {
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

  Color _statusColor(String status) {
    return status == 'Ativo'
        ? const Color(0xFF43A047)
        : const Color(0xFFE53935);
  }

  Color _perfilColor(String perfil) {
    return perfil == 'Administrador'
        ? const Color(0xFFE87722)
        : const Color(0xFF1976D2);
  }

  Widget _buildColaboradorCard(Map<String, dynamic> usuario) {
    final perfil = usuario['perfil'] ?? 'Operador';
    final status = usuario['status'] ?? 'Ativo';

    return Container(
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
          CircleAvatar(
            radius: 26,
            backgroundColor: _perfilColor(perfil).withOpacity(0.15),
            child: Icon(
              perfil == 'Administrador'
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              color: _perfilColor(perfil),
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
                const SizedBox(height: 3),
                Text(
                  usuario['cargo'] ?? '',
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
                if (usuario['precisa_trocar_senha'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Senha provisória',
                      style: TextStyle(
                        color: Color(0xFFE87722),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _perfilColor(perfil).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  perfil,
                  style: TextStyle(
                    color: _perfilColor(perfil),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'editar') {
                    _abrirFormularioCadastro(usuarioEditando: usuario);
                  }

                  if (value == 'status') {
                    _alternarStatus(usuario);
                  }

                  if (value == 'excluir') {
                    _excluirUsuario(usuario);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Text(
                      status == 'Ativo' ? 'Desativar' : 'Ativar',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir da lista'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumo(String valor, String titulo, Color cor) {
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
              valor,
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

  @override
  Widget build(BuildContext context) {
    final total = colaboradores.length;
    final ativos =
        colaboradores.where((user) => user['status'] == 'Ativo').length;
    final admins = colaboradores
        .where((user) => user['perfil'] == 'Administrador')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Colaboradores',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormularioCadastro(),
        backgroundColor: const Color(0xFFE87722),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(26),
              ),
            ),
            child: Row(
              children: [
                _buildResumo(
                  total.toString(),
                  'Total',
                  const Color(0xFF1976D2),
                ),
                const SizedBox(width: 10),
                _buildResumo(
                  ativos.toString(),
                  'Ativos',
                  const Color(0xFF43A047),
                ),
                const SizedBox(width: 10),
                _buildResumo(
                  admins.toString(),
                  'Admins',
                  const Color(0xFFE87722),
                ),
              ],
            ),
          ),

          Expanded(
            child: carregando
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : colaboradores.isEmpty
                    ? const Center(
                        child: Text('Nenhum colaborador cadastrado.'),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(18),
                        children:
                            colaboradores.map(_buildColaboradorCard).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}