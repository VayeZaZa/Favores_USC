import 'dart:async';

import 'package:flutter/material.dart';

import 'favores_brand.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _slides = [
    _WelcomeSlide(
      image: 'assets/images/slide 1.png',
      titleBefore: 'Tu universidad,\n',
      titleHighlight: 'más cerca',
      description: 'Conecta · Comparte · Apoya',
    ),
    _WelcomeSlide(
      image: 'assets/images/slide 2.png',
      titleBefore: 'La vida en la USC,\n',
      titleHighlight: 'se hace en equipo',
      description:
          'Pide una mano, ofrece la tuya y hagan más fácil el día a día.',
    ),
    _WelcomeSlide(
      image: 'assets/images/slide 3.png',
      titleBefore: 'Lo que se pierde,\n',
      titleHighlight: 'puede volver',
      description: 'Reporta objetos y ayuda a reunir cada cosa con quien la está buscando.',
    ),
  ];

  static const _navy = Color(0xFF101F58);
  static const _gold = Color(0xFFFFD34E);
  static const _mutedBlue = Color(0xFFAFC2FF);

  final _pageController = PageController();
  Timer? _slideTimer;
  Timer? _loadingTimer;
  int _currentPage = 0;
  int _activeLoadingDot = 0;
  bool _isPageLoading = false;
  bool _imagesPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_imagesPrecached) return;
    _imagesPrecached = true;
    for (final slide in _slides) {
      precacheImage(AssetImage(slide.image), context);
    }
  }

  @override
  void initState() {
    super.initState();
    _slideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _loadingTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _loadingTimer?.cancel();
    setState(() {
      _currentPage = page;
      _activeLoadingDot = 0;
      _isPageLoading = true;
    });

    var loadingTicks = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      loadingTicks++;
      if (loadingTicks >= 4) {
        timer.cancel();
        setState(() => _isPageLoading = false);
        return;
      }
      setState(() {
        _activeLoadingDot = (_activeLoadingDot + 1) % 3;
      });
    });
  }

  void _openLogin() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  void _goToNextPage() {
    if (_currentPage == _slides.length - 1) {
      _openLogin();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => Image.asset(
              _slides[index].image,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          if (_isPageLoading)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _activeLoadingDot == index
                            ? _gold
                            : Colors.white.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const FavoresBrand(
                        foregroundColor: Colors.white,
                        accentColor: _gold,
                        surfaceColor: Color(0xB3101F58),
                      ),
                      Text(
                        '${(_currentPage + 1).toString().padLeft(2, '0')} / ${_slides.length.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          shadows: [Shadow(color: _navy, blurRadius: 10)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _WelcomeSlideText(slide: _slides[_currentPage]),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Semantics(
                          button: true,
                          label: 'Ir a la diapositiva ${index + 1}',
                          child: GestureDetector(
                            onTap: () => _goToPage(index),
                            child: _PageDot(active: index == _currentPage),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _navy,
                        elevation: 6,
                        shadowColor: _navy.withValues(alpha: 0.35),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _slides.length - 1
                                ? 'Comenzar'
                                : 'Siguiente',
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: _openLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: _mutedBlue,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: _navy, blurRadius: 8)],
                        ),
                      ),
                      child: const Text('Ya tengo una cuenta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.image,
    required this.titleBefore,
    required this.titleHighlight,
    required this.description,
  });

  final String image;
  final String titleBefore;
  final String titleHighlight;
  final String description;
}

class _WelcomeSlideText extends StatelessWidget {
  const _WelcomeSlideText({required this.slide});

  final _WelcomeSlide slide;

  static const _gold = Color(0xFFFFD34E);
  static const _navy = Color(0xFF101F58);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: slide.titleBefore),
              TextSpan(
                text: slide.titleHighlight,
                style: const TextStyle(color: _gold),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 31,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            shadows: [Shadow(color: _navy, blurRadius: 12)],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          slide.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: _navy, blurRadius: 12)],
          ),
        ),
      ],
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({required this.active});

  final bool active;

  static const _gold = Color(0xFFFFD34E);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? _gold : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0xFF101F58), blurRadius: 8)],
      ),
    );
  }
}
