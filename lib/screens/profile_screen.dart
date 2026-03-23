import 'package:financas_inteligentes/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _AvatarSection(
            initial: auth.displayInitial,
            photoURL: auth.photoUrl, // FIX
          ),
          const SizedBox(height: 24),

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
                  auth.displayLabel == 'Convidado'
                      ? '—'
                      : auth.displayLabel,
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _showEditNameDialog(context, auth),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
          ),
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
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Senha atual'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Nova senha'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha'),
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
              if (currentCtrl.text.isEmpty) {
                _showSnack(ctx, 'Informe a senha atual.');
                return;
              }

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

              final ok = await auth.updatePassword(
                currentPassword: currentCtrl.text,
                newPassword: newCtrl.text,
              );

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
    );

    currentCtrl.dispose();
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
          'Todos os seus dados serão removidos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok == true) await auth.deleteAccount();
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.initial, this.photoURL});

  final String initial;
  final String? photoURL;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 48,
      backgroundImage:
          photoURL != null ? NetworkImage(photoURL!) : null,
      child: photoURL == null ? Text(initial) : null,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}