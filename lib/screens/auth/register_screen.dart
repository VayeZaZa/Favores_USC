import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import 'favores_brand.dart';

/// Pantalla de Registro Institucional (RF01, RN01)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _navy = Color(0xFF344B73);
  static const _blue = Color(0xFF7D96BE);
  static const _mutedBlue = Color(0xFF7A8BA9);
  static const _borderBlue = Color(0xFFDEE5F0);

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  late final _authService = AuthService();

  String? _programaSeleccionado;
  int? _semestreSeleccionado;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_programaSeleccionado == null) {
      setState(
        () => _errorMessage = 'Por favor selecciona tu programa académico',
      );
      return;
    }

    if (_semestreSeleccionado == null) {
      setState(() => _errorMessage = 'Por favor selecciona tu semestre actual');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.registrarUsuario(
        nombre: _nombreController.text,
        correo: _correoController.text,
        password: _passwordController.text,
        programa: _programaSeleccionado!,
        semestre: _semestreSeleccionado!,
        telefono: _telefonoController.text,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.mark_email_read_rounded,
            color: AppTheme.successColor,
            size: 48,
          ),
          title: const Text('¡Registro Exitoso!'),
          content: Text(
            'Solicitamos un enlace de verificación para ${_correoController.text.trim()}.\n\n'
            'Revisa Recibidos, Spam y Promociones. Si no llega, intenta iniciar sesión '
            'con tu contraseña y usa “Reenviar verificación”.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Ir al Login'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      bottomNavigationBar: const _RegisterFooter(),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 5, 18, 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            tooltip: 'Volver',
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: _navy,
                            ),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          const Spacer(),
                          const FavoresBrand(
                            foregroundColor: _navy,
                            accentColor: _blue,
                            surfaceColor: Color(0xFFEAF0FA),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 8),
                                Text(
                                  'Crear cuenta',
                                  style: TextStyle(
                                    color: _navy,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Únete a la comunidad USC y aprovecha todos los beneficios.',
                                  style: TextStyle(
                                    color: _mutedBlue,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 116,
                              height: 142,
                              color: const Color(0xFFFFF1F1),
                              child: Image.asset(
                                'assets/images/icon para registro.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Form(
                        key: _formKey,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            inputDecorationTheme: InputDecorationTheme(
                              filled: true,
                              fillColor: Color(0xFFFDFEFF),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 11,
                              ),
                              labelStyle: const TextStyle(
                                color: _mutedBlue,
                                fontSize: 12,
                              ),
                              hintStyle: const TextStyle(
                                color: Color(0xFF9AA8BF),
                                fontSize: 12,
                              ),
                              prefixIconColor: _blue,
                              suffixIconColor: _blue,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: _borderBlue,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: _borderBlue,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: _blue,
                                  width: 1.4,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: AppTheme.errorColor,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: AppTheme.errorColor,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Datos personales',
                                style: TextStyle(
                                  color: _navy,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Regístrate con tu correo @usc.edu.co',
                                style: TextStyle(
                                  color: _mutedBlue,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: AppTheme.errorColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.errorColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 9),
                              ],
                              TextFormField(
                                controller: _nombreController,
                                textCapitalization: TextCapitalization.words,
                                validator: (value) =>
                                    Validators.validateRequired(
                                      value,
                                      'El nombre',
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Nombre completo',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    size: 19,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              TextFormField(
                                controller: _correoController,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.validateEmail,
                                decoration: const InputDecoration(
                                  labelText: 'Correo institucional',
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    size: 19,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: Validators.validatePassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña (mín. 6 caracteres)',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 19,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 19,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              DropdownButtonFormField<String>(
                                initialValue: _programaSeleccionado,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Programa académico',
                                  prefixIcon: Icon(
                                    Icons.school_outlined,
                                    size: 19,
                                  ),
                                ),
                                items: AppConstants.programasAcademicos
                                    .map(
                                      (programa) => DropdownMenuItem(
                                        value: programa,
                                        child: Text(
                                          programa,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(
                                  () => _programaSeleccionado = value,
                                ),
                                validator: (value) => value == null
                                    ? 'Selecciona tu programa'
                                    : null,
                              ),
                              const SizedBox(height: 9),
                              DropdownButtonFormField<int>(
                                initialValue: _semestreSeleccionado,
                                decoration: const InputDecoration(
                                  labelText: 'Semestre actual',
                                  prefixIcon: Icon(
                                    Icons.calendar_month_outlined,
                                    size: 19,
                                  ),
                                ),
                                items: List.generate(12, (index) => index + 1)
                                    .map(
                                      (semestre) => DropdownMenuItem(
                                        value: semestre,
                                        child: Text(
                                          'Semestre $semestre',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(
                                  () => _semestreSeleccionado = value,
                                ),
                                validator: (value) => value == null
                                    ? 'Selecciona tu semestre'
                                    : null,
                              ),
                              const SizedBox(height: 9),
                              TextFormField(
                                controller: _telefonoController,
                                keyboardType: TextInputType.phone,
                                validator: Validators.validateTelefono,
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono móvil',
                                  prefixIcon: Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 19,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _blue,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text('Crear cuenta'),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => Navigator.maybePop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: _mutedBlue,
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text(
                                  'Ya tengo una cuenta · Iniciar sesión',
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
            );
          },
        ),
      ),
    );
  }
}

class _RegisterFooter extends StatelessWidget {
  const _RegisterFooter();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFF8F7),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 112,
          width: double.infinity,
          child: Image.asset(
            'assets/images/footer registro.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}
