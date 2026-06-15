import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_responsive.dart';
import 'app_theme.dart';
import 'equipamento_detalhes_screen.dart';
import 'services/mlkit_ocr_service.dart';

class EquipamentosScreen extends StatefulWidget {
  const EquipamentosScreen({super.key});

  @override
  State<EquipamentosScreen> createState() => _EquipamentosScreenState();
}

class _EquipamentosScreenState extends State<EquipamentosScreen> {
  final db = FirebaseFirestore.instance;

  bool carregando = true;
  bool isAdmin = false;
  String? filtroSelecionado;
  List<Map<String, dynamic>> equipamentos = [];
  List<Map<String, dynamic>> operadores = [];

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

  Future<void> carregarOperadores() async {
    final snapshot = await db
        .collection('users')
        .where('perfil', isEqualTo: 'Operador')
        .orderBy('nome')
        .get();

    operadores = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  Future<void> carregarTela() async {
    try {
      final adminFirestore = await verificarAdminNoFirestore();

      await carregarOperadores();

      final snapshot = await db.collection('equipamentos').get();

      setState(() {
        isAdmin = adminFirestore;

        final listaEquipamentos = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        listaEquipamentos.sort((a, b) {
          final prioridade = {
            'Inativo': 0,
            'Manutenção': 1,
            'Ativo': 2,
          };

          final statusA = prioridade[a['status']] ?? 3;
          final statusB = prioridade[b['status']] ?? 3;

          if (statusA != statusB) {
            return statusA.compareTo(statusB);
          }

          final nomeA = (a['nome'] ?? '').toString().toLowerCase();
          final nomeB = (b['nome'] ?? '').toString().toLowerCase();

          return nomeA.compareTo(nomeB);
        });

        equipamentos = listaEquipamentos;

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

  Future<PlatformFile?> escolherImagemParaOCR() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (resultado == null || resultado.files.isEmpty) {
      return null;
    }

    return resultado.files.first;
  }

  Future<Map<String, String?>> lerDadosEquipamentoPorOCR(
    PlatformFile arquivo,
  ) async {
    final recognizedText = await MlkitOcrService.reconhecerTexto(arquivo);

    if (recognizedText == null) {
      throw Exception('Nao foi possivel acessar a imagem selecionada.');
    }

      final textoOriginal = recognizedText.text;
      final texto = textoOriginal.toLowerCase();
      final linhas = textoOriginal
          .split(RegExp(r'\r?\n'))
          .map((linha) => linha.trim())
          .where((linha) => linha.isNotEmpty)
          .toList();

      final linhasComPosicao = recognizedText.blocks
          .expand((block) => block.lines)
          .toList();

      String? valorVisualAoLado(List<String> rotulos) {
        for (final linhaRotulo in linhasComPosicao) {
          final textoRotulo = linhaRotulo.text.toLowerCase();

          if (!rotulos.any((rotulo) => textoRotulo.contains(rotulo))) {
            continue;
          }

          final caixaRotulo = linhaRotulo.boundingBox;
          final centroRotulo = caixaRotulo.top + (caixaRotulo.height / 2);

          dynamic melhorLinha;
          double melhorDistancia = double.infinity;

          for (final linhaValor in linhasComPosicao) {
            if (identical(linhaValor, linhaRotulo)) continue;

            final caixaValor = linhaValor.boundingBox;
            final centroValor = caixaValor.top + (caixaValor.height / 2);
            final desalinhamento = (centroValor - centroRotulo).abs();
            final distanciaHorizontal = caixaValor.left - caixaRotulo.right;

            if (desalinhamento > caixaRotulo.height * 1.5) continue;
            if (distanciaHorizontal < -8) continue;

            final textoValor = linhaValor.text.toLowerCase();
            final pareceOutroRotulo = [
              'nome / identifica',
              'tipo de ve',
              'placa',
              'capacidade',
              'combust',
              'cor',
              'ano / modelo',
              'marca / modelo',
              'potencia',
              'renavam',
              'chassi',
            ].any((rotulo) => textoValor.contains(rotulo));

            if (pareceOutroRotulo) continue;

            final distancia = distanciaHorizontal.abs() + desalinhamento;

            if (distancia < melhorDistancia) {
              melhorDistancia = distancia;
              melhorLinha = linhaValor;
            }
          }

          final valor = melhorLinha?.text.trim();

          if (valor != null && valor.isNotEmpty) {
            return valor;
          }
        }

        return null;
      }

      final placaMatch = RegExp(
        r'\b([A-Z]{3})[-\s]?([0-9][A-Z][0-9]{2})\b',
      ).firstMatch(textoOriginal.toUpperCase());

      final capacidadeMatch = RegExp(
        r'(capacidade|cap\.?|peso bruto total|pbt|lotacao|lotação)'
        r'[:\s-]*([0-9]+(?:[,.][0-9]+)?\s*(?:kg|kgs|t|ton|toneladas|pessoas|m3|m³)?)',
        caseSensitive: false,
      ).firstMatch(textoOriginal);

      String? valorDaLinhaComRotulo(List<String> rotulos) {
        for (var i = 0; i < linhas.length; i++) {
          final linha = linhas[i];
          final linhaLower = linha.toLowerCase();

          final temRotulo =
              rotulos.any((rotulo) => linhaLower.contains(rotulo));

          if (!temRotulo) continue;

          final partes = linha.split(RegExp(r'\s{2,}|:|-'));
          final ultimoTrecho = partes.last.trim();

          if (partes.length > 1 && ultimoTrecho.isNotEmpty) {
            return ultimoTrecho;
          }

          for (var proxima = i + 1; proxima < linhas.length; proxima++) {
            final valor = linhas[proxima].trim();
            final valorLower = valor.toLowerCase();

            final ehOutroRotulo = [
              'tipo',
              'placa',
              'capacidade',
              'combust',
              'cor',
              'ano',
              'marca',
              'potencia',
              'renavam',
              'chassi',
            ].any((rotulo) => valorLower.contains(rotulo));

            if (ehOutroRotulo) break;
            if (valor.isNotEmpty) return valor;
          }
        }

        return null;
      }

      final rotulosNome = [
        'nome / identifica',
        'nome',
      ];
      final rotulosTipo = [
        'tipo de ve',
        'tipo',
      ];
      final rotulosPlaca = [
        'placa',
      ];
      final rotulosCapacidade = [
        'capacidade de carga',
        'capacidade',
        'pbt',
      ];

      final nomePorRotulo =
          valorVisualAoLado(rotulosNome) ?? valorDaLinhaComRotulo(rotulosNome);
      final tipoPorRotulo =
          valorVisualAoLado(rotulosTipo) ?? valorDaLinhaComRotulo(rotulosTipo);
      final placaPorRotulo = valorVisualAoLado(rotulosPlaca) ??
          valorDaLinhaComRotulo(rotulosPlaca);
      final capacidadePorRotulo = valorVisualAoLado(rotulosCapacidade) ??
          valorDaLinhaComRotulo(rotulosCapacidade);

      String? tipo;
      final tipos = <String, List<String>>{
        'Caminhao Munck': ['munck', 'guindauto', 'guindaste veicular'],
        'Guindaste': ['guindaste', 'grua'],
        'Empilhadeira': ['empilhadeira'],
        'Plataforma elevatoria': [
          'plataforma elevatoria',
          'plataforma elevatória',
          'plataforma aerea',
          'plataforma aérea',
        ],
        'Caminhao': ['caminhao', 'caminhão'],
        'Carreta': ['carreta', 'semirreboque', 'semi reboque'],
        'Escavadeira': ['escavadeira'],
        'Retroescavadeira': ['retroescavadeira'],
      };

      for (final item in tipos.entries) {
        final textoTipo = (tipoPorRotulo ?? texto).toLowerCase();

        if (item.value.any((palavra) => textoTipo.contains(palavra))) {
          tipo = item.key;
          break;
        }
      }

      String? nome = nomePorRotulo;
      final nomeMatch = RegExp(
        r'(modelo|veiculo|veículo|equipamento|descricao|descrição)'
        r'[:\s-]+([A-Za-z0-9 .\/-]{3,48})',
        caseSensitive: false,
      ).firstMatch(textoOriginal);

      if (nome == null && nomeMatch != null) {
        nome = nomeMatch.group(2)?.trim();
      } else if (nome == null) {
        for (final linha in linhas.take(8)) {
          final minuscula = linha.toLowerCase();
          final pareceDadoUtil = linha.length >= 4 &&
              !minuscula.contains('certificado') &&
              !minuscula.contains('validade') &&
              !minuscula.contains('renavam') &&
              !minuscula.contains('placa') &&
              !RegExp(r'^\d').hasMatch(linha);

          if (pareceDadoUtil) {
            nome = linha;
            break;
          }
        }
      }

      final placaPorRotuloLimpa = placaPorRotulo
          ?.toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');

      return {
        'nome': nome,
        'tipo': tipo,
        'placa': placaPorRotuloLimpa != null &&
                RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$')
                    .hasMatch(placaPorRotuloLimpa)
            ? placaPorRotuloLimpa
            : placaMatch == null
            ? null
            : '${placaMatch.group(1)}${placaMatch.group(2)}',
        'capacidade':
            capacidadePorRotulo?.trim() ?? capacidadeMatch?.group(2)?.trim(),
      };
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
    bool analisandoOCR = false;


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
                    Text(
                      editando ? 'Editar veículo' : 'Cadastrar veículo',
                      style: const TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: analisandoOCR
                          ? null
                          : () async {
                              final arquivo = await escolherImagemParaOCR();

                              if (arquivo == null) return;

                              setModalState(() {
                                analisandoOCR = true;
                              });

                              try {
                                final dados =
                                    await lerDadosEquipamentoPorOCR(arquivo);

                                setModalState(() {
                                  if ((dados['nome'] ?? '').isNotEmpty) {
                                    nomeController.text = dados['nome']!;
                                  }

                                  if ((dados['tipo'] ?? '').isNotEmpty) {
                                    tipoController.text = dados['tipo']!;
                                  }

                                  if ((dados['placa'] ?? '').isNotEmpty) {
                                    placaController.text = dados['placa']!;
                                  }

                                  if ((dados['capacidade'] ?? '').isNotEmpty) {
                                    capacidadeController.text =
                                        dados['capacidade']!;
                                  }

                                  analisandoOCR = false;
                                });

                                final preenchidos = dados.values
                                    .where(
                                      (valor) =>
                                          (valor ?? '').trim().isNotEmpty,
                                    )
                                    .length;

                                if (preenchidos > 0) {
                                  mostrarSucesso(
                                    'Dados preenchidos pela imagem.',
                                  );
                                } else {
                                  mostrarErro(
                                    'Nenhum dado foi detectado na imagem.',
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  analisandoOCR = false;
                                });

                                mostrarErro('Erro ao ler imagem: $e');
                              }
                            },
                      icon: analisandoOCR
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner_rounded),
                      label: Text(
                        analisandoOCR
                            ? 'Lendo imagem...'
                            : 'Ler imagem com Google ML Kit',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE87722),
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Color(0xFFE87722)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.22 : 0.06),
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
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    equipamento['tipo'] ?? 'Sem tipo',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Placa: ${equipamento['placa'] ?? '-'}',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoCard(String valor, String label, Color cor) {
    final selecionado = filtroSelecionado == label;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            filtroSelecionado = selecionado ? null : label;
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
                valor,
                style: TextStyle(
                  color: selecionado ? Colors.white : cor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
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

  @override
  Widget build(BuildContext context) {
    final ativos =
        equipamentos.where((item) => item['status'] == 'Ativo').length;
    final manutencao =
        equipamentos.where((item) => item['status'] == 'Manutenção').length;
    final inativos =
        equipamentos.where((item) => item['status'] == 'Inativo').length;
    String? statusFiltro;

    if (filtroSelecionado == 'Ativos') {
      statusFiltro = 'Ativo';
    } else if (filtroSelecionado == 'Inativos') {
      statusFiltro = 'Inativo';
    } else {
      statusFiltro = filtroSelecionado;
    }

    final equipamentosFiltrados = statusFiltro == null
        ? equipamentos
        : equipamentos
            .where((item) => item['status'] == statusFiltro)
            .toList();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          'Frota',
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
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              onPressed: () => abrirFormulario(),
              child: const Icon(Icons.add),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : AppResponsiveBody(
              child: Column(
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
                  child: equipamentosFiltrados.isEmpty
                      ? const Center(
                          child: Text('Nenhum veículo encontrado.'),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(18),
                          children:
                              equipamentosFiltrados.map(equipamentoCard).toList(),
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}
