import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'firebase_service.dart';

import 'app_responsive.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'home_screen.dart';
import 'home_admin_screen.dart';
import 'alterar_senha_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://mxecasxsghuimdirtnhc.supabase.co',
    anonKey: 'sb_publishable_xQioOh6azAYq_KchXTs5Bw_P6FyfQqZ',
  );

  await appSettings.load();

  runApp(const HubDigitalApp());
}

class HubDigitalApp extends StatelessWidget {
  const HubDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Hub Digital Ribas',
          debugShowCheckedModeBanner: false,
          themeMode: appSettings.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(appSettings.fontSize.scale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const LoginScreen(),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final matriculaController = TextEditingController();
  final senhaController = TextEditingController();

  bool ocultarSenha = true;
  bool carregando = false;

  @override
  void dispose() {
    matriculaController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> realizarLogin() async {
    final matricula = matriculaController.text.trim();
    final senha = senhaController.text.trim();

    if (matricula.isEmpty || senha.isEmpty) {
      mostrarErro('Informe matr\u00edcula e senha.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final email = FirebaseService.emailPorMatricula(matricula);

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Usu\u00e1rio n\u00e3o encontrado.');
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!profileDoc.exists) {
        throw Exception('Perfil do usu\u00e1rio n\u00e3o encontrado.');
      }

      final profile = profileDoc.data()!;

      final perfil = profile['perfil'];
      final status = profile['status'];
      final precisaTrocarSenha = profile['precisaTrocarSenha'] == true;

      if (status == 'Inativo') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Usu\u00e1rio inativo. Procure o administrador.');
      }

      if (!mounted) return;

      if (precisaTrocarSenha) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AlterarSenhaScreen(),
          ),
        );
        return;
      }

      if (perfil == 'Administrador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeAdminScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      mostrarErro('Erro ao logar: $e');
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
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    const textColor = Color(0xFFEAF4FF);
    const mutedColor = Color(0xFF9EB1C9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: const Color(0xFF38A7F2),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: mutedColor,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon,
              color: mutedColor,
              size: 25,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF061A32).withValues(alpha: 0.62),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.26),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF42B7F4),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustFooter(bool isDesktop) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isDesktop ? 168 : 82,
              height: 1,
              color: Colors.white.withValues(alpha: 0.16),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Icon(
                Icons.verified_user_outlined,
                color: Colors.white.withValues(alpha: 0.48),
                size: 34,
              ),
            ),
            Container(
              width: isDesktop ? 168 : 82,
              height: 1,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'S E G U R A N C A   -   Q U A L I D A D E   -   C O N F I A N C A',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF93A5BC),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppResponsive.isDesktop(context);
    final size = MediaQuery.sizeOf(context);
    final isCompactHeight = size.height < 720;

    return Scaffold(
      backgroundColor: const Color(0xFF041426),
      body: AppResponsiveBody(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/login_background.png',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE8041426),
                    Color(0xD9072442),
                    Color(0xEA03111F),
                  ],
                  stops: [0, 0.46, 1],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Container(
              color: const Color(0xFF041426).withValues(alpha: 0.38),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = isDesktop
                      ? (constraints.maxWidth * 0.42).clamp(560.0, 720.0)
                      : constraints.maxWidth - 32;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      isDesktop ? 64 : 28,
                      16,
                      isDesktop ? 34 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - (isDesktop ? 98 : 52),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              SizedBox(
                                width: isDesktop ? 160 : 132,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              SizedBox(height: isCompactHeight ? 32 : 56),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: -120,
                                    top: -90,
                                    child: Opacity(
                                      opacity: isDesktop ? 0.07 : 0.04,
                                      child: SizedBox(
                                        width: 390,
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: cardWidth,
                                    padding: EdgeInsets.fromLTRB(
                                      isDesktop ? 40 : 24,
                                      isDesktop ? 42 : 30,
                                      isDesktop ? 40 : 24,
                                      isDesktop ? 42 : 30,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF071A31)
                                          .withValues(alpha: 0.76),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.28),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.28),
                                          blurRadius: 36,
                                          offset: const Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Login',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Acesse sua conta para continuar',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFFB4C4D6),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: Container(
                                            width: 108,
                                            height: 2,
                                            color: const Color(0xFF41B7F4),
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        _buildInputField(
                                          controller: matriculaController,
                                          label: 'Matr\u00edcula',
                                          hint: 'Digite sua matr\u00edcula',
                                          icon: Icons.person_outline_rounded,
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 24),
                                        _buildInputField(
                                          controller: senhaController,
                                          label: 'Senha',
                                          hint: 'Digite sua senha',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: ocultarSenha,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              ocultarSenha
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: const Color(0xFF9EB1C9),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                ocultarSenha = !ocultarSenha;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 34),
                                        SizedBox(
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed: carregando
                                                ? null
                                                : realizarLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF2296E8),
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  const Color(0xFF2296E8)
                                                      .withValues(alpha: 0.52),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: carregando
                                                ? const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.4,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Entrar',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              top: isCompactHeight ? 32 : 54,
                            ),
                            child: _buildTrustFooter(isDesktop),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
