import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'firebase_service.dart';

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

  runApp(const HubDigitalApp());
}

class HubDigitalApp extends StatelessWidget {
  const HubDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hub Digital Ribas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFE87722),
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      ),
      home: const LoginScreen(),
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
      mostrarErro('Informe matrícula e senha.');
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
        throw Exception('Usuário não encontrado.');
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!profileDoc.exists) {
        throw Exception('Perfil do usuário não encontrado.');
      }

      final profile = profileDoc.data()!;

      final perfil = profile['perfil'];
      final status = profile['status'];
      final precisaTrocarSenha = profile['precisaTrocarSenha'] == true;

      if (status == 'Inativo') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Usuário inativo. Procure o administrador.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF071A2E),
                          Color(0xFF0D1B2A),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 150,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 6,
                  child: SizedBox(),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.64,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 38, 28, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(64),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Login',
                            style: TextStyle(
                              color: Color(0xFF0D1B2A),
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Acesse sua conta para continuar',
                            style: TextStyle(
                              color: Color(0xFF718096),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        const Text(
                          'Matrícula',
                          style: TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: matriculaController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Digite sua matrícula',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9AA6B2),
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: Color(0xFF1976D2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFF1976D2),
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Senha',
                          style: TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: senhaController,
                          obscureText: ocultarSenha,
                          style: const TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Digite sua senha',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9AA6B2),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF1976D2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                ocultarSenha
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: const Color(0xFF718096),
                              ),
                              onPressed: () {
                                setState(() {
                                  ocultarSenha = !ocultarSenha;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFF1976D2),
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: carregando ? null : realizarLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF11468F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: carregando
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
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