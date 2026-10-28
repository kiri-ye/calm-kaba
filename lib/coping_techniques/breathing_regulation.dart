import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/design_system.dart';

class BreathingRegulationPage extends StatefulWidget {
  const BreathingRegulationPage({super.key});

  @override
  State<BreathingRegulationPage> createState() => _BreathingRegulationPageState();
}

class _BreathingRegulationPageState extends State<BreathingRegulationPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  bool _isRunning = false;
  int _currentPhase = 0; // 0=Inhale, 1=Hold, 2=Exhale
  String _instructionText = "Ready?";
  String _subInstructionText = "Press start to begin";

  int _completedCycles = 0;
  int _targetCycles = 0;

  @override
  void initState() {
    super.initState();
    // 4s inhale, 7s hold, 8s exhale = 19 seconds total
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 19),
    );

    // Expansion (0.0 to 4.0 seconds) -> 4/19 = 0.2105
    // Hold (4.0 to 11.0 seconds) -> 11/19 = 0.5789
    // Contraction (11.0 to 19.0 seconds) -> 1.0
    _scaleAnimation = TweenSequence([
      // Reduced maximum scale from 2.2 to 1.8 to prevent visual clutter
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.8), weight: 4.0),
      TweenSequenceItem(tween: Tween<double>(begin: 1.8, end: 1.8), weight: 7.0),
      TweenSequenceItem(tween: Tween<double>(begin: 1.8, end: 1.0), weight: 8.0),
    ]).animate(_controller);

    _controller.addListener(_updatePhase);
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _completedCycles++;
      if (_completedCycles >= _targetCycles) {
        // We finished the session
        setState(() {
          _isRunning = false;
          _instructionText = "Session Complete";
          _subInstructionText = "Great job finding your center.";
          _controller.reset();
          _completedCycles = 0;
        });
      } else {
        // Loop again
        _controller.forward(from: 0.0);
      }
    }
  }

  void _updatePhase() {
    // Keep default instruction state if animation hasn't started yet
    if (!_isRunning && _controller.value == 0.0 && (_instructionText == "Ready?" || _instructionText == "Session Complete")) {
       return;
    }
    
    final t = _controller.value;
    int newPhase = 0;
    String newInst = "";
    String newSub = "";

    if (t < 0.2105) {
      newPhase = 0;
      newInst = "Inhale...";
      newSub = "Breathe in gently";
    } else if (t < 0.5789) {
      newPhase = 1;
      newInst = "Hold";
      newSub = "Hold your breath";
    } else {
      newPhase = 2;
      newInst = "Exhale...";
      newSub = "Release slowly";
    }
    
    if (newPhase != _currentPhase || newInst != _instructionText) {
      setState(() {
        _currentPhase = newPhase;
        _instructionText = newInst;
        _subInstructionText = newSub;
      });
    }
  }

  void _startSession(int cycles) {
    setState(() {
      _targetCycles = cycles;
      _completedCycles = 0;
      _isRunning = true;
    });
    _controller.forward(from: 0.0);
    _updatePhase();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _controller.stop();
      setState(() => _isRunning = false);
    } else {
      if (_controller.value == 0.0 && _completedCycles == 0) {
        // Start exactly 4 cycles immediately for breathing regulation
        _startSession(4);
      } else {
        // Resume
        _controller.forward(from: _controller.value);
        setState(() => _isRunning = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      alignment: Alignment.center,
      width: 140, // increased to make it the highlight
      height: 140,
      child: SvgPicture.asset(
        'assets/images/pufferFish.svg',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildPhaseBox(String title, String duration, bool isActive, bool isLightMode) {
    return Expanded(
      flex: isActive ? 11 : 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        height: isActive ? 85 : 70, // Reduced from 110 / 90
        decoration: BoxDecoration(
          color: isActive 
              ? (isLightMode ? AppColors.elizabeth : AppColors.primary)
              : (isLightMode ? Theme.of(context).extension<AppColorsExtension>()!.cardBackground : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive 
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] 
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title, 
              style: AppTypography.labelSmall.copyWith( // Reduced from labelMedium
                color: isActive ? Colors.white : (isLightMode ? AppColors.textPrimary : AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              duration, 
              style: AppTypography.titleMedium.copyWith( // Reduced from titleLarge
                color: isActive ? (isLightMode ? AppColors.arden : AppColors.teaGreen) : (isLightMode ? AppColors.tertiary : AppColors.secondary),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // Allow exit if not started, or if session is fully complete
    if (!_isRunning && (_instructionText == "Ready?" || _instructionText == "Session Complete")) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isLightMode = Theme.of(context).brightness == Brightness.light;
        return AlertDialog(
          backgroundColor: isLightMode ? Theme.of(context).extension<AppColorsExtension>()!.secondaryBackground : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Exit Session?', 
            style: AppTypography.titleLarge.copyWith(color: AppColors.primary),
          ),
          content: Text(
            'Are you sure you want to exit before completing 4-7-8 Breathing?',
            style: AppTypography.bodyMedium.copyWith(color: isLightMode ? AppColors.textPrimary : AppColors.secondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AppTypography.titleMedium.copyWith(color: AppColors.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Exit', style: AppTypography.titleMedium.copyWith(color: AppColors.pinkCarnation)),
            ),
          ],
        );
      }
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0, bottom: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
                  onPressed: () async {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            
            // Header Texts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4-7-8 Breathing',
                    style: AppTypography.headlineMedium.copyWith( // Reduced from displaySmall
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced spacing
                  Text(
                    'Longer exhales to drop your spiked heart rate. Do NOT use when hyperventilating.',
                    style: AppTypography.titleSmall.copyWith(color: AppColors.arden), // Reduced from titleLarge
                  ),
                ],
              ),
            ),
            
            // Animated Placeholder Image
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: _buildImagePlaceholder(),
                    );
                  }
                ),
              ),
            ),
            
            // Instruction Texts (Centered perfectly)
            SizedBox(
              height: 70, // Slightly reduced
              width: double.infinity, // Forces exact horizontal centering
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey<String>(_instructionText),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _instructionText,
                      style: AppTypography.headlineSmall.copyWith( // Reduced from headlineMedium
                        color: AppColors.primary, 
                        fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subInstructionText,
                      style: AppTypography.titleSmall.copyWith( // Reduced from titleMedium
                        color: AppColors.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Cycle Indicator
            if (_isRunning || _completedCycles > 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '${_completedCycles + 1}/$_targetCycles Cycles',
                    style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // 3 Phase Containers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0), // Slightly more horizontal padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPhaseBox('Inhale', '4s', _currentPhase == 0, isLightMode),
                  _buildPhaseBox('Hold', '7s', _currentPhase == 1, isLightMode),
                  _buildPhaseBox('Exhale', '8s', _currentPhase == 2, isLightMode),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Start/Pause Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
                label: Text(
                  _isRunning ? 'Pause' : 'Start',
                  style: AppTypography.titleMedium.copyWith(color: Colors.white), // Reduced from titleLarge
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), // Reduced padding
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
              ),
            ),
            
            const SizedBox(height: 32), // Reduced from 40
          ],
        ),
      ),
      ),
    );
  }
}
