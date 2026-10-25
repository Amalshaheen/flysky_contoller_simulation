import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const JoystickApp());
}

const String kTargetDeviceName = 'ESP32_Rover';
final Guid kTargetServiceUuid = Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
final Guid kTargetCharacteristicUuid = Guid(
  '0000ffe1-0000-1000-8000-00805f9b34fb',
);
const Duration kThrottleWindow = Duration(milliseconds: 50);
const int kAxisMin = -255;
const int kAxisMax = 255;

class JoystickApp extends StatelessWidget {
  const JoystickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07111F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const JoystickScreen(),
    );
  }
}

class JoystickScreen extends StatefulWidget {
  const JoystickScreen({super.key});

  @override
  State<JoystickScreen> createState() => _JoystickScreenState();
}

class _JoystickScreenState extends State<JoystickScreen> {
  late final JoystickBloc _bloc;
  bool _isThrottleLeft = true;
  bool _isCustomizeMode = false;
  double _throttleWidth = 150.0;
  double _throttleHeight = 240.0;
  Alignment _throttleAlignment = const Alignment(-1.0, 0.0);
  double _steeringWidth = 380.0;
  double _steeringHeight = 150.0;
  Alignment _steeringAlignment = const Alignment(1.0, 0.0);

  @override
  void initState() {
    super.initState();
    _bloc = JoystickBloc();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bloc.start();
    });
  }

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          return Stack(
            children: [
              // Deep space cyber background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF040A12),
                        Color(0xFF0A1829),
                        Color(0xFF051D28),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        const Color(0xFF00E5FF).withOpacity(0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: _BackgroundTechLines()),

              // Content based on orientation
              Positioned.fill(
                child: SafeArea(
                  child: isPortrait
                      ? _buildPortraitLayout()
                      : _buildLandscapeLayout(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Top status card
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1727).withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'FLYSKY SIMULATOR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          StreamBuilder<JoystickState>(
                            stream: _bloc.stream,
                            initialData: _bloc.state,
                            builder: (context, snapshot) {
                              final state = snapshot.data ?? _bloc.state;
                              return Text(
                                state.statusMessage,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<JoystickState>(
                      stream: _bloc.stream,
                      initialData: _bloc.state,
                      builder: (context, snapshot) {
                        final state = snapshot.data ?? _bloc.state;
                        return _TopStatusBar(state: state, bloc: _bloc);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Dynamic spacer to push components to the bottom of the screen
        const Spacer(),

        // Telemetry display (above joystick)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: StreamBuilder<JoystickState>(
            stream: _bloc.stream,
            initialData: _bloc.state,
            builder: (context, snapshot) {
              final state = snapshot.data ?? _bloc.state;
              return _TelemetryDisplay(x: state.x, y: state.y);
            },
          ),
        ),

        const SizedBox(height: 24), // spacing between telemetry and joystick
        // Joystick (at the bottom)
        Center(child: _GraphJoystick(bloc: _bloc)),

        const SizedBox(
          height: 70,
        ), // space below joystick to keep it comfortable to hold
      ],
    );
  }

  void _onControlDrag(
    JoystickAxis axis,
    DragUpdateDetails details,
    Size screenSize,
  ) {
    if (!_isCustomizeMode) return;
    setState(() {
      final dx = 2 * details.delta.dx / screenSize.width;
      final dy = 2 * details.delta.dy / screenSize.height;
      if (axis == JoystickAxis.y) {
        _throttleAlignment = Alignment(
          (_throttleAlignment.x + dx).clamp(-1.0, 1.0),
          (_throttleAlignment.y + dy).clamp(-1.0, 1.0),
        );
      } else {
        _steeringAlignment = Alignment(
          (_steeringAlignment.x + dx).clamp(-1.0, 1.0),
          (_steeringAlignment.y + dy).clamp(-1.0, 1.0),
        );
      }
    });
  }

  Widget _buildLandscapeLayout() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

          final throttleWidget = SizedBox(
            width: _throttleWidth,
            height: _throttleHeight,
            child: StreamBuilder<int>(
              stream: _bloc.stream.map((s) => s.y).distinct(),
              initialData: _bloc.state.y,
              builder: (context, snapshot) {
                final yValue = snapshot.data ?? _bloc.state.y;
                return _ControlCard(
                  title: 'THROTTLE',
                  subtitle: 'Y-Axis',
                  value: yValue,
                  isCustomizeMode: _isCustomizeMode,
                  width: _throttleWidth,
                  height: _throttleHeight,
                  onWidthChanged: (val) {
                    setState(() => _throttleWidth = val);
                  },
                  onHeightChanged: (val) {
                    setState(() => _throttleHeight = val);
                  },
                  onPresetSelected: (alignment) {
                    setState(() => _throttleAlignment = alignment);
                  },
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: _ColoredTrackSlider(
                      value: yValue,
                      onChanged: (val) => _bloc.setAxis(JoystickAxis.y, val),
                      onChangeEnd: (val) =>
                          _bloc.snapAxisToCenter(JoystickAxis.y),
                    ),
                  ),
                );
              },
            ),
          );

          final steeringWidget = SizedBox(
            width: _steeringWidth,
            height: _steeringHeight,
            child: StreamBuilder<int>(
              stream: _bloc.stream.map((s) => s.x).distinct(),
              initialData: _bloc.state.x,
              builder: (context, snapshot) {
                final xValue = snapshot.data ?? _bloc.state.x;
                return _ControlCard(
                  title: 'STEERING',
                  subtitle: 'X-Axis',
                  value: xValue,
                  isCustomizeMode: _isCustomizeMode,
                  width: _steeringWidth,
                  height: _steeringHeight,
                  onWidthChanged: (val) {
                    setState(() => _steeringWidth = val);
                  },
                  onHeightChanged: (val) {
                    setState(() => _steeringHeight = val);
                  },
                  onPresetSelected: (alignment) {
                    setState(() => _steeringAlignment = alignment);
                  },
                  child: Center(
                    child: _ColoredTrackSlider(
                      value: xValue,
                      onChanged: (val) => _bloc.setAxis(JoystickAxis.x, val),
                      onChangeEnd: (val) =>
                          _bloc.snapAxisToCenter(JoystickAxis.x),
                    ),
                  ),
                );
              },
            ),
          );

          return Stack(
            children: [
              // Center control panel column
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 150,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StreamBuilder<JoystickState>(
                        stream: _bloc.stream,
                        initialData: _bloc.state,
                        builder: (context, snapshot) {
                          final state = snapshot.data ?? _bloc.state;
                          return _TopStatusBar(state: state, bloc: _bloc);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildSwapToggle(),
                      const SizedBox(height: 16),
                      _buildCustomizeToggle(),
                    ],
                  ),
                ),
              ),

              // Floating edit mode reminder banner
              if (_isCustomizeMode)
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit,
                          color: Color(0xFFFF9800),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CUSTOMIZE LAYOUT: Drag cards to reposition',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF9800).withOpacity(0.9),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Throttle control alignment wrapper
              Align(
                alignment: _throttleAlignment,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: _isCustomizeMode
                      ? (details) =>
                            _onControlDrag(JoystickAxis.y, details, screenSize)
                      : null,
                  child: throttleWidget,
                ),
              ),

              // Steering control alignment wrapper
              Align(
                alignment: _steeringAlignment,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: _isCustomizeMode
                      ? (details) =>
                            _onControlDrag(JoystickAxis.x, details, screenSize)
                      : null,
                  child: steeringWidget,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomizeToggle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CUSTOMIZE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _isCustomizeMode = !_isCustomizeMode;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 120,
            height: 38,
            decoration: BoxDecoration(
              color: _isCustomizeMode
                  ? const Color(0xFFFF9800).withOpacity(0.12)
                  : const Color(0xFF0D1727).withOpacity(0.55),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: _isCustomizeMode
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF00E5FF).withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: _isCustomizeMode
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                _isCustomizeMode ? 'DONE' : 'EDIT LAYOUT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: _isCustomizeMode
                      ? const Color(0xFFFF9800)
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwapToggle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LAYOUT',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _isThrottleLeft = !_isThrottleLeft;
              if (_isThrottleLeft) {
                _throttleAlignment = const Alignment(-1.0, 0.0);
                _steeringAlignment = const Alignment(1.0, 0.0);
              } else {
                _throttleAlignment = const Alignment(1.0, 0.0);
                _steeringAlignment = const Alignment(-1.0, 0.0);
              }
            });
          },
          child: Container(
            width: 120,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1727).withOpacity(0.55),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  left: _isThrottleLeft ? 2 : 60,
                  top: 2,
                  child: Container(
                    width: 58,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E5FF).withOpacity(0.2),
                          const Color(0xFF00838F).withOpacity(0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'THR L',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: _isThrottleLeft
                                ? const Color(0xFF00E5FF)
                                : Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'THR R',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: !_isThrottleLeft
                                ? const Color(0xFF00E5FF)
                                : Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackgroundTechLines extends StatelessWidget {
  const _BackgroundTechLines();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TechLinesPainter());
  }
}

