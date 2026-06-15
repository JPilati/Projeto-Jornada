import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_responsive.dart';
import 'app_theme.dart';
import 'home_admin_screen.dart';
import 'home_screen.dart';

class AlterarSenhaScreen extends StatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final novaSenhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool ocultarNovaSenha = true;
  bool ocultarConfirmarSenha = true;
  bool carregando = false;

  @override
  void dispose() {
    novaSenhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> alterarSenha() async {
    final novaSenha = novaSenhaController.text.trim();
    final confirmarSenha = confirmarSenhaController.text.trim();

    if (novaSenha.length < 6) {
      mostrarErro('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    if (novaSenha != confirmarSenha) {
      mostrarErro('As senhas não conferem.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      await user.updatePassword(novaSenha);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'precisaTrocarSenha': false,
      });

      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!profileDoc.exists) {
        throw Exception('Perfil não encontrado.');
      }

      final profile = profileDoc.data()!;
      final perfil = profile['perfil'];

      if (!mounted) return;

      if (perfil == 'Administrador') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeAdminScreen(),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      mostrarErro('Erro ao alterar senha: $e');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  void mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppTheme.red,
      ),
    );
  }

  Widget passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: AppResponsiveBody(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.navy950, AppTheme.navy850],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 560 : double.infinity,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 148,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 34),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppTheme.surface(context).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppTheme.border(context)),
                            boxShadow: AppTheme.cardShadow(context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Alterar senha',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Por segurança, altere sua senha provisória antes de continuar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 26),
                              passwordField(
                                controller: novaSenhaController,
                                label: 'Nova senha',
                                icon: Icons.lock_outline_rounded,
                                obscureText: ocultarNovaSenha,
                                onToggle: () {
                                  setState(() {
                                    ocultarNovaSenha = !ocultarNovaSenha;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              passwordField(
                                controller: confirmarSenhaController,
                                label: 'Confirmar senha',
                                icon: Icons.lock_reset_rounded,
                                obscureText: ocultarConfirmarSenha,
                                onToggle: () {
                                  setState(() {
                                    ocultarConfirmarSenha = !ocultarConfirmarSenha;
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: carregando ? null : alterarSenha,
                                child: carregando
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Alterar senha e continuar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
