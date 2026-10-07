import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import 'favores_brand.dart';
import '../favores/favores_feed_screen.dart';
import 'register_screen.dart';

/// Pantalla de Inicio de Sesión (RF02)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _navy = Color(0xFF111B43);
  static const _panelBlue = Color(0xFF28365F);
  static const _softBlue = Color(0xFFA9BDE9);
  static const _gold = Color(0xFFFFD981);

  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _mostrarReenvioVerificacion = false;

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _mostrarReenvioVerificacion = false;
    });

    try {
      final usuario = await _authService.iniciarSesion(
        correo: _correoController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido, ${usuario.nombre}!'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Redirigir al Feed de Favores (RF03, RNF02)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const FavoresFeedScreen(),
        ),
      );
    } catch (e) {
      final errorStr = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _errorMessage = errorStr;
        _mostrarReenvioVerificacion = errorStr.contains('EMAIL_NOT_VERIFIED');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReenviarVerificacion() async {
    try {
      await _authService.reenviarEnlaceVerificacion(
        correo: _correoController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitamos un nuevo enlace. Revisa también Spam y Promociones.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reenviar: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _handlePasswordRecovery() async {
    final emailError = Validators.validateEmail(_correoController.text);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Escribe tu correo institucional primero. $emailError'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      await _authService.enviarEnlaceRecuperacion(
        correo: _correoController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviamos un enlace para restablecer tu contraseña.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos enviar el enlace: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      bottomNavigationBar: _AuthFooter(
        asset: 'assets/images/footer inicio.png',
        backgroundColor: _navy,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _softBlue.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(13, 4, 13, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                tooltip: 'Volver',
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              const Spacer(),
                              const FavoresBrand(
                                foregroundColor: Colors.white,
                                accentColor: _gold,
                                surfaceColor: _panelBlue,
                              ),
                            ],
                          ),
                        ),
                        const _LoginHero(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 10, 22, 17),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  _LoginError(
                                    message: _errorMessage!,
                                    showResend: _mostrarReenvioVerificacion,
                                    onResend: _handleReenviarVerificacion,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    inputDecorationTheme:
                                        const InputDecorationTheme(
                                          filled: true,
                                          fillColor: _panelBlue,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 13,
                                          ),
                                          labelStyle: TextStyle(
                                            color: _softBlue,
                                            fontSize: 12,
                                          ),
                                          hintStyle: TextStyle(
                                            color: _softBlue,
                                            fontSize: 12,
                                          ),
                                          prefixIconColor: Colors.white,
                                          suffixIconColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(22),
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(0xFF47577F),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(22),
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(0xFF47577F),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(22),
                                            ),
                                            borderSide: BorderSide(
                                              color: _softBlue,
                                              width: 1.4,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(22),
                                            ),
                                            borderSide: BorderSide(
                                              color: AppTheme.errorColor,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(22),
                                                ),
                                                borderSide: BorderSide(
                                                  color: AppTheme.errorColor,
                                                  width: 1.4,
                                                ),
                                              ),
                                        ),
                                  ),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _correoController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: Validators.validateEmail,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Correo institucional',
                                          prefixIcon: Icon(
                                            Icons.mail_outline_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        validator: Validators.validatePassword,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Contraseña',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                          ),
                                          suffixIcon: IconButton(
                                            tooltip: _obscurePassword
                                                ? 'Mostrar contraseña'
                                                : 'Ocultar contraseña',
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              size: 18,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      height: 30,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) => setState(
                                          () => _rememberMe = value ?? false,
                                        ),
                                        activeColor: const Color(0xFF748DBF),
                                        side: const BorderSide(
                                          color: _softBlue,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Recordarme',
                                      style: TextStyle(
                                        color: _softBlue,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _handlePasswordRecovery,
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            textStyle: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          child: const Text(
                                            '¿Olvidaste tu contraseña?',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _gold,
                                      foregroundColor: _navy,
                                      shape: const StadiumBorder(),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 19,
                                            height: 19,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _navy,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('Entrar'),
                                              SizedBox(width: 9),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 17,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: _softBlue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 9,
                                      ),
                                      child: Text(
                                        '¿No tienes cuenta?',
                                        style: TextStyle(
                                          color: _softBlue,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: _softBlue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: _openRegister,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _softBlue,
                                      side: const BorderSide(
                                        color: Color(0xFF7188B7),
                                      ),
                                      shape: const StadiumBorder(),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text('Regístrate'),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 15,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/icon arriba para inicio de sesion.png',
      width: double.infinity,
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter({required this.asset, required this.backgroundColor});

  final String asset;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 112,
          width: double.infinity,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({
    required this.message,
    required this.showResend,
    required this.onResend,
  });

  final String message;
  final bool showResend;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Color(0xFFFFC3C9), fontSize: 12),
          ),
          if (showResend)
            TextButton.icon(
              onPressed: onResend,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: const Text('Reenviar verificación'),
              style: TextButton.styleFrom(
                foregroundColor: _LoginScreenState._gold,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}
