import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'equipamento_detalhes_screen.dart';

class EquipamentosScreen extends StatefulWidget {
  const EquipamentosScreen({super.key});

  @override
  State<EquipamentosScreen> createState() => _EquipamentosScreenState();
}

class _EquipamentosScreenState extends State<EquipamentosScreen> {
  final supabase = Supabase.instance.client;

  bool carregando = true;
  List<Map<String, dynamic>> equipamentos = [];

  @override
  void initState() {
    super.initState();
    carregarEquipamentos();
  }

  Future<void> carregarEquipamentos() async {
    try {
      final data = await supabase
          .from('equipamentos')
          .select()
          .order('nome', ascending: true);

      setState(() {
        equipamentos = List<Map<String, dynamic>>.from(data);
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar equipamentos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      value: statusSelecionado,
                      decoration: inputDecoration('Status'),
                      items: const [
                        DropdownMenuItem(value: 'Ativo', child: Text('Ativo')),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preencha os campos principais.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          if (editando) {
                            await supabase.from('equipamentos').update({
                              'nome': nomeController.text.trim(),
                              'tipo': tipoController.text.trim(),
                              'placa': placaController.text.trim(),
                              'capacidade': capacidadeController.text.trim(),
                              'status': statusSelecionado,
                            }).eq('id', equipamento['id']);
                          } else {
                            await supabase.from('equipamentos').insert({
                              'nome': nomeController.text.trim(),
                              'tipo': tipoController.text.trim(),
                              'placa': placaController.text.trim(),
                              'capacidade': capacidadeController.text.trim(),
                              'status': statusSelecionado,
                            });
                          }

                          await carregarEquipamentos();

                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao salvar veículo: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
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
                await supabase
                    .from('equipamentos')
                    .delete()
                    .eq('id', equipamento['id']);

                await carregarEquipamentos();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veículo excluído.'),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE87722),
        foregroundColor: Colors.white,
        onPressed: () => abrirFormulario(),
        child: const Icon(Icons.add),
      ),
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
}