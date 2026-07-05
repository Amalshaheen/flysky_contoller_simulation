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
    return StreamBuilder<JoystickState>(
      stream: _bloc.stream,
      initialData: _bloc.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _bloc.state;
        return Scaffold(
          body: Stack(
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

              // Centered Left, Middle, and Right Controls (3 Columns)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Column 1: Throttle (Vertical Slider)
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: SizedBox(
                            width: 150,
                            // height: 280, // Takes up optimal vertical height
                            child: _ControlCard(
                              title: 'THROTTLE',
                              subtitle: 'Y-Axis',
                              value: state.y,
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: _ColoredTrackSlider(
                                  value: state.y,
                                  onChanged: (val) =>
                                      _bloc.setAxis(JoystickAxis.y, val),
                                  onChangeEnd: (val) =>
                                      _bloc.snapAxisToCenter(JoystickAxis.y),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Column 2: Bluetooth Status (Center Button)
                      SizedBox(
                        width: 140,
                        child: Center(
                          child: _TopStatusBar(state: state, bloc: _bloc),
                        ),
                      ),
                      // Column 3: Steering (Horizontal Slider)
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: SizedBox(
                            width: 380, // Very wide horizontal slider
                            height: 150,
                            child: _ControlCard(
                              title: 'STEERING',
                              subtitle: 'X-Axis',
                              value: state.x,
                              child: Center(
                                child: _ColoredTrackSlider(
                                  value: state.x,
                                  onChanged: (val) =>
                                      _bloc.setAxis(JoystickAxis.x, val),
                                  onChangeEnd: (val) =>
                                      _bloc.snapAxisToCenter(JoystickAxis.x),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
  });

  final String title;
  final String subtitle;
  final int value;
  final Widget child;

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
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
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
                child: Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 12),
                  child: child,
                ),
              ),
              Positioned(
                top: 14,
                left: 18,
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
              Positioned(
                top: 12,
                right: 18,
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

class _ColoredTrackSlider extends StatelessWidget {
  const _ColoredTrackSlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withOpacity(0.65),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF69F0AE).withOpacity(0.65),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
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
              divisions: kAxisMax - kAxisMin,
              value: value.toDouble(),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
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
