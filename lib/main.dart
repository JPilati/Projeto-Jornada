import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/material.dart';

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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gestão de documentos operacionais',
                    style: TextStyle(
                      color: Color(0xFF8A9BB0),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Matrícula / CPF',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: matriculaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.badge_outlined),
                      hintText: 'Digite sua matrícula',
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Senha',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: senhaController,
                    obscureText: ocultarSenha,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          ocultarSenha
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            ocultarSenha = !ocultarSenha;
                          });
                        },
                      ),
                      hintText: 'Digite sua senha',
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: carregando ? null : realizarLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: carregando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'ENTRAR NO SISTEMA',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}