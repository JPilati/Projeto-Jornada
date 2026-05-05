import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'equipamentos_screen.dart';
import 'documentos_screen.dart';
import 'colaboradores_screen.dart';

class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  final supabase = Supabase.instance.client;

  int totalColaboradores = 0;
  int equipamentosAtivos = 0;
  int equipamentosManutencao = 0;

  List<Map<String, dynamic>> docsOperadorVencidos = [];
  List<Map<String, dynamic>> docsOperadorAVencer = [];
  List<Map<String, dynamic>> docsEquipamentoVencidos = [];
  List<Map<String, dynamic>> docsEquipamentoAVencer = [];

  @override
  void initState() {
    super.initState();
    carregarDadosDashboard();
  }

  int get totalNotificacoes =>
      docsOperadorVencidos.length +
      docsOperadorAVencer.length +
      docsEquipamentoVencidos.length +
      docsEquipamentoAVencer.length;

  Future<void> carregarDadosDashboard() async {
    try {
      final colaboradores = await supabase
          .from('profiles')
          .select('id')
          .eq('perfil', 'Operador')
          .eq('status', 'Ativo');

      final equipamentos = await supabase.from('equipamentos').select('status');

      final documentos = await supabase.from('documentos').select('''
        id,
        titulo,
        categoria,
        data_validade,
        status,
        arquivo_url,
        usuario_id,
        equipamento_id,
        profiles (
          nome
        ),
        equipamentos (
          nome
        )
      ''');

      final hoje = DateTime.now();
      final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
      final limite = hojeSemHora.add(const Duration(days: 30));

      final operadorVencidos = <Map<String, dynamic>>[];
      final operadorAVencer = <Map<String, dynamic>>[];
      final equipamentoVencidos = <Map<String, dynamic>>[];
      final equipamentoAVencer = <Map<String, dynamic>>[];

      for (final doc in documentos) {
        final dataTexto = doc['data_validade'];
        if (dataTexto == null) continue;

        final validade = DateTime.tryParse(dataTexto.toString());
        if (validade == null) continue;

        final validadeSemHora =
            DateTime(validade.year, validade.month, validade.day);

        final isEquipamento = doc['equipamento_id'] != null;

        if (validadeSemHora.isBefore(hojeSemHora)) {
          if (isEquipamento) {
            equipamentoVencidos.add(Map<String, dynamic>.from(doc));
          } else {
            operadorVencidos.add(Map<String, dynamic>.from(doc));
          }
        } else if (validadeSemHora.isBefore(limite) ||
            validadeSemHora.isAtSameMomentAs(limite)) {
          if (isEquipamento) {
            equipamentoAVencer.add(Map<String, dynamic>.from(doc));
          } else {
            operadorAVencer.add(Map<String, dynamic>.from(doc));
          }
        }
      }

      setState(() {
        totalColaboradores = colaboradores.length;
        equipamentosAtivos =
            equipamentos.where((e) => e['status'] == 'Ativo').length;
        equipamentosManutencao =
            equipamentos.where((e) => e['status'] == 'Manutenção').length;

        docsOperadorVencidos = operadorVencidos;
        docsOperadorAVencer = operadorAVencer;
        docsEquipamentoVencidos = equipamentoVencidos;
        docsEquipamentoAVencer = equipamentoAVencer;
      });
    } catch (e) {
      debugPrint('Erro dashboard: $e');
    }
  }

  void _logout(BuildContext context) async {
    await supabase.auth.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String formatarData(String? dataTexto) {
    if (dataTexto == null) return '-';

    final data = DateTime.tryParse(dataTexto);
    if (data == null) return '-';

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  String nomeOrigemDocumento(Map<String, dynamic> doc) {
    if (doc['equipamento_id'] != null) {
      final equipamento = doc['equipamentos'];
      return equipamento != null ? equipamento['nome'] ?? 'Equipamento' : 'Equipamento';
    }

    final profile = doc['profiles'];
    return profile != null ? profile['nome'] ?? 'Operador' : 'Operador';
  }

  void abrirDocumentoNotificacao(Map<String, dynamic> doc) {
    final arquivoUrl = doc['arquivo_url']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF4F7FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D7E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  doc['titulo'] ?? 'Documento',
                  style: const TextStyle(
                    color: Color(0xFF1A202C),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  doc['categoria'] ?? 'Sem categoria',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                _linhaDetalhe(
                  'Tipo',
                  doc['equipamento_id'] != null
                      ? 'Documento de equipamento'
                      : 'Documento de operador',
                ),
                _linhaDetalhe('Vinculado a', nomeOrigemDocumento(doc)),
                _linhaDetalhe(
                  'Validade',
                  formatarData(doc['data_validade']?.toString()),
                ),
                _linhaDetalhe('Status', doc['status'] ?? '-'),
                const SizedBox(height: 18),
                if (arquivoUrl != null && arquivoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      arquivoUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: arquivoUrl == null || arquivoUrl.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VisualizarDocumentoScreen(imageUrl: arquivoUrl),
                            ),
                          );
                        },
                  icon: const Icon(Icons.open_in_full_rounded),
                  label: const Text('ABRIR DOCUMENTO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE87722),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _linhaDetalhe(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF718096),
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                color: Color(0xFF1A202C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A202C),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF718096),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return GestureDetector(
      onTap: abrirMenuNotificacoes,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: Color(0xFF1B2F46),
            child: Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          if (totalNotificacoes > 0)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  totalNotificacoes.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void abrirMenuNotificacoes() {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFFF4F7FB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D7E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Notificações',
                style: TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                totalNotificacoes == 0
                    ? 'Nenhuma pendência no momento.'
                    : '$totalNotificacoes pendência(s) encontrada(s).',
                style: const TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),

              // 🔥 OPERADORES VENCIDOS
              if (docsOperadorVencidos.isNotEmpty) ...[
                _buildGrupoNotificacao(
                  titulo: 'Operadores — vencidos',
                  subtitulo: 'Documentos de funcionários vencidos',
                  documentos: docsOperadorVencidos,
                  cor: const Color(0xFFE53935),
                  icone: Icons.person_off_rounded,
                ),
                const SizedBox(height: 16),
              ],

              // 🔥 OPERADORES A VENCER
              if (docsOperadorAVencer.isNotEmpty) ...[
                _buildGrupoNotificacao(
                  titulo: 'Operadores — a vencer',
                  subtitulo: 'Documentos de funcionários em até 30 dias',
                  documentos: docsOperadorAVencer,
                  cor: const Color(0xFFE87722),
                  icone: Icons.person_search_rounded,
                ),
                const SizedBox(height: 16),
              ],

              // 🔥 EQUIPAMENTOS VENCIDOS
              if (docsEquipamentoVencidos.isNotEmpty) ...[
                _buildGrupoNotificacao(
                  titulo: 'Equipamentos — vencidos',
                  subtitulo: 'Documentos de veículos/equipamentos vencidos',
                  documentos: docsEquipamentoVencidos,
                  cor: const Color(0xFFE53935),
                  icone: Icons.precision_manufacturing_rounded,
                ),
                const SizedBox(height: 16),
              ],

              // 🔥 EQUIPAMENTOS A VENCER
              if (docsEquipamentoAVencer.isNotEmpty) ...[
                _buildGrupoNotificacao(
                  titulo: 'Equipamentos — a vencer',
                  subtitulo:
                      'Documentos de veículos/equipamentos em até 30 dias',
                  documentos: docsEquipamentoAVencer,
                  cor: const Color(0xFFE87722),
                  icone: Icons.build_circle_outlined,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildGrupoNotificacao({
    required String titulo,
    required String subtitulo,
    required List<Map<String, dynamic>> documentos,
    required Color cor,
    required IconData icone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
                backgroundColor: cor.withOpacity(0.14),
                child: Icon(icone, color: cor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Color(0xFF1A202C),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                documentos.length.toString(),
                style: TextStyle(
                  color: cor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (documentos.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...documentos.take(8).map((doc) {
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => abrirDocumentoNotificacao(doc),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description_rounded, color: cor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${doc['titulo']} • ${nomeOrigemDocumento(doc)}',
                          style: const TextStyle(
                            color: Color(0xFF1A202C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatarData(doc['data_validade']?.toString()),
                        style: TextStyle(
                          color: cor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              color: const Color(0xFF0D1B2A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Área Administrativa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _buildNotificationIcon(),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _logout(context),
                        child: const CircleAvatar(
                          radius: 23,
                          backgroundColor: Color(0xFF1B2F46),
                          child: Icon(
                            Icons.logout,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF12365A),
                          Color(0xFF0D1B2A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Painel de gestão',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          totalNotificacoes == 0
                              ? 'Tudo certo por enquanto.'
                              : 'Você tem $totalNotificacoes pendência(s) para verificar.',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E0),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.92,
                  children: [
                    _buildAdminCard(
                      icon: Icons.people_alt_rounded,
                      title: 'Colaboradores',
                      subtitle: '$totalColaboradores ativos',
                      iconBgColor: const Color(0xFFE8F5E9),
                      iconColor: const Color(0xFF43A047),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ColaboradoresScreen(),
                          ),
                        ).then((_) => carregarDadosDashboard());
                      },
                    ),
                    _buildAdminCard(
                      icon: Icons.precision_manufacturing_rounded,
                      title: 'Frota',
                      subtitle:
                          '$equipamentosAtivos ativos / $equipamentosManutencao manutenção',
                      iconBgColor: const Color(0xFFEDE7F6),
                      iconColor: const Color(0xFF6A1B9A),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EquipamentosScreen(),
                          ),
                        ).then((_) => carregarDadosDashboard());
                      },
                    ),
                    _buildAdminCard(
                      icon: Icons.description_rounded,
                      title: 'Documentos',
                      subtitle: totalNotificacoes == 0
                          ? 'Controle geral'
                          : '$totalNotificacoes pendência(s)',
                      iconBgColor: const Color(0xFFFFF3E0),
                      iconColor: const Color(0xFFE87722),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentosScreen(),
                          ),
                        ).then((_) => carregarDadosDashboard());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}