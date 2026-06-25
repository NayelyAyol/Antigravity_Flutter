import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GPSLocationApp());
}

class GPSLocationApp extends StatelessWidget {
  const GPSLocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6F40),
          primary: const Color(0xFF2E6F40),
          secondary: const Color(0xFF00838F),
          tertiary: const Color(0xFF00ACC1),
          surface: const Color(0xFFF1F8F5),
          error: const Color(0xFFC62828),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F8F5),
        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: const Color(0x1A2E6F40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE8F5E9),
          foregroundColor: Color(0xFF1B4D22),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B4D22),
          ),
        ),
      ),
      home: const MainLocationScreen(),
    );
  }
}

class LocationHistoryItem {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final DateTime timestamp;

  LocationHistoryItem({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.timestamp,
  });
}

class MainLocationScreen extends StatefulWidget {
  const MainLocationScreen({super.key});

  @override
  State<MainLocationScreen> createState() => _MainLocationScreenState();
}

class _MainLocationScreenState extends State<MainLocationScreen>
    with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  bool _gpsEnabled = false;
  LocationPermission _permissionStatus = LocationPermission.denied;
  bool _isTracking = false; // ✅ Estado del tracking activo
  final List<LocationHistoryItem> _history = [];

  StreamSubscription<Position>? _positionStreamSubscription;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      setState(() {
        _gpsEnabled = serviceEnabled;
        _permissionStatus = permission;
      });
    } catch (e) {
      debugPrint("Error checking status: $e");
    }
  }

  /// En Android usa AndroidSettings con ForegroundNotificationConfig
  /// para mantener el GPS vivo en segundo plano.
  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        // Sin esto Android mata el proceso al minimizar.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'GPS Activo',
          notificationText: 'Registrando tu ubicación en segundo plano...',
          enableWakeLock: true, // Evita que el CPU duerma y corte el GPS
        ),
      );
    }
    // iOS u otras plataformas
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  Future<void> _fetchGPSLocation() async {
    // Si ya hay tracking activo, detenerlo (toggle)
    if (_isTracking) {
      await _stopTracking();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Verificar servicio GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      setState(() => _gpsEnabled = serviceEnabled);

      if (!serviceEnabled) {
        throw 'El servicio de ubicación (GPS) está desactivado. Por favor, actívalo en los ajustes de tu dispositivo.';
      }

      // 2. Verificar y solicitar permiso básico
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        setState(() => _permissionStatus = permission);
        if (permission == LocationPermission.denied) {
          throw 'Los permisos de ubicación fueron denegados por el usuario.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Los permisos de ubicación están permanentemente denegados. Actívalos manualmente en los ajustes de la aplicación.';
      }

      // ✅ 3. Solicitar permiso de segundo plano (Android 10+ requiere "Permitir todo el tiempo")
      // Solo se solicita si el permiso actual es "whileInUse"
      if (!kIsWeb && Platform.isAndroid && permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
        // Si el usuario no eligió "Siempre", avisamos pero continuamos
        // (el GPS funcionará en primer plano igualmente)
        if (permission != LocationPermission.always) {
          _showSnackBar(
            'Permiso de segundo plano no otorgado. El GPS puede detenerse al minimizar la app. '
            'Ve a Ajustes > Permisos > Ubicación > Permitir todo el tiempo.',
            isError: false,
          );
        }
      }

      setState(() => _permissionStatus = permission);

      // 4. Cancelar suscripción previa si existe
      await _positionStreamSubscription?.cancel();

      // ✅ 5. Iniciar stream con configuración de segundo plano
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: _buildLocationSettings(),
      ).listen(
        (Position position) {
          setState(() {
            _currentPosition = position;
            _history.insert(
              0,
              LocationHistoryItem(
                latitude: position.latitude,
                longitude: position.longitude,
                accuracy: position.accuracy,
                speed: position.speed,
                timestamp: position.timestamp,
              ),
            );
          });
          _animController.forward(from: 0.0);
        },
        onError: (error) {
          setState(() {
            _isTracking = false;
            _errorMessage = error.toString().replaceAll("Exception: ", "");
          });
          _showSnackBar(
            _errorMessage ?? 'Error en el flujo de ubicación.',
            isError: true,
          );
        },
        onDone: () {
          setState(() => _isTracking = false);
        },
      );

      setState(() => _isTracking = true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
      _showSnackBar(
        _errorMessage ?? 'Ocurrió un error inesperado al obtener la ubicación.',
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
      _checkInitialStatus();
    }
  }

  Future<void> _stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    setState(() => _isTracking = false);
    _showSnackBar('Seguimiento GPS detenido.');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFC62828) : const Color(0xFF2E6F40),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 5 : 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: isError && message.contains('permanentemente')
            ? SnackBarAction(
                label: 'Ajustes',
                textColor: Colors.white,
                onPressed: () => Geolocator.openAppSettings(),
              )
            : null,
      ),
    );
  }

  void _copyToClipboard() {
    if (_currentPosition == null) return;
    final coords =
        "${_currentPosition!.latitude}, ${_currentPosition!.longitude}";
    Clipboard.setData(ClipboardData(text: coords));
    _showSnackBar('Coordenadas copiadas al portapapeles: $coords');
  }

  Future<void> _openInMaps() async {
    if (_currentPosition == null) return;
    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;
    final url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir el mapa.';
      }
    } catch (e) {
      _showSnackBar('Error al intentar abrir el mapa: $e', isError: true);
    }
  }

  void _clearHistory() {
    setState(() => _history.clear());
    _showSnackBar('Historial de ubicaciones limpiado.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.gps_fixed,
              color: Color(0xFF1B4D22),
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text('Localizador GPS'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusPanel(theme),
              const SizedBox(height: 16),
              _buildCoordinatesDisplay(theme),
              const SizedBox(height: 24),
              _buildActionButtons(theme),
              const SizedBox(height: 28),
              _buildHistoryPanel(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPanel(ThemeData theme) {
    final isPermitted = _permissionStatus == LocationPermission.always ||
        _permissionStatus == LocationPermission.whileInUse;
    final hasBackgroundPermission =
        _permissionStatus == LocationPermission.always;

    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // GPS Activo/Inactivo
            _statusChip(
              icon: _gpsEnabled ? Icons.location_on : Icons.location_off,
              label: _gpsEnabled ? 'GPS Activo' : 'GPS Inactivo',
              active: _gpsEnabled,
            ),
            Container(height: 20, width: 1, color: Colors.grey[300]),
            // Permiso básico
            _statusChip(
              icon: isPermitted ? Icons.verified_user : Icons.gpp_maybe,
              label: isPermitted ? 'Permiso OK' : 'Sin Permiso',
              active: isPermitted,
              inactiveColor: const Color(0xFFE65100),
            ),
            Container(height: 20, width: 1, color: Colors.grey[300]),
            // ✅ Permiso de segundo plano
            _statusChip(
              icon: hasBackgroundPermission
                  ? Icons.wifi_tethering
                  : Icons.wifi_tethering_off,
              label: hasBackgroundPermission ? '2do Plano' : 'Solo 1er Plano',
              active: hasBackgroundPermission,
              inactiveColor: const Color(0xFFE65100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required bool active,
    Color inactiveColor = const Color(0xFFC62828),
  }) {
    final color = active ? const Color(0xFF2E6F40) : inactiveColor;
    final textColor = active ? const Color(0xFF1B4D22) : inactiveColor;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinatesDisplay(ThemeData theme) {
    if (_currentPosition == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F7FA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location,
                    size: 48, color: Color(0xFF00838F)),
              ),
              const SizedBox(height: 16),
              Text(
                'Sin ubicación obtenida',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Presiona el botón inferior para iniciar el seguimiento GPS.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final timeStr = dateFormat.format(_currentPosition!.timestamp);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                // ✅ Color del header cambia según estado de tracking
                color: _isTracking
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: _isTracking
                        ? const Color(0xFF1B4D22)
                        : const Color(0xFFE65100),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTracking ? 'Seguimiento Activo' : 'Seguimiento Pausado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isTracking
                          ? const Color(0xFF1B4D22)
                          : const Color(0xFFE65100),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildDataRow(
                    label: 'Latitud',
                    value: _currentPosition!.latitude.toStringAsFixed(6),
                    icon: Icons.swap_vert,
                    color: const Color(0xFF2E6F40),
                  ),
                  const Divider(
                      height: 24, thickness: 1, color: Color(0xFFEEEEEE)),
                  _buildDataRow(
                    label: 'Longitud',
                    value: _currentPosition!.longitude.toStringAsFixed(6),
                    icon: Icons.swap_horiz,
                    color: const Color(0xFF2E6F40),
                  ),
                  const Divider(
                      height: 24, thickness: 1, color: Color(0xFFEEEEEE)),
                  _buildDataRow(
                    label: 'Precisión',
                    value:
                        '±${_currentPosition!.accuracy.toStringAsFixed(1)} m',
                    icon: Icons.gps_fixed,
                    color: const Color(0xFF00838F),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copiar'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B4D22),
                          backgroundColor: const Color(0xFFE8F5E9),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openInMaps,
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Ver Mapa'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: const Color(0xFF006064),
                          backgroundColor: const Color(0xFFE0F7FA),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF333333))),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    // ✅ Botón cambia entre INICIAR y DETENER según estado
    final isActive = _isTracking;
    final buttonColors = isActive
        ? [const Color(0xFFC62828), const Color(0xFFE53935)]
        : _isLoading
            ? [Colors.grey[400]!, Colors.grey[500]!]
            : [const Color(0xFF2E6F40), const Color(0xFF00838F)];

    return Column(
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: buttonColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _isLoading
                    ? Colors.transparent
                    : (isActive
                        ? const Color(0x3DC62828)
                        : const Color(0x3D00838F)),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _fetchGPSLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? Icons.stop_circle : Icons.gps_fixed,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isActive
                            ? 'DETENER SEGUIMIENTO'
                            : 'INICIAR SEGUIMIENTO GPS',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // ✅ Banner informativo cuando el tracking está activo
        if (_isTracking) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Color(0xFF2E6F40), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GPS activo en segundo plano. Verás una notificación persistente mientras el seguimiento esté encendido.',
                    style: TextStyle(
                        color: Color(0xFF1B4D22), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFC62828), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: Color(0xFFB71C1C), fontSize: 12.5),
                  ),
                ),
                if (_errorMessage!.contains('permanentemente'))
                  TextButton(
                    onPressed: () => Geolocator.openAppSettings(),
                    child: const Text(
                      'CONFIGURAR',
                      style: TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryPanel(ThemeData theme) {
    if (_history.isEmpty) return const SizedBox.shrink();

    final dateFormat = DateFormat('HH:mm:ss');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history,
                        color: Color(0xFF555555), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Historial (${_history.length} puntos)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF333333)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _clearHistory,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Limpiar',
                      style: TextStyle(
                          color: Color(0xFF00838F),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length > 5 ? 5 : _history.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 16, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final item = _history[index];
                final timeStr = dateFormat.format(item.timestamp);
                return InkWell(
                  onTap: () {
                    setState(() {
                      _currentPosition = Position(
                        latitude: item.latitude,
                        longitude: item.longitude,
                        accuracy: item.accuracy,
                        altitude: 0,
                        timestamp: item.timestamp,
                        heading: 0,
                        speed: item.speed,
                        speedAccuracy: 0,
                        altitudeAccuracy: 0,
                        headingAccuracy: 0,
                      );
                    });
                    _animController.forward(from: 0.0);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F8F5),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '#${_history.length - index}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E6F40)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.latitude.toStringAsFixed(6)}, ${item.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Precisión: ±${item.accuracy.toStringAsFixed(1)} m',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(timeStr,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_history.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Mostrando los últimos 5 de ${_history.length} puntos registrados',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}