import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'alterar_senha_screen.dart';
import 'app_responsive.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'firebase_service.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  Map<String, dynamic>? perfil;
  bool carregando = true;
  bool recuperandoSenha = false;

  @override
  void initState() {
    super.initState();
    carregarPerfil();
  }

  Future<void> carregarPerfil() async {
    try {
      final dados = await FirebaseService.buscarMeuPerfil();

      if (!mounted) return;

      setState(() {
        perfil = dados;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      mostrarMensagem('Erro ao carregar perfil: $e', erro: true);
    }
  }

  Future<void> recuperarSenha() async {
    final email = FirebaseAuth.instance.currentUser?.email;

    if (email == null || email.isEmpty) {
      mostrarMensagem('E-mail do usuário não encontrado.', erro: true);
      return;
    }

    setState(() {
      recuperandoSenha = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      mostrarMensagem('Link de recuperação enviado para $email.');
    } catch (e) {
      mostrarMensagem('Erro ao enviar recuperação: $e', erro: true);
    } finally {
      if (mounted) {
        setState(() {
          recuperandoSenha = false;
        });
      }
    }
  }

  void mostrarMensagem(String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? AppTheme.red : AppTheme.green,
      ),
    );
  }

  String valorPerfil(String chave, String fallback) {
    final valor = perfil?[chave]?.toString().trim();
    if (valor == null || valor.isEmpty) return fallback;
    return valor;
  }

  String get matricula {
    final valor = perfil?['matricula']?.toString().trim();
    if (valor != null && valor.isNotEmpty) return valor;

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.contains('@')) return email.split('@').first;

    return '-';
  }

  Widget sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget infoLine(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface(context).withValues(
          alpha: AppTheme.isDark(context) ? 0.58 : 0.72,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary(context), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget themeOption({
    required bool dark,
    required String label,
    required IconData icon,
  }) {
    final selected = appSettings.darkMode == dark;
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => appSettings.setDarkMode(dark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 94,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? (dark ? AppTheme.navy800 : const Color(0xFFEAF4FF))
                : AppTheme.elevatedSurface(context).withValues(
                    alpha: AppTheme.isDark(context) ? 0.48 : 0.68,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : AppTheme.border(context),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Icon(
                  icon,
                  color: selected
                      ? (dark ? Colors.white : AppTheme.navy950)
                      : AppTheme.textSecondary(context),
                  size: 30,
                ),
              ),
              if (selected)
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.orange,
                    size: 22,
                  ),
                ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? (dark ? Colors.white : AppTheme.navy950)
                        : AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget fontOption(AppFontSize option) {
    final selected = appSettings.fontSize == option;

    return Expanded(
      child: OutlinedButton(
        onPressed: () => appSettings.setFontSize(option),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          side: BorderSide(
            color: selected ? Theme.of(context).colorScheme.primary : AppTheme.border(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(option.label),
      ),
    );
  }

  Widget settingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface(context).withValues(
          alpha: AppTheme.isDark(context) ? 0.52 : 0.66,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget dayOption(int days) {
    final selected = appSettings.notificationDays == days;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: appSettings.notificationsEnabled
            ? () => appSettings.setNotificationDays(days)
            : null,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
                : AppTheme.elevatedSurface(context).withValues(
                    alpha: AppTheme.isDark(context) ? 0.46 : 0.64,
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.primary : AppTheme.border(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : AppTheme.textSecondary(context),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$days dias',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Radio<int>(
                value: days,
                groupValue: appSettings.notificationDays,
                onChanged: appSettings.notificationsEnabled
                    ? (value) => appSettings.setNotificationDays(value ?? days)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget systemLine(IconData icon, String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border(context)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary(context), size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '-';
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppTheme.pageBackground(context),
          appBar: AppBar(
            title: const Text('Configurações'),
          ),
          body: carregando
              ? const Center(child: CircularProgressIndicator())
              : AppResponsiveBody(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.navy800, AppTheme.navy950],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Configurações',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Gerencie sua conta, aparência e preferências do sistema.',
                                    style: TextStyle(
                                      color: AppTheme.darkInfo,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumns = constraints.maxWidth >= 920;
                          final account = sectionCard(
                            icon: Icons.person_outline_rounded,
                            title: 'Minha Conta',
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 44,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          valorPerfil('nome', 'Usuário'),
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            color: AppTheme.textPrimary(context),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Chip(
                                          avatar: const Icon(Icons.verified_user, size: 16),
                                          label: Text(valorPerfil('perfil', 'Operador')),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Matrícula: $matricula',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary(context),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              infoLine(Icons.email_outlined, 'E-mail', email),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, buttonConstraints) {
                                  final vertical = buttonConstraints.maxWidth < 520;
                                  final alterarSenhaButton = ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AlterarSenhaScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.lock_reset_rounded),
                                    label: const Text('Alterar Senha'),
                                  );
                                  final recuperarSenhaButton = OutlinedButton.icon(
                                    onPressed: recuperandoSenha ? null : recuperarSenha,
                                    icon: const Icon(Icons.restart_alt_rounded),
                                    label: Text(
                                      recuperandoSenha ? 'Enviando...' : 'Redefinir Senha',
                                    ),
                                  );

                                  if (vertical) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        alterarSenhaButton,
                                        const SizedBox(height: 10),
                                        recuperarSenhaButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: alterarSenhaButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: recuperarSenhaButton),
                                    ],
                                  );
                                },
                              ),
                            ],
                          );

                          final appearance = sectionCard(
                            icon: Icons.palette_outlined,
                            title: 'Aparência',
                            children: [
                              Text(
                                'Tema',
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  themeOption(
                                    dark: false,
                                    label: 'Claro',
                                    icon: Icons.light_mode_outlined,
                                  ),
                                  const SizedBox(width: 12),
                                  themeOption(
                                    dark: true,
                                    label: 'Escuro',
                                    icon: Icons.dark_mode_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Tamanho da fonte',
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  for (final option in AppFontSize.values) ...[
                                    fontOption(option),
                                    if (option != AppFontSize.values.last)
                                      const SizedBox(width: 10),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.isDark(context)
                                      ? AppTheme.navy950
                                      : const Color(0xFF101827),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border(context)),
                                ),
                                child: const Text(
                                  'Este é um exemplo de texto com o tamanho selecionado para a interface do sistema.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );

                          final notifications = sectionCard(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notificações',
                            children: [
                              settingSwitch(
                                icon: Icons.event_available_rounded,
                                title: 'Notificações de vencimento',
                                subtitle:
                                    'Receba alertas sobre documentos e itens próximos do vencimento.',
                                value: appSettings.notificationsEnabled,
                                onChanged: appSettings.setNotificationsEnabled,
                              ),
                              const SizedBox(height: 12),
                              settingSwitch(
                                icon: Icons.volume_up_outlined,
                                title: 'Notificações sonoras',
                                subtitle:
                                    'Emitir som ao receber novas notificações e alertas importantes.',
                                value: appSettings.notificationSoundEnabled,
                                onChanged: appSettings.notificationsEnabled
                                    ? appSettings.setNotificationSoundEnabled
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Prazo de aviso',
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  dayOption(7),
                                  const SizedBox(width: 10),
                                  dayOption(15),
                                  const SizedBox(width: 10),
                                  dayOption(30),
                                ],
                              ),
                            ],
                          );

                          final system = sectionCard(
                            icon: Icons.info_outline_rounded,
                            title: 'Sistema',
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  children: [
                                    systemLine(
                                      Icons.shield_outlined,
                                      'Versão do sistema',
                                      'Hub Digital Ribas v1.0.0',
                                    ),
                                    systemLine(
                                      Icons.sync_rounded,
                                      'Última sincronização',
                                      '15/06/2026 10:45',
                                    ),
                                    systemLine(
                                      Icons.wifi_rounded,
                                      'Status da conexão',
                                      'Online',
                                      valueColor: AppTheme.green,
                                    ),
                                    systemLine(
                                      Icons.storage_rounded,
                                      'Banco de dados',
                                      'Firebase',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );

                          if (!twoColumns) {
                            return Column(
                              children: [
                                account,
                                const SizedBox(height: 18),
                                appearance,
                                const SizedBox(height: 18),
                                notifications,
                                const SizedBox(height: 18),
                                system,
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: account),
                                  const SizedBox(width: 18),
                                  Expanded(child: appearance),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: notifications),
                                  const SizedBox(width: 18),
                                  Expanded(child: system),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          'S E G U R A N Ç A   •   Q U A L I D A D E   •   C O N F I A N Ç A',
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
}
