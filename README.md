# <h1 align="center"> 📍 GPS Tracker - Geolocalización en Tiempo Real con Flutter 💙 </h1>

## Descripción

Aplicación móvil desarrollada con Flutter y Dart que utiliza las capacidades de geolocalización del dispositivo para obtener y mostrar la ubicación actual del usuario en tiempo real.

La aplicación permite:

- Solicitar permisos de ubicación
- Obtener coordenadas GPS precisas
- Mostrar latitud y longitud actuales
- Visualizar la precisión de la lectura GPS
- Mostrar la hora de la última actualización
- Abrir la ubicación en Google Maps
- Copiar coordenadas al portapapeles
- Iniciar y detener el seguimiento GPS en segundo plano
- Registrar un historial de ubicaciones obtenidas
- Mantener el seguimiento mediante un Foreground Service de Android con notificación persistente

---

## Autora

- Nayely Ayol

---

## Tecnologías utilizadas

- Flutter
- Dart
- Geolocator
- URL Launcher
- Intl
- Android Studio

---

## Herramienta de IA utilizada

Este proyecto fue desarrollado utilizando **Antigravity** como herramienta de asistencia para la generación y optimización del código fuente.


<img width="886" height="361" alt="image" src="https://github.com/user-attachments/assets/72e252f9-312c-4a29-9254-01155e9c9c3f" />


---

## Funcionalidades

- Obtención de ubicación GPS en tiempo real mediante stream continuo
- Solicitud automática de permisos de ubicación en primer y segundo plano
- Validación de coordenadas obtenidas
- Visualización de precisión GPS
- Panel de estado con indicadores de GPS, permisos básicos y permisos de segundo plano
- Apertura de ubicación en Google Maps
- Copia de coordenadas al portapapeles
- Interfaz moderna y responsiva con Material 3
- Ícono personalizado
- Seguimiento GPS en segundo plano con Foreground Service
- Historial de ubicaciones registradas (últimos 5 puntos)
- Inicio y detención del seguimiento en tiempo real
- Notificación persistente mientras el GPS permanece activo
- Animación de fade al actualizar coordenadas

---

## Proceso de desarrollo

### 1. Creación del proyecto con Antigravity

Para el desarrollo de la aplicación se utilizó **Antigravity** como asistente de programación.

#### Prompt utilizado

Se ingresó el siguiente prompt para generar la aplicación:

```text
Crea una aplicación Flutter que obtenga la ubicación GPS actual usando Capacitor Geolocation, con manejo de permisos y errores. Una interfaz clara y con componentes bien distribuidos, colores que combinen tonos verdes claros y oscuros, y celestes claros, no muy saturado, y splash screen.
```

#### Generación automática del código

Claude analizó el requerimiento y generó automáticamente la lógica necesaria para:

- Solicitar permisos de ubicación en primer y segundo plano.
- Obtener coordenadas GPS mediante stream continuo.
- Validar los datos obtenidos.
- Manejar errores de geolocalización.
- Mostrar información detallada de la ubicación.
- Diseñar una interfaz moderna con Material 3.

#### Implementación del seguimiento en segundo plano

Posteriormente se solicitó a Claude ampliar la funcionalidad para incorporar el seguimiento continuo mediante un Foreground Service de Android, manteniendo el GPS activo incluso cuando la aplicación permanece minimizada.

#### Ejecución del proyecto

Una vez finalizada la generación del código, se ejecutó la aplicación mediante:

```bash
flutter run
```

Posteriormente se verificó el correcto funcionamiento de la interfaz y de la lectura GPS.

---

### 2. Instalación de dependencias

```bash
flutter pub get
```

Dependencias del proyecto (`pubspec.yaml`):

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  geolocator: ^14.0.2
  url_launcher: ^6.3.0
  intl: ^0.20.2
