import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'equipamento_detalhes_screen.dart';

class EquipamentosScreen extends StatefulWidget {
  const EquipamentosScreen({super.key});

  @override
  State<EquipamentosScreen> createState() => _EquipamentosScreenState();
}

class _EquipamentosScreenState extends State<EquipamentosScreen> {
  final db = FirebaseFirestore.instance;

  bool carregando = true;
  bool isAdmin = false;

  List<Map<String, dynamic>> equipamentos = [];

  @override
  void initState() {
    super.initState();
    carregarTela();
  }

  Future<bool> verificarAdminNoFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final profileDoc = await db.collection('users').doc(user.uid).get();

    if (!profileDoc.exists) return false;

    final profile = profileDoc.data();

    return profile?['perfil'] == 'Administrador';
  }

  Future<void> carregarTela() async {
    try {
      final adminFirestore = await verificarAdminNoFirestore();

      final snapshot = await db.collection('equipamentos').orderBy('nome').get();

      setState(() {
        isAdmin = adminFirestore;
        equipamentos = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
      });

      mostrarErro('Erro ao carregar equipamentos: $e');
    }
  }

  Future<void> carregarEquipamentos() async {
    await carregarTela();
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

  Future<void> abrirFormulario({Map<String, dynamic>? equipamento}) async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      mostrarErro('Acesso somente leitura para operadores.');
      return;
    }

    final editando = equipamento != null;

    final nomeController =
        TextEditingController(text: equipamento?['nome'] ?? '');
    final tipoController =
        TextEditingController(text: equipamento?['tipo'] ?? '');
    final placaController =
        TextEditingController(text: equipamento?['placa'] ?? '');
    final capacidadeController =
        TextEditingController(text: equipamento?['capacidade'] ?? '');

    String statusSelecionado = equipamento?['status'] ?? 'Ativo';

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
                      editando ? 'Editar veículo' : 'Cadastrar veículo',
                      style: const TextStyle(
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
                        DropdownMenuItem(
                          value: 'Ativo',
                          child: Text('Ativo'),
                        ),
                        DropdownMenuItem(
                          value: 'Manutenção',
                          child: Text('Manutenção'),
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
                            tipoController.text.trim().isEmpty ||
                            placaController.text.trim().isEmpty) {
                          mostrarErro('Preencha os campos principais.');
                          return;
                        }

                        try {
                          final adminSalvar =
                              await verificarAdminNoFirestore();

                          if (!adminSalvar) {
                            throw Exception(
                              'Acesso somente leitura para operadores.',
                            );
                          }

                          if (editando) {
                            await db
                                .collection('equipamentos')
                                .doc(equipamento['id'])
                                .update({
                              'nome': nomeController.text.trim(),
                              'tipo': tipoController.text.trim(),
                              'placa': placaController.text.trim(),
                              'capacidade': capacidadeController.text.trim(),
                              'status': statusSelecionado,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await db.collection('equipamentos').add({
                              'nome': nomeController.text.trim(),
                              'tipo': tipoController.text.trim(),
                              'placa': placaController.text.trim(),
                              'capacidade': capacidadeController.text.trim(),
                              'status': statusSelecionado,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }

                          await carregarEquipamentos();

                          if (mounted) Navigator.pop(context);

                          mostrarSucesso(
                            editando
                                ? 'Veículo atualizado com sucesso.'
                                : 'Veículo cadastrado com sucesso.',
                          );
                        } catch (e) {
                          mostrarErro('Erro ao salvar veículo: $e');
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
                      child: Text(
                        editando ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR VEÍCULO',
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

  Color statusColor(String status) {
    if (status == 'Manutenção') return const Color(0xFFE87722);
    if (status == 'Inativo') return const Color(0xFFE53935);
    return const Color(0xFF43A047);
  }

  Future<void> excluirEquipamento(Map<String, dynamic> equipamento) async {
    final adminFirestore = await verificarAdminNoFirestore();

    if (!adminFirestore) {
      mostrarErro('Acesso somente leitura para operadores.');
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir veículo'),
        content: Text('Deseja excluir "${equipamento['nome']}"?'),
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
                  throw Exception(
                    'Acesso somente leitura para operadores.',
                  );
                }

                final docs = await db
                    .collection('documentos')
                    .where('equipamentoId', isEqualTo: equipamento['id'])
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
                    .doc(equipamento['id'])
                    .delete();

                await carregarEquipamentos();

                mostrarSucesso('Veículo excluído.');
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

  Widget equipamentoCard(Map<String, dynamic> equipamento) {
    final status = equipamento['status'] ?? 'Ativo';
    final cor = statusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EquipamentoDetalhesScreen(
              equipamentoId: equipamento['id'],
            ),
          ),
        ).then((_) => carregarEquipamentos());
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
            CircleAvatar(
              radius: 28,
              backgroundColor: cor.withOpacity(0.15),
              child: Icon(
                Icons.precision_manufacturing_rounded,
                color: cor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipamento['nome'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    equipamento['tipo'] ?? 'Sem tipo',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Placa: ${equipamento['placa'] ?? '-'}',
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
                if (isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'editar') {
                        abrirFormulario(equipamento: equipamento);
                      }

                      if (value == 'excluir') {
                        excluirEquipamento(equipamento);
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
      ),
    );
  }

  Widget _resumoCard(String valor, String label, Color cor) {
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
              label,
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
    final ativos =
        equipamentos.where((item) => item['status'] == 'Ativo').length;
    final manutencao =
        equipamentos.where((item) => item['status'] == 'Manutenção').length;
    final inativos =
        equipamentos.where((item) => item['status'] == 'Inativo').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Frota',
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
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              onPressed: () => abrirFormulario(),
              child: const Icon(Icons.add),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                      _resumoCard(
                        ativos.toString(),
                        'Ativos',
                        const Color(0xFF43A047),
                      ),
                      const SizedBox(width: 10),
                      _resumoCard(
                        manutencao.toString(),
                        'Manutenção',
                        const Color(0xFFE87722),
                      ),
                      const SizedBox(width: 10),
                      _resumoCard(
                        inativos.toString(),
                        'Inativos',
                        const Color(0xFFE53935),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: equipamentos.isEmpty
                      ? const Center(
                          child: Text('Nenhum veículo cadastrado.'),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(18),
                          children: equipamentos.map(equipamentoCard).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}