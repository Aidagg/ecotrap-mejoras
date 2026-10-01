# Changelog — EcoTrap

El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.0.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

---

## [2.9.1] — 2026-04-10

### Añadido
- **Splash screen** (`SplashPage`) — logo `app_icon.png` centrado sobre fondo verde corporativo con animación de fade + scale al arrancar la app. Ruta `/splash` como `initialRoute`.
- **Campo `name` en `WiFiNetwork`** — nombre amigable de la trampa obtenido de `last_cycle.id_trap` (Hive `@HiveField(6)`, nunca reutilizar índices anteriores).
- **Getter `displayName`** en entidad — muestra el nombre del trap si existe, SSID como fallback.
- **Flujo de guardado en 3 pasos**: 1) conectar WiFi por BSSID → 2) `GET /api/health` con `x-api-key` → 3) guardar red con nombre del trap ya incluido. Si `/health` devuelve 401, se bloquea el guardado y se redirige a Configuración.
- **Validación obligatoria de API Key** antes de guardar una red — diálogo bloqueante con botón "Ir a Configuración" en caso de key ausente o inválida.
- **Binding Dio a interfaz WiFi** (`WifiNetworkClient.bindDioToWifi`) en la petición `/api/health` del flujo de guardado, igual que `ApiService`.
- **Desconexión automática al eliminar red** — si la red eliminada es la actualmente conectada, se llama `unbindNetwork()` + `WiFiForIoTPlugin.disconnect()` antes de borrar.
- **Adaptador Hive regenerado** — `wifi_network_model.g.dart` actualizado con `HiveField(6)` (`name`); `writeByte(7)` campos; compatible con registros anteriores (field 6 nullable).

### Cambiado
- `_buildNearbyState`: filtro de redes ya guardadas corregido — si la red tiene BSSID, se excluye solo por BSSID exacto (permite mostrar dos redes con mismo SSID pero diferente BSSID).
- `connectAndroid10Plus` (Kotlin): libera `boundNetwork` y desvincula el proceso antes de solicitar una nueva red, evitando que Android rechace la segunda conexión.
- `SaveAndConnectNearbyEvent`, `SaveWiFiNetworkParams`, `UpdateWiFiNetworkParams`, `WiFiRepository`, `WiFiRepositoryImpl`, `WiFiBloc` — propagación del campo `name` en toda la cadena domain → data → bloc.
- Versión actualizada a `2.9.1` en `pubspec.yaml` y `AppConstants.version`.

### Corregido
- "No route to host" al conectar segunda trampa — faltaba liberar la red anterior en el lado nativo antes de pedir una nueva.
- Nombre del trap no se persistía — el adaptador Hive generado no incluía el campo `name`; corregido manualmente en `wifi_network_model.g.dart`.
- 401 Unauthorized en `/api/health` — faltaba el header `x-api-key` en el Dio creado manualmente.
- Segunda red ENTOMOLAB desaparecía del listado de escaneo tras guardar la primera — el filtro eliminaba por SSID sin considerar BSSID distinto.

---

## [2.7.0] — En desarrollo

### Añadido
- **Pruebas unitarias — feature `files`** (28 tests nuevos):
  - `file_entity_test.dart`: 17 tests sobre `sizeFormatted`, `extension`, `isImage`, `isJson`
  - `get_files_test.dart`: 3 tests sobre el use case `GetFiles`
  - `download_file_test.dart`: 3 tests sobre `DownloadFile` con callback de progreso
  - `files_bloc_test.dart`: 5 tests sobre `FilesBloc` (carga, descarga, errores)
- **`WiFiListPage` y `WiFiListItem` parametrizados** — reutilización para dos flujos distintos:
  - Parámetros: `pageTitle`, `connectLabel`, `connectRoute`
  - Flujo archivos IoT: `connectRoute = '/files-list'` (por defecto)
  - Flujo cámara: `connectRoute = '/camera-stream'`