```

---

### 3. Configuración de permisos Android

Archivo:

```
android/app/src/main/AndroidManifest.xml
```

Permisos agregados:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Servicio de segundo plano registrado dentro de `<application>`:

```xml
<service
    android:name="com.baseflow.geolocator.GeolocatorLocationService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="location" />
```

Bloque `<queries>` para permitir apertura de URLs externas (Google Maps):

```xml
<queries>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT" />
        <data android:mimeType="text/plain" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="geo" />
    </intent>
</queries>
```

---

### 4. Implementación de geolocalización

Importaciones utilizadas:

```dart
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
```

Verificación de permisos:

```dart
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
LocationPermission permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
  permission = await Geolocator.requestPermission();
}
```

Obtención continua de ubicación mediante stream:

```dart
_positionStreamSubscription = Geolocator.getPositionStream(
  locationSettings: _buildLocationSettings(),
).listen((Position position) {
  setState(() {
    _currentPosition = position;
    _history.insert(0, LocationHistoryItem(...));
  });
});
```

---

### 5. Implementación del seguimiento en segundo plano

Para mantener la actualización continua de la ubicación incluso cuando la aplicación permanece minimizada, se configuró un Foreground Service mediante `AndroidSettings` con `ForegroundNotificationConfig`.

Configuración de `LocationSettings` según plataforma:

```dart
LocationSettings _buildLocationSettings() {
  if (!kIsWeb && Platform.isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      intervalDuration: const Duration(seconds: 10),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'GPS Activo',
        notificationText: 'Registrando tu ubicación en segundo plano...',
        enableWakeLock: true,
      ),
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );
}
```

Inicio del seguimiento:

```dart
_positionStreamSubscription = Geolocator.getPositionStream(
  locationSettings: _buildLocationSettings(),
).listen((position) { ... });
setState(() => _isTracking = true);
```

Detención del seguimiento:

```dart
await _positionStreamSubscription?.cancel();
_positionStreamSubscription = null;
setState(() => _isTracking = false);
```

Durante el seguimiento se actualizan automáticamente:

- Coordenadas GPS
- Precisión
- Hora de actualización
- Historial de ubicaciones
- Estado del seguimiento (color del header de la tarjeta)

---

### 6. Manejo de errores

La aplicación incorpora validaciones y control de errores para distintos escenarios:

- GPS desactivado en el dispositivo
- Permisos denegados por el usuario
- Permisos denegados permanentemente (con botón directo a ajustes)
- Fallo en el stream de ubicación
- Error al abrir Google Maps

---

### 7. Historial de ubicaciones

Cada lectura GPS obtenida se almacena temporalmente en memoria para consultar los últimos puntos registrados.

Cada registro almacena:

- Latitud
- Longitud
- Precisión
- Velocidad
- Hora de captura

El historial muestra los últimos 5 puntos y puede eliminarse mediante el botón **Limpiar**. Al tocar un punto del historial, se actualiza la tarjeta principal con esas coordenadas.

---

## Interfaz principal

La interfaz permite al usuario:

- Ver el estado del GPS, permisos básicos y permisos de segundo plano
- Obtener su ubicación actual
- Iniciar el seguimiento GPS continuo
- Detener el seguimiento cuando lo desee
- Consultar el historial de ubicaciones
- Visualizar latitud, longitud y precisión GPS
- Abrir la ubicación en Google Maps
- Copiar coordenadas al portapapeles

Panel de estado:

```dart
_statusChip(
  icon: _gpsEnabled ? Icons.location_on : Icons.location_off,
  label: _gpsEnabled ? 'GPS Activo' : 'GPS Inactivo',
  active: _gpsEnabled,
),
```

Botón principal (toggle INICIAR / DETENER):

```dart
ElevatedButton(
  onPressed: _isLoading ? null : _fetchGPSLocation,
  child: Text(
    isActive ? 'DETENER SEGUIMIENTO' : 'INICIAR SEGUIMIENTO GPS',
  ),
)
```

Visualización de coordenadas:

```dart
_buildDataRow(
  label: 'Latitud',
  value: _currentPosition!.latitude.toStringAsFixed(6),
  icon: Icons.swap_vert,
  color: const Color(0xFF2E6F40),
),
```

---

## Implementación de ícono

1. Agregar imagen `icon.png` en la carpeta:

```
assets/icon.png
```

2. Declarar en `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/icon.png
```

3. Configurar el ícono de la app en:

```
android/app/src/main/res/mipmap-*/ic_launcher.png
```

---

## Ejecución en dispositivo Android

Verificar dispositivo conectado:

```bash
flutter devices
```

Ejecutar en modo debug:

```bash
flutter run
```

Generar APK de release:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

El APK generado se encuentra en:

```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Capturas de la funcionalidad

