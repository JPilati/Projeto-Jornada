import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_responsive.dart';
import 'app_theme.dart';
import 'configuracoes_screen.dart';
import 'documentos_screen.dart';
import 'firebase_service.dart';
import 'frota_operador_screen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String nomeUsuario = 'Operador';
  bool carregandoNome = true;

  @override
  void initState() {
    super.initState();
    carregarNomeUsuario();
  }

  Future<void> carregarNomeUsuario() async {
    try {
      final profile = await FirebaseService.buscarMeuPerfil();

      if (!mounted) return;

      setState(() {
        nomeUsuario = profile?['nome'] ?? 'Operador';
        carregandoNome = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        carregandoNome = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildFeatureCard({
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
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: AppTheme.cardShadow(context),
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
              style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                color: Theme.of(context).appBarTheme.backgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Hub Digital',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton.filled(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.navy800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.navy800, AppTheme.navy950],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            carregandoNome
                                ? 'Bem-vindo'
                                : 'Bem-vindo, $nomeUsuario',
                            style: const TextStyle(
                              color: AppTheme.darkInfo,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Área do Operador',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Consulte seus documentos e informações.',
                            style: TextStyle(
                              color: AppTheme.darkInfo,
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
                    crossAxisCount: isDesktop ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isDesktop ? 1.35 : 0.92,
                    children: [
                      _buildFeatureCard(
                        icon: Icons.description_rounded,
                        title: 'Documentos',
                        subtitle: 'Meus documentos',
                        iconBgColor: AppTheme.orange.withValues(alpha: 0.16),
                        iconColor: AppTheme.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentosScreen(),
                            ),
                          );
                        },
                      ),
                      _buildFeatureCard(
                        icon: Icons.local_shipping_rounded,
                        title: 'Frota',
                        subtitle: 'Meus veículos',
                        iconBgColor: AppTheme.green.withValues(alpha: 0.16),
                        iconColor: AppTheme.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FrotaOperadorScreen(),
                            ),
                          );
                        },
                      ),
                      _buildFeatureCard(
                        icon: Icons.settings_rounded,
                        title: 'Configurações',
                        subtitle: 'Preferências',
                        iconBgColor: AppTheme.blue.withValues(alpha: 0.16),
                        iconColor: AppTheme.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ConfiguracoesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
