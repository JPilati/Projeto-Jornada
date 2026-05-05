// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'equipamentos_screen.dart';
import 'main.dart';
import 'documentos_screen.dart';
import 'colaboradores_screen.dart';

class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja sair da conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sair'),
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

  Widget _buildMiniStatus({
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            // 🔵 HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              color: const Color(0xFF0D1B2A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Hub Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _logout(context),
                        child: const CircleAvatar(
                          backgroundColor: Color(0xFF1B2F46),
                          child: Icon(
                            Icons.logout,
                            color: Colors.white,
                          ),
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
                        colors: [
                          Color(0xFF12365A),
                          Color(0xFF0D1B2A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Área Administrativa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gerencie colaboradores, frota, documentos e relatórios.',
                          style: TextStyle(
                            color: Color(0xFFCBD5E0),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _buildMiniStatus(
                              value: '18',
                              label: 'Regulares',
                              color: const Color(0xFF43A047),
                            ),
                            const SizedBox(width: 10),
                            _buildMiniStatus(
                              value: '5',
                              label: 'A vencer',
                              color: const Color(0xFFE87722),
                            ),
                            const SizedBox(width: 10),
                            _buildMiniStatus(
                              value: '2',
                              label: 'Vencidos',
                              color: const Color(0xFFE53935),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🔲 GRID
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
                      icon: Icons.dashboard_rounded,
                      title: 'Dashboard',
                      subtitle: 'Visão geral',
                      iconBgColor: const Color(0xFFE3F2FD),
                      iconColor: const Color(0xFF1976D2),
                      onTap: () {},
                    ),

                    _buildAdminCard(
                      icon: Icons.people_alt_rounded,
                      title: 'Colaboradores',
                      subtitle: 'Gerenciar equipe',
                      iconBgColor: const Color(0xFFE8F5E9),
                      iconColor: const Color(0xFF43A047),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ColaboradoresScreen(),
                          ),
                        );
                      },
                    ),

                    _buildAdminCard(
                      icon: Icons.precision_manufacturing_rounded,
                      title: 'Frota',
                      subtitle: 'Máquinas e veículos',
                      iconBgColor: const Color(0xFFEDE7F6),
                      iconColor: const Color(0xFF6A1B9A),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EquipamentosScreen(),
                          ),
                        );
                      },
                    ),

                    _buildAdminCard(
                      icon: Icons.description_rounded,
                      title: 'Documentos',
                      subtitle: 'Controle geral',
                      iconBgColor: const Color(0xFFFFF3E0),
                      iconColor: const Color(0xFFE87722),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentosScreen(),
                          ),
                        );
                      },
                    ),

                    _buildAdminCard(
                      icon: Icons.bar_chart_rounded,
                      title: 'Relatórios',
                      subtitle: 'Indicadores',
                      iconBgColor: const Color(0xFFE0F7FA),
                      iconColor: const Color(0xFF00838F),
                      onTap: () {},
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