| Sin ubicación obtenida | Seguimiento activo |
| :--------------------: | :----------------: |
| <img width="720" height="1600" alt="WhatsApp Image 2026-06-25 at 5 11 43 PM (1)" src="https://github.com/user-attachments/assets/d98cdd91-c91d-46c5-807d-6f5ea2f06205" />| <img width="720" height="1600" alt="WhatsApp Image 2026-06-25 at 5 11 42 PM" src="https://github.com/user-attachments/assets/493b25e3-4ffb-41d5-879a-0477befce9c9" />|

| Permisos | Historial de ubicaciones |
| :------------------------: | :----------------------: |
| <img width="720" height="1600" alt="WhatsApp Image 2026-06-25 at 5 11 43 PM" src="https://github.com/user-attachments/assets/b3f4c9d9-638c-45d3-9871-2ca0b7f9d5f5" /> | <img width="720" height="1600" alt="WhatsApp Image 2026-06-25 at 5 14 32 PM" src="https://github.com/user-attachments/assets/a83c30e2-d11f-49f9-9552-9caa6d16061a" />|

| Notificación en segundo plano | Google Maps |
| :---------------------------: | :---------: |
| <img width="720" height="1600" alt="WhatsApp Image 2026-06-25 at 5 11 43 PM (2)" src="https://github.com/user-attachments/assets/33a00a09-8e6e-43a0-8c3a-0b86bf96971a" />| <img width="720" height="1600" alt="WhatsApp Image 2026-06-25 at 5 11 43 PM (3)" src="https://github.com/user-attachments/assets/8d73b6bf-f692-46f9-8a47-44a21f1fd7c2" />|

| Seguimiento detenido | Splash Screen |
| :---------------: | :------------------: |
| <img width="720" height="1600" alt="WhatsApp Image 2026-06-25 at 5 11 43 PM (4)" src="https://github.com/user-attachments/assets/d3d5acd6-8d4d-4426-ba4e-58140b5b1a54" />| <img width="1080" height="2400" alt="WhatsApp Image 2026-06-25 at 5 11 43 PM (5)" src="https://github.com/user-attachments/assets/e34fa31b-d25f-44af-954b-d19d8eb6b5d2" />|

---

## Video de funcionamiento

*(Agrega aquí el enlace al video de demostración)*

---

## Resultados

- Se obtuvo correctamente la ubicación GPS del dispositivo mediante stream continuo.
- Se implementó la solicitud y validación de permisos de ubicación en primer y segundo plano.
- Se visualizaron coordenadas geográficas precisas con actualización en tiempo real.
- Se integró la apertura directa en Google Maps mediante `url_launcher`.
- Se implementó la copia de coordenadas al portapapeles.
- Se desarrolló un sistema de seguimiento GPS continuo en segundo plano con Foreground Service.
- Se registró un historial de los últimos 5 puntos de ubicación obtenidos.
- Se implementó una notificación persistente durante el seguimiento continuo.
- Se configuró el ícono personalizado de la aplicación.
- Se obtuvo un APK funcional para dispositivos Android.
- Proyecto desarrollado con apoyo de **Claude**.
