import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:financas_inteligentes/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus    = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Preencha e-mail e senha para continuar.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok   = await auth.signIn(email: email, password: password);
    if (!mounted) return;
    if (!ok && auth.errorMessage != null) {
      _showSnack(auth.errorMessage!);
      auth.clearError();
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Preencha e-mail e senha para cadastrar.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok   = await auth.register(email: email, password: password);
    if (!mounted) return;
    if (!ok && auth.errorMessage != null) {
      _showSnack(auth.errorMessage!);
      auth.clearError();
    }
  }

  Future<void> _loginGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok   = await auth.signInWithGoogle();
    if (!mounted) return;
    if (!ok && auth.errorMessage != null) {
      _showSnack(auth.errorMessage!);
      auth.clearError();
    }
  }

  Future<void> _loginApple() async {
    final auth = context.read<AuthProvider>();
    final ok   = await auth.signInWithApple();
    if (!mounted) return;
    if (!ok && auth.errorMessage != null) {
      _showSnack(auth.errorMessage!);
      auth.clearError();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InputDecoration(
      hintText:   hint,
      hintStyle:  tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final tt        = Theme.of(context).textTheme;
    final auth      = context.watch<AuthProvider>();
    final isLoading = auth.isLoading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primaryContainer],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Card(
                  elevation: 2,
                  shadowColor: cs.shadow,
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.88),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo ────────────────────────────────────────
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: cs.onPrimaryContainer,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bem-vindo de volta',
                          textAlign: TextAlign.center,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Acesse sua conta para continuar.',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onPrimaryContainer.withValues(alpha: 0.82),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── E-mail ───────────────────────────────────────
                        Text('E-mail',
                            style: tt.labelLarge?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          focusNode:  _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(_passwordFocus),
                          decoration: _inputDecoration(context,
                              hint: 'seuemail@dominio.com',
                              icon: Icons.mail_outline),
                        ),
                        const SizedBox(height: 12),

                        // ── Senha ────────────────────────────────────────
                        Text('Senha',
                            style: tt.labelLarge?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          focusNode:  _passwordFocus,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: _inputDecoration(
                            context,
                            hint: 'Digite sua senha',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Entrar ───────────────────────────────────────
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: isLoading ? null : _login,
                            child: isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4))
                                : const Text('Entrar'),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── Criar conta ──────────────────────────────────
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: isLoading ? null : _register,
                            child: const Text('Criar conta'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Divisor ──────────────────────────────────────
                        Row(children: [
                          Expanded(child: Divider(color: cs.outlineVariant)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou continue com',
                                style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant)),
                          ),
                          Expanded(child: Divider(color: cs.outlineVariant)),
                        ]),
                        const SizedBox(height: 16),

                        // ── Google ───────────────────────────────────────
                        _SocialButton(
                          onPressed: isLoading ? null : _loginGoogle,
                          icon: _GoogleIcon(),
                          label: 'Continuar com Google',
                        ),

                        // ── Apple (somente iOS / macOS) ──────────────────
                        if (auth.appleSignInAvailable) ...[
                          const SizedBox(height: 10),
                          _SocialButton(
                            onPressed: isLoading ? null : _loginApple,
                            icon: const Icon(Icons.apple, size: 22),
                            label: 'Continuar com Apple',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botão social genérico ─────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: cs.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label,
                style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ── Ícone do Google (SVG inline via CustomPainter) ────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2;

    // Red arc
    _arc(canvas, cx, cy, r, -10, 128,
        const Color(0xFFEA4335));
    // Yellow arc
    _arc(canvas, cx, cy, r, 118, 93,
        const Color(0xFFFBBC04));
    // Green arc
    _arc(canvas, cx, cy, r, 211, 75,
        const Color(0xFF34A853));
    // Blue arc
    _arc(canvas, cx, cy, r, 286, 84,
        const Color(0xFF4285F4));

    // White center hole
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.58,
      Paint()..color = Colors.white,
    );

    // Blue rectangle (right extension)
    final paint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.22, r * 1.02, r * 0.44),
      paint,
    );

    // White inner hole (re-draw to clip rect)
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.58,
      Paint()..color = Colors.white,
    );
  }

  void _arc(Canvas canvas, double cx, double cy, double r,
      double startDeg, double sweepDeg, Color color) {
    final paint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = r * 0.42;
    const d2r = 3.14159265 / 180;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.79),
      startDeg * d2r,
      sweepDeg * d2r,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
