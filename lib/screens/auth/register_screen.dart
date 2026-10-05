import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';

/// Pantalla de Registro Institucional (RF01, RN01)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
      setState(() => _errorMessage = 'Por favor selecciona tu programa académico');
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

      // Diálogo informativo de verificación por correo (RF01)
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
            'Hemos enviado un enlace de verificación a ${_correoController.text.trim()}.\n\n'
            'Abre el enlace en tu correo institucional para activar tu cuenta e iniciar sesión.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Cerrar diálogo
                Navigator.pop(context); // Volver al login
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
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.groups_rounded, color: Colors.white, size: 34),
                    SizedBox(height: 12),
                    Text(
                      'Tu comunidad te espera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Crea tu cuenta USC y conecta con estudiantes que se ayudan.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryDark.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Datos personales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Regístrate con tu correo @usc.edu.co',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.errorColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _nombreController,
                        textCapitalization: TextCapitalization.words,
                        validator: (val) => Validators.validateRequired(val, 'El nombre'),
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _correoController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Correo institucional',
                          hintText: 'ejemplo@usc.edu.co',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: Validators.validatePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña (mínimo 6 caracteres)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      DropdownButtonFormField<String>(
                        initialValue: _programaSeleccionado,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Programa académico',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: AppConstants.programasAcademicos.map((prog) {
                          return DropdownMenuItem(
                            value: prog,
                            child: Text(prog, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _programaSeleccionado = val),
                        validator: (val) => val == null ? 'Selecciona tu programa' : null,
                      ),
                      const SizedBox(height: 13),
                      DropdownButtonFormField<int>(
                        initialValue: _semestreSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Semestre actual',
                          prefixIcon: Icon(Icons.timeline_rounded),
                        ),
                        items: List.generate(12, (index) => index + 1).map((sem) {
                          return DropdownMenuItem(
                            value: sem,
                            child: Text('Semestre $sem'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _semestreSeleccionado = val),
                        validator: (val) => val == null ? 'Selecciona tu semestre' : null,
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        validator: Validators.validateTelefono,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono móvil',
                          hintText: '3001234567',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Crear cuenta'),
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
  }
}
