import 'package:financas_inteligentes/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tela de perfil do usuário.
///
/// Permite editar nome de exibição, alterar senha e excluir conta.
/// Foto de perfil exibe o avatar com inicial — upload de imagem será
/// adicionado em versão futura (requer firebase_storage + image_picker).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth        = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Avatar ───────────────────────────────────────────────────────
          _AvatarSection(
            initial: auth.displayInitial,
            photoURL: auth.photoURL,
          ),
          const SizedBox(height: 24),

          // ── Informações da conta ─────────────────────────────────────────
          _SectionCard(
            header: 'Informações da conta',
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('E-mail'),
                subtitle: Text(auth.user?.email ?? '—'),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Nome de exibição'),
                subtitle: Text(
                  auth.displayLabel == 'Convidado' ? '—' : auth.displayLabel,
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _showEditNameDialog(context, auth),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Segurança ─────────────────────────────────────────────────────
          _SectionCard(
            header: 'Segurança',
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Alterar senha'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showChangePasswordDialog(context, auth),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Zona de perigo ────────────────────────────────────────────────
          _SectionCard(
            header: 'Zona de perigo',
            children: [
              ListTile(
                leading: Icon(Icons.logout, color: colorScheme.error),
                title: Text('Sair',
                    style: TextStyle(color: colorScheme.error)),
                onTap: () => _confirmSignOut(context, auth),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: colorScheme.error),
                title: Text('Excluir conta',
                    style: TextStyle(color: colorScheme.error)),
                subtitle: const Text('Esta ação é irreversível.'),
                onTap: () => _confirmDeleteAccount(context, auth),
              ),
            ],
          ),

          // ── Versão ────────────────────────────────────────────────────────
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Finanças Inteligentes v1.0.0',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Diálogos ──────────────────────────────────────────────────────────────

  Future<void> _showEditNameDialog(
      BuildContext context, AuthProvider auth) async {
    final ctrl = TextEditingController(
      text: auth.user?.displayName ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nome'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nome de exibição',
            hintText: 'Como quer ser chamado?',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await auth.updateDisplayName(name);
              if (!ok && context.mounted && auth.errorMessage != null) {
                _showSnack(context, auth.errorMessage!);
                auth.clearError();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _showChangePasswordDialog(
      BuildContext context, AuthProvider auth) async {
    final newCtrl    = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureNew     = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Alterar senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar nova senha',
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (newCtrl.text.length < 6) {
                  _showSnack(ctx,
                      'A senha deve ter pelo menos 6 caracteres.');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  _showSnack(ctx, 'As senhas não coincidem.');
                  return;
                }
                Navigator.pop(ctx);
                final ok = await auth.updatePassword(newCtrl.text);
                if (!ok && context.mounted && auth.errorMessage != null) {
                  _showSnack(context, auth.errorMessage!);
                  auth.clearError();
                } else if (ok && context.mounted) {
                  _showSnack(context, 'Senha alterada com sucesso!');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _confirmSignOut(
      BuildContext context, AuthProvider auth) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair da conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) await auth.signOut();
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, AuthProvider auth) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Excluir conta'),
        content: const Text(
          'Todos os seus dados serão removidos permanentemente. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final deleted = await auth.deleteAccount();
    if (!deleted && context.mounted && auth.errorMessage != null) {
      _showSnack(context, auth.errorMessage!);
      auth.clearError();
    }
  }

  void _showSnack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── _AvatarSection ────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.initial, this.photoURL});

  final String  initial;
  final String? photoURL;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    photoURL != null ? NetworkImage(photoURL!) : null,
                child: photoURL == null
                    ? Text(
                        initial,
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              // Botão placeholder para futura funcionalidade de upload
              Tooltip(
                message: 'Upload de foto disponível em breve',
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: colorScheme.outlineVariant, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Foto de perfil',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── _SectionCard ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.header, required this.children});

  final String       header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              header,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