class _TechLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1.0;

    const dotSpacing = 30.0;
    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }

    final accentPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.04)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(170, 40),
      Offset(170, size.height - 40),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.child,
    this.isCustomizeMode = false,
    this.width,
    this.height,
    this.onWidthChanged,
    this.onHeightChanged,
    this.onPresetSelected,
  });

  final String title;
  final String subtitle;
  final int value;
  final Widget child;
  final bool isCustomizeMode;
  final double? width;
  final double? height;
  final ValueChanged<double>? onWidthChanged;
  final ValueChanged<double>? onHeightChanged;
  final ValueChanged<Alignment>? onPresetSelected;

  Widget _presetChip(String label, Alignment alignment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: GestureDetector(
        onTap: () {
          if (onPresetSelected != null) {
            onPresetSelected!(alignment);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: Border.all(
              color: const Color(0xFFFF9800).withOpacity(0.6),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9800),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1727).withOpacity(0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCustomizeMode
                  ? const Color(0xFFFF9800)
                  : Colors.white.withOpacity(0.08),
              width: isCustomizeMode ? 2.0 : 1.5,
            ),
            boxShadow: [
              if (isCustomizeMode)
                BoxShadow(
                  color: const Color(0xFFFF9800).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: isCustomizeMode ? 0.15 : 1.0,
                  child: IgnorePointer(
                    ignoring: isCustomizeMode,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 12),
                      child: child,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 18,
                child: Opacity(
                  opacity: isCustomizeMode ? 0.15 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 18,
                child: Opacity(
                  opacity: isCustomizeMode ? 0.15 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      value.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),

              // Customize Overlay HUD
              if (isCustomizeMode)
                Positioned.fill(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.open_with,
                                  color: Color(0xFFFF9800),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF9800),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _presetChip(
                                    'TL',
                                    const Alignment(-1.0, -1.0),
                                  ),
                                  _presetChip('TR', const Alignment(1.0, -1.0)),
                                  _presetChip('FL', const Alignment(-1.0, 0.0)),
                                  _presetChip('CTR', const Alignment(0.0, 0.0)),
                                  _presetChip('FR', const Alignment(1.0, 0.0)),
                                  _presetChip('BL', const Alignment(-1.0, 1.0)),
                                  _presetChip('BR', const Alignment(1.0, 1.0)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.swap_horiz,
                                    color: Color(0xFFFF9800),
                                    size: 14,
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 10,
                                            ),
                                        activeTrackColor: const Color(
                                          0xFFFF9800,
                                        ),
                                        inactiveTrackColor: Colors.white10,
                                        thumbColor: const Color(0xFFFF9800),
                                      ),
                                      child: Slider(
                                        value: width!,
                                        min: title == 'THROTTLE'
                                            ? 100.0
                                            : 250.0,
                                        max: title == 'THROTTLE'
                                            ? 250.0
                                            : 550.0,
                                        onChanged: onWidthChanged,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.swap_vert,
                                    color: Color(0xFFFF9800),
                                    size: 14,
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 10,
                                            ),
                                        activeTrackColor: const Color(
                                          0xFFFF9800,
                                        ),
                                        inactiveTrackColor: Colors.white10,
                                        thumbColor: const Color(0xFFFF9800),
                                      ),
                                      child: Slider(
                                        value: height!,
                                        min: title == 'THROTTLE'
                                            ? 200.0
                                            : 130.0,
                                        max: title == 'THROTTLE'
                                            ? 400.0
                                            : 250.0,
                                        onChanged: onHeightChanged,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _TransparentSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _TransparentSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    // Empty implementation to make it completely invisible
  }
}

class _ColoredTrackSlider extends StatefulWidget {
  const _ColoredTrackSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_ColoredTrackSlider> createState() => _ColoredTrackSliderState();
}

class _ColoredTrackSliderState extends State<_ColoredTrackSlider> {
  double? _localValue;

  @override
  void didUpdateWidget(covariant _ColoredTrackSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _localValue = widget.value.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = _localValue ?? widget.value.toDouble();
    final intensity = (currentValue.abs() / 255.0).clamp(0.0, 1.0);

    final trackColor = Color.lerp(
      const Color(0xFF0D1727).withOpacity(0.55),
      const Color(0xFFFF5252).withOpacity(0.45),
      intensity,
    );

    final borderColor = Color.lerp(
      Colors.white.withOpacity(0.08),
      const Color(0xFFFF5252).withOpacity(0.8),
      intensity,
    );

    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor!, width: 1.5),
                boxShadow: intensity > 0.01
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFFFF5252,
                          ).withOpacity(0.3 * intensity),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          Container(width: 3, height: 36, color: Colors.white.withOpacity(0.5)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 28,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.15),
              trackShape: const _TransparentSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 50,
                pressedElevation: 10.0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 32),
            ),
            child: Slider(
              min: kAxisMin.toDouble(),
              max: kAxisMax.toDouble(),
              value: currentValue,
              onChanged: (newValue) {
                setState(() {
                  _localValue = newValue;
                });
                widget.onChanged(newValue);
              },
              onChangeEnd: (newValue) {
                setState(() {
                  _localValue = null;
                });
                widget.onChangeEnd(newValue);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({required this.state, required this.bloc});

  final JoystickState state;
  final JoystickBloc bloc;

  @override
  Widget build(BuildContext context) {
    final phase = state.connectionPhase;

    Color statusColor;
    IconData iconData;
    bool isSearching = false;

    switch (phase) {
      case ConnectionPhase.connected:
        statusColor = const Color(0xFF3EE08A);
        iconData = Icons.bluetooth_connected;
        break;
      case ConnectionPhase.scanning:
      case ConnectionPhase.connecting:
        statusColor = const Color(0xFFFFC857);
        iconData = Icons.bluetooth_searching;
        isSearching = true;
        break;
      case ConnectionPhase.error:
        statusColor = const Color(0xFFFF6B6B);
        iconData = Icons.bluetooth;
        break;
      case ConnectionPhase.idle:
      default:
        statusColor = Colors.white.withOpacity(0.4);
        iconData = Icons.bluetooth;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (phase == ConnectionPhase.connected ||
                phase == ConnectionPhase.scanning ||
                phase == ConnectionPhase.connecting) {
              bloc.disconnect();
            } else {
              bloc.start();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isSearching)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  Icon(iconData, color: statusColor.withOpacity(0.9), size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          phase == ConnectionPhase.connected
              ? (state.deviceName ?? kTargetDeviceName)
              : state.connectionPhase.label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: statusColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

enum JoystickAxis { x, y }

enum ConnectionPhase { idle, scanning, connecting, connected, error }

extension on ConnectionPhase {
  String get label => switch (this) {
    ConnectionPhase.idle => 'Idle',
    ConnectionPhase.scanning => 'Scanning',
    ConnectionPhase.connecting => 'Connecting',
    ConnectionPhase.connected => 'Connected',
    ConnectionPhase.error => 'Error',
  };
}

class JoystickState {
  const JoystickState({
    required this.connectionPhase,
    required this.statusMessage,
    required this.x,
    required this.y,
    this.deviceName,
    this.deviceId,
  });

  const JoystickState.initial()
    : connectionPhase = ConnectionPhase.scanning,
      statusMessage = 'Scanning for ESP32_Rover...',
      x = 0,
      y = 0,
      deviceName = null,
      deviceId = null;

  final ConnectionPhase connectionPhase;
  final String statusMessage;
  final int x;
  final int y;
  final String? deviceName;
  final String? deviceId;

  JoystickState copyWith({
    ConnectionPhase? connectionPhase,
    String? statusMessage,
    int? x,
    int? y,
    String? deviceName,
    String? deviceId,
    bool clearDeviceName = false,
    bool clearDeviceId = false,
  }) {
    return JoystickState(
      connectionPhase: connectionPhase ?? this.connectionPhase,
      statusMessage: statusMessage ?? this.statusMessage,
      x: x ?? this.x,
      y: y ?? this.y,
      deviceName: clearDeviceName ? null : deviceName ?? this.deviceName,
      deviceId: clearDeviceId ? null : deviceId ?? this.deviceId,
    );
  }
}

class JoystickBloc {
  JoystickBloc() {
    _emit(_state);
  }

  final StreamController<JoystickState> _controller =
      StreamController<JoystickState>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _throttleTimer;
  Future<void> _writeChain = Future<void>.value();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  DateTime _lastTransmission = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isDisposed = false;

  int _x = 0;
  int _y = 0;
  JoystickState _state = const JoystickState.initial();

  Stream<JoystickState> get stream => _controller.stream;
  JoystickState get state => _state;

  Future<void> start() async {
    if (_isDisposed) {
      return;
    }

    final permissionsGranted = await _ensureBlePermissions();
    if (!permissionsGranted) {
      _emit(
        _state.copyWith(
          connectionPhase: ConnectionPhase.error,
          statusMessage:
              'Bluetooth permission required. Please grant scan and connect permissions.',
        ),
      );
      return;
    }

    await _stopScan();
    await _disposeDeviceListeners();

    _emit(
      _state.copyWith(
        connectionPhase: ConnectionPhase.scanning,
        statusMessage: 'Scanning for $kTargetDeviceName...',
        clearDeviceName: true,
        clearDeviceId: true,
      ),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: (error, stackTrace) {
        _emit(
          _state.copyWith(
            connectionPhase: ConnectionPhase.error,
            statusMessage: 'Scan error: $error',
          ),
        );
      },
    );

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (error) {
      _emit(
        _state.copyWith(
          connectionPhase: ConnectionPhase.error,
          statusMessage: 'Unable to start scan: $error',
        ),
      );
    }
  }

  Future<bool> _ensureBlePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;

    return scanGranted && connectGranted;
  }

  Future<void> disconnect() async {
    _cancelThrottle();
    await _stopScan();
    await _disposeDeviceListeners();

    final device = _device;
    _device = null;
    _characteristic = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // Ignore disconnect failures; the UI is already reset locally.
      }
    }

    _emit(
      _state.copyWith(
        connectionPhase: ConnectionPhase.idle,
        statusMessage: 'Disconnected.',
        clearDeviceName: true,
        clearDeviceId: true,
      ),
    );
  }

  void setAxis(JoystickAxis axis, double value) {
    if (_isDisposed) {
      return;
    }

    final next = _clampAxis(value);
    if (axis == JoystickAxis.x) {
      _x = next;
    } else {
      _y = next;
    }

    _emit(_state.copyWith(x: _x, y: _y));
    _queueCurrentPayload(force: false);
  }

  void snapAxisToCenter(JoystickAxis axis) {
    if (_isDisposed) {
      return;
    }

    if (axis == JoystickAxis.x) {
      _x = 0;
    } else {
      _y = 0;
    }

    _emit(_state.copyWith(x: _x, y: _y));
    _queueCurrentPayload(force: true);
  }

  void setAxes(double xVal, double yVal) {
    if (_isDisposed) {
      return;
    }

    _x = _clampAxis(xVal);
    _y = _clampAxis(yVal);

    _emit(_state.copyWith(x: _x, y: _y));
    _queueCurrentPayload(force: false);
  }

  void snapAxesToCenter() {
    if (_isDisposed) {
      return;
    }

    _x = 0;
    _y = 0;

    _emit(_state.copyWith(x: _x, y: _y));
    _queueCurrentPayload(force: true);
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _cancelThrottle();
    unawaited(_stopScan());
    unawaited(_disposeDeviceListeners());
    unawaited(_device?.disconnect());
    _controller.close();
  }

  void _handleScanResults(List<ScanResult> results) {
    if (_isDisposed ||
        _state.connectionPhase == ConnectionPhase.connecting ||
        _state.connectionPhase == ConnectionPhase.connected) {
      return;
    }

    for (final result in results) {
      final name = result.device.platformName;
      if (name != kTargetDeviceName) {
        continue;
      }

      _emit(
        _state.copyWith(
          connectionPhase: ConnectionPhase.connecting,
          statusMessage: 'Found $kTargetDeviceName. Connecting...',
          deviceName: name,
          deviceId: result.device.remoteId.str,
        ),
      );

      unawaited(_connectToDevice(result.device));
      return;
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isDisposed) {
      return;
    }

    _device = device;
    await _stopScan();

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 20),
      );
    } catch (_) {
      // If already connected, flutter_blue_plus may throw. Continue to service discovery.
    }

    if (_isDisposed) {
      return;
    }

    try {
      final services = await device.discoverServices();
      _characteristic = _findWritableCharacteristic(services);

      if (_characteristic == null) {
        throw StateError(
          'Writable characteristic not found for the configured UUIDs.',
        );
      }

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (_isDisposed) {
          return;
        }
        if (state == BluetoothConnectionState.disconnected) {
          _characteristic = null;
          _emit(
            _state.copyWith(
              connectionPhase: ConnectionPhase.error,
              statusMessage: 'Device disconnected.',
            ),
          );
        }
      });

      _emit(
        _state.copyWith(
          connectionPhase: ConnectionPhase.connected,
          statusMessage: 'Connected to $kTargetDeviceName.',
          deviceName: device.platformName,
          deviceId: device.remoteId.str,
        ),
      );

      _queueCurrentPayload(force: true);
    } catch (error) {
      _characteristic = null;
      _emit(
        _state.copyWith(
          connectionPhase: ConnectionPhase.error,
          statusMessage: 'Connect failed: $error',
        ),
      );
      unawaited(_restartAfterFailure());
    }
  }

  Future<void> _restartAfterFailure() async {
    if (_isDisposed) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_isDisposed) {
      return;
    }

    await start();
  }

  BluetoothCharacteristic? _findWritableCharacteristic(
    List<BluetoothService> services,
  ) {
    BluetoothCharacteristic? fallback;

    for (final service in services) {
      if (service.uuid != kTargetServiceUuid) {
        continue;
      }

      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == kTargetCharacteristicUuid &&
            _isWritable(characteristic)) {
          return characteristic;
        }

        if (fallback == null && _isWritable(characteristic)) {
          fallback = characteristic;
        }
      }
    }

    return fallback;
  }

  bool _isWritable(BluetoothCharacteristic characteristic) {
    return characteristic.properties.write ||
        characteristic.properties.writeWithoutResponse;
  }

  void _queueCurrentPayload({required bool force}) {
    final characteristic = _characteristic;
    if (characteristic == null) {
      return;
    }

    final payload = '<$_x,$_y>';
    final bytes = utf8.encode(payload);

    if (force) {
      _cancelThrottle();
      _enqueueWrite(characteristic, bytes);
      _lastTransmission = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastTransmission);

    if (elapsed >= kThrottleWindow && _throttleTimer == null) {
      _enqueueWrite(characteristic, bytes);
      _lastTransmission = now;
      return;
    }

    final delay = elapsed >= kThrottleWindow
        ? kThrottleWindow
        : kThrottleWindow - elapsed;
    _throttleTimer ??= Timer(delay, () {
      _throttleTimer = null;
      if (_isDisposed || _characteristic == null) {
        return;
      }

      _enqueueWrite(_characteristic!, utf8.encode('<$_x,$_y>'));
      _lastTransmission = DateTime.now();
    });
  }

  void _enqueueWrite(BluetoothCharacteristic characteristic, List<int> bytes) {
    _writeChain = _writeChain.then((_) async {
      if (_isDisposed || _characteristic == null) {
        return;
      }

      try {
        await characteristic.write(bytes, withoutResponse: true);
      } catch (error) {
        if (_isDisposed) {
          return;
        }

        _emit(
          _state.copyWith(
            connectionPhase: ConnectionPhase.error,
            statusMessage: 'Write failed: $error',
          ),
        );
      }
    });
  }

  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Ignore stop-scan errors when the adapter is already idle.
    }
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> _disposeDeviceListeners() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  void _cancelThrottle() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }

  int _clampAxis(double value) {
    return value.round().clamp(kAxisMin, kAxisMax);
  }

  void _emit(JoystickState nextState) {
    _state = nextState;
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }
}