- **Tercer botón en `HomePage`** — acceso directo al stream de cámara (`/camera-wifi`)
- **Rutas `/camera-wifi` y `/camera-stream`** añadidas en `main.dart`
- **`DOCUMENTATION.md`** — documentación técnica exhaustiva en la raíz del proyecto
- **`docs/features.md`** — descripción detallada de cada feature
- **`README.md` actualizado** — badge de tests (60 pasando), tabla de cobertura por suite

### Cambiado
- `SplashPage` eliminado — la app arranca directamente en `/home`
- Paleta `AppColors` aplicada en todas las pantallas (sin colores hardcoded)
- `README.md` — sección Testing reescrita con tabla por suite y comandos separados por feature
- Versión del badge de tests actualizada a 60 tests

---

## [2.6.0] — Anterior

### Añadido
- Feature `upload`: sincronización de archivos JSON al backend `backendmonitorizacion.ecotrap.es`
- `SyncService`: login automático con JWT, re-login en expiración 401, marcado `.synced`
- Enrutamiento por `option_menu`: `0063` → monitorizacion, `0064` → medicion
- Selección múltiple con FAB y cortina de progreso masivo
- Feature `stream`: stream MJPEG con parser de bytes `0xFF 0xD8`/`0xFF 0xD9`
- Timeout automático de 3 minutos con cuenta regresiva
- Ping periódico cada 10s para mantener cámara activa
- `POST /stream/close` al salir para liberar cámara en IoT
- Popup de salud del dispositivo (`GET /health`): secciones General, Sensores, Offline
- Zoom interactivo hasta 4× con `InteractiveViewer`

---

## [2.5.0] — Anterior

### Añadido
- Feature `files`: exploración y descarga de archivos del dispositivo IoT
- `ApiCheckScreen`: verificación de API Key al entrar al explorador
- `ApiConfigScreen`: configuración de API Key, baseUrl y credenciales de sincronización
- `FilesListScreen`: tabla con selección múltiple, descarga masiva, visualizador de imágenes y JSON
- Binding Wi-Fi forzado antes de cargar archivos (con backoff)
- `DownloadConfigService`: gestión de ruta de descarga configurable

---

## [2.0.0] — Anterior

### Añadido
- `WifiNetworkClient`: binding del proceso Android a la interfaz Wi-Fi via MethodChannel nativo
- `WiFiReconnectService`: reconexión automática a última red guardada
- Campo `bssid` en `WiFiNetwork` (HiveField 5) para identificar dispositivos por MAC
- `ScanNearbyNetworksEvent`: escaneo de redes ENTOMO cercanas con filtro por prefijo
- `WiFiNearbyLoaded` / `WiFiSavedFromNearby`: estados BLoC para flujo de escaneo
- Intensidad de señal en `WiFiListItem` con actualización en tiempo real
- `WiFiConnectionService`: servicio centralizado de conexión con gestión de permisos
- `PermissionService`: adaptación dinámica de permisos según versión Android (12 vs 13+)
- `runWithInternet()`: desvincular temporalmente Wi-Fi para llamadas a internet

### Cambiado
- Migración a Clean Architecture completa con separación por features
- `WiFiBloc` refactorizado con paginación (`LoadMoreWiFiNetworksEvent`)
- `ApiService` con reintentos automáticos y mapeo tipado de errores HTTP

---

## [1.0.0] — Versión inicial

### Añadido
- Estructura base Flutter con Clean Architecture
- Feature `wifi`: CRUD de redes Wi-Fi con Hive
- Feature `home`: panel de control principal
- Feature `splash`: pantalla de inicio con animaciones
- Paleta corporativa EntomoLab (`AppColors`)
- Inyección de dependencias con GetIt
- Gestión de estado con flutter_bloc + equatable
- Tests unitarios para feature `wifi` (32 tests)

---

> A partir de v2.7.0: actualizar este archivo en cada merge a `main` usando los prefijos
> **Añadido**, **Cambiado**, **Corregido**, **Eliminado**, **Seguridad**.