class _GraphJoystick extends StatefulWidget {
  const _GraphJoystick({required this.bloc});

  final JoystickBloc bloc;

  @override
  State<_GraphJoystick> createState() => _GraphJoystickState();
}

class _GraphJoystickState extends State<_GraphJoystick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Animation<Offset>? _snapAnimation;
  Offset _dragOffset = Offset.zero;
  final double _joystickSize = 280.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePosition(Offset localPos) {
    final radius = _joystickSize / 2;
    final center = Offset(radius, radius);
    final offsetFromCenter = localPos - center;

    // Clamp coordinates to a square bounding box instead of a circle
    final clampedX = offsetFromCenter.dx.clamp(-radius, radius);
    final clampedY = offsetFromCenter.dy.clamp(-radius, radius);
    final clampedOffset = Offset(clampedX, clampedY);

    setState(() {
      _dragOffset = clampedOffset;
    });

    final xPct = clampedOffset.dx / radius;
    final yPct = -clampedOffset.dy / radius;
    widget.bloc.setAxes(xPct * 255, yPct * 255);
  }

  void _startSnapBack() {
    _snapAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.addListener(_onSnapAnimationUpdate);
    _animationController.addStatusListener(_onSnapAnimationStatusChange);

    _animationController.forward(from: 0.0);
  }

  void _onSnapAnimationUpdate() {
    if (_snapAnimation != null) {
      setState(() {
        _dragOffset = _snapAnimation!.value;
      });
      final radius = _joystickSize / 2;
      final xPct = _dragOffset.dx / radius;
      final yPct = -_dragOffset.dy / radius;
      widget.bloc.setAxes(xPct * 255, yPct * 255);
    }
  }

  void _onSnapAnimationStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _animationController.removeListener(_onSnapAnimationUpdate);
      _animationController.removeStatusListener(_onSnapAnimationStatusChange);
      widget.bloc.snapAxesToCenter();
    }
  }

  void _stopSnapBack() {
    if (_animationController.isAnimating) {
      _animationController.stop();
      _animationController.removeListener(_onSnapAnimationUpdate);
      _animationController.removeStatusListener(_onSnapAnimationStatusChange);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = _joystickSize / 2;
    final xPct = _dragOffset.dx / radius;
    final yPct = -_dragOffset.dy / radius;
    // Calculate the maximum displacement intensity on either axis
    final intensity = (xPct.abs() > yPct.abs() ? xPct.abs() : yPct.abs()).clamp(
      0.0,
      1.0,
    );

    final padColor = Color.lerp(
      const Color(0xFF0D1727).withOpacity(0.55),
      const Color(0xFFFF5252).withOpacity(0.25),
      intensity,
    );

    final borderColor = Color.lerp(
      const Color(0xFF00E5FF).withOpacity(0.15),
      const Color(0xFFFF5252).withOpacity(0.7),
      intensity,
    );

    final shadowColor = Color.lerp(
      const Color(0xFF00E5FF).withOpacity(0.05),
      const Color(0xFFFF5252).withOpacity(0.25),
      intensity,
    );

    return GestureDetector(
      onPanStart: (details) {
        _stopSnapBack();
        _updatePosition(details.localPosition);
      },
      onPanUpdate: (details) {
        _updatePosition(details.localPosition);
      },
      onPanEnd: (details) {
        _startSnapBack();
      },
      child: Container(
        width: _joystickSize,
        height: _joystickSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: padColor,
          border: Border.all(color: borderColor!, width: 2.0),
          boxShadow: [
            BoxShadow(color: shadowColor!, blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background Grid Painter
            Positioned.fill(
              child: CustomPaint(painter: _JoystickGridPainter(radius: radius)),
            ),
            // Crosshair lines from center to thumb
            Positioned.fill(
              child: CustomPaint(
                painter: _JoystickTrailPainter(
                  center: Offset(radius, radius),
                  thumb: Offset(radius, radius) + _dragOffset,
                ),
              ),
            ),
            // Joystick thumb
            Positioned(
              left: radius + _dragOffset.dx - 30,
              top: radius + _dragOffset.dy - 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF00838F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2.0),
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoystickGridPainter extends CustomPainter {
  _JoystickGridPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintGrid = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final paintAxes = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw vertical and horizontal grid lines
    const gridDivisions = 6;
    final step = radius / (gridDivisions / 2);

    // Vertical grid lines
    for (double i = -radius + step; i < radius; i += step) {
      if (i.abs() < 1) continue; // Skip center axis
      canvas.drawLine(
        Offset(center.dx + i, center.dy - radius),
        Offset(center.dx + i, center.dy + radius),
        paintGrid,
      );
    }

    // Horizontal grid lines
    for (double i = -radius + step; i < radius; i += step) {
      if (i.abs() < 1) continue; // Skip center axis
      canvas.drawLine(
        Offset(center.dx - radius, center.dy + i),
        Offset(center.dx + radius, center.dy + i),
        paintGrid,
      );
    }

    // Draw main axes
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paintAxes,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paintAxes,
    );

    // Draw some tick marks on the axes
    final tickPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.4)
      ..strokeWidth = 1.0;

    for (double i = -radius + step; i < radius; i += step) {
      if (i.abs() < 1) continue; // Skip center
      // X-axis ticks
      canvas.drawLine(
        Offset(center.dx + i, center.dy - 4),
        Offset(center.dx + i, center.dy + 4),
        tickPaint,
      );
      // Y-axis ticks
      canvas.drawLine(
        Offset(center.dx - 4, center.dy + i),
        Offset(center.dx + 4, center.dy + i),
        tickPaint,
      );
    }

    // Draw labels: -255, +255, etc.
    const textStyle = TextStyle(
      color: Color(0xFF00E5FF),
      fontSize: 8,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );

    void drawText(String text, Offset offset, {bool isCenteringX = true}) {
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final adjustedOffset = Offset(
        isCenteringX ? offset.dx - textPainter.width / 2 : offset.dx,
        offset.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, adjustedOffset);
    }

    // Y Axis labels
    drawText('+255', Offset(center.dx, center.dy - radius + 12));
    drawText('-255', Offset(center.dx, center.dy + radius - 12));

    // X Axis labels
    drawText('-255', Offset(center.dx - radius + 16, center.dy - 8));
    drawText('+255', Offset(center.dx + radius - 16, center.dy - 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JoystickTrailPainter extends CustomPainter {
  _JoystickTrailPainter({required this.center, required this.thumb});

  final Offset center;
  final Offset thumb;

  @override
  void paint(Canvas canvas, Size size) {
    if (thumb == center) return;

    final paintLine = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintProjection = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw main line from center to thumb
    canvas.drawLine(center, thumb, paintLine);

    // Draw projections to the axes
    // X projection: vertical line from thumb to horizontal axis (y = center.dy)
    _drawDashedLine(
      canvas,
      thumb,
      Offset(thumb.dx, center.dy),
      paintProjection,
    );

    // Y projection: horizontal line from thumb to vertical axis (x = center.dx)
    _drawDashedLine(
      canvas,
      thumb,
      Offset(center.dx, thumb.dy),
      paintProjection,
    );

    // Draw dots at projection intercepts
    final dotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumb.dx, center.dy), 3, dotPaint);
    canvas.drawCircle(Offset(center.dx, thumb.dy), 3, dotPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;

    final distance = (p2 - p1).distance;
    if (distance == 0) return;

    final direction = (p2 - p1) / distance;
    double drawn = 0.0;

    while (drawn < distance) {
      final start = p1 + direction * drawn;
      final end = p1 + direction * (drawn + dashWidth).clamp(0, distance);
      canvas.drawLine(start, end, paint);
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _JoystickTrailPainter oldDelegate) {
    return oldDelegate.thumb != thumb || oldDelegate.center != center;
  }
}

class _TelemetryDisplay extends StatelessWidget {
  const _TelemetryDisplay({required this.x, required this.y});

  final int x;
  final int y;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1727).withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('STEERING (X)', x, const Color(0xFF00E5FF)),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildMetric('THROTTLE (Y)', y, const Color(0xFF3EE08A)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value > 0 ? '+$value' : value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
            shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}
