# Arquitectura — EcoTrap v2.9.1

## Visión general

EcoTrap implementa **Clean Architecture** con **BLoC** para gestión de estado y **GetIt** como service locator. La app opera en modo **offline-first**: los datos se persisten localmente en Hive y se sincronizan con el backend cuando hay conectividad a internet. La comunicación con los dispositivos IoT se realiza exclusivamente por red Wi-Fi local.

---

## Capas de la arquitectura

```
┌──────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│         Pages · Widgets · BLoC (Events / States)             │
├──────────────────────────────────────────────────────────────┤
│                      Domain Layer                            │
│          Entities · Use Cases · Repository Interfaces        │
├──────────────────────────────────────────────────────────────┤
│                       Data Layer                             │
│        Models · DataSources · Repository Implementations     │
├──────────────────────────────────────────────────────────────┤
│                       Core Layer                             │
│   DI · Network · Services · Utils · Errors · UseCases Base   │
└──────────────────────────────────────────────────────────────┘
```

---

## Core Layer

### Inyección de dependencias (`core/di/injection.dart`)

El registro sigue un orden estricto para evitar dependencias circulares:

```
1. External     → Hive, Uuid, WiFiConnectionService
2. DataSources  → WiFiLocalDataSourceImpl, FilesRemoteDataSourceImpl
3. Repositories → WiFiRepositoryImpl, FilesRepositoryImpl
4. Use Cases    → GetWiFiNetworks, SaveWiFiNetwork, UpdateWiFiNetwork,
                  DeleteWiFiNetwork, GetTotalCount, GetFiles, DownloadFile
5. BLoCs        → WiFiBloc (factory), FilesBloc (factory)
```

Los BLoCs se registran como `factory` (nueva instancia por cada `BlocProvider`). Los servicios como `ApiService` y `WiFiConnectionService` se registran como `lazySingleton`.

### Manejo de errores

**Exceptions** (capa de datos) → **Failures** (dominio) → **Either\<Failure, T\>** (use cases → BLoC)

| Exception | Failure | Cuándo |
|-----------|---------|--------|
| `CacheException` | `CacheFailure` | Error en Hive |
| `ValidationException` | `ValidationFailure` | Datos inválidos |
| `NotFoundException` | `NotFoundFailure` | Entidad no existe |
| *(genérico)* | `UnexpectedFailure` | Error inesperado |

### Red y conectividad

#### `WifiNetworkClient`

Resuelve el problema crítico de Android: cuando hay datos móviles activos, el sistema redirige el tráfico HTTP por la interfaz de datos móviles en lugar de Wi-Fi, impidiendo la comunicación con el dispositivo IoT en la red local.

Flujo de binding:
1. `bindProcessToWifi()` — vincula el proceso a la interfaz Wi-Fi via canal nativo `es.ecotrap.ecotrap/wifi_network`
2. `ensureWifiBinding()` — garantiza binding antes de cualquier petición, con `_bindWithAutoReconnect()` como fallback
3. `runWithInternet(action)` — desvincula temporalmente de Wi-Fi para llamadas a internet (sincronización), luego re-vincula y notifica a `ApiService` via callback `onWifiRebound`

#### `ApiService`

Cliente HTTP Dio con gestión automática de reintentos (hasta 3, con backoff `attempts * 2s`). Se auto-resetea cuando `WifiNetworkClient` detecta un re-binding.

Mapeo de errores HTTP a `ErrorType`:

| HTTP | ErrorType |
|------|-----------|
| 400 | badRequest |
| 401 | unauthorized |
| 403 | forbidden |
| 404 | notFound |
| 500/502/503 | serverError |
| timeout | timeout |
| connection | connectionError |

Los archivos se descargan en `/storage/emulated/0/Download/EntomoLab-EcoTrap/` con fallback a `getApplicationDocumentsDirectory()`.

#### `ApiConfigService`

Persiste API Key y baseUrl en `FlutterSecureStorage` con:
- `sharedPreferencesName: 'ecotrap_api_prefs'`
- `preferencesKeyPrefix: 'api_'`
- `encryptedSharedPreferences: true` (Android)

URL por defecto: `http://192.168.100.10/api`

Validaciones: API Key alfanumérica de mínimo 16 caracteres; URL con esquema `http` o `https`.

#### `SyncService`

Sincronización de datos de campo al backend `https://backendmonitorizacion.ecotrap.es/api/v1`.

Flujo:
1. Obtener token JWT del secure storage
2. Si no hay token → login automático con credenciales guardadas
3. Si 401 → re-login automático y reintento
4. Leer JSON, extraer `option_menu`
5. Enrutar: `0063` → `POST /web/monitorizacion` | `0064` → `POST /web/monitorizacion/medicion`
6. Marcar como sincronizado con archivo `{nombre}.synced`

Las llamadas a internet usan `WifiNetworkClient.runWithInternet()` para desvincular temporalmente del Wi-Fi IoT.

#### `WiFiReconnectService`

Persiste credenciales de la última red Wi-Fi conectada (namespace `ecotrap_wifi_prefs`) para reconexión automática cuando el proceso pierde el binding.

#### `PermissionService`

Adapta los permisos Wi-Fi según versión de Android:

| SDK | Permiso |
|-----|---------|
| 31-32 (Android 12) | `locationWhenInUse` + `locationAlways` |
| 33+ (Android 13+) | `nearbyWifiDevices` |
| < 31 | **No soportado** |

Muestra diálogos contextuales con justificación antes de solicitar cada permiso. Si el permiso fue denegado permanentemente, ofrece abrir `openAppSettings()`.

---

## Features

### Feature: wifi

Gestión local de redes Wi-Fi de los dispositivos IoT EntomoLab.

#### Entidad `WiFiNetwork`

```dart
WiFiNetwork {
  String id        // UUID v4 — generado en WiFiRepositoryImpl
  String ssid      // Nombre de red (máx. 32 chars)
  String password  // Contraseña (8-63 chars)
  String? bssid    // MAC del dispositivo — diferencia trampas con mismo SSID
  DateTime createdAt
  DateTime? updatedAt
}
```

#### Modelo Hive `WiFiNetworkModel` — índices fijos

| HiveField | Campo | Tipo |
|-----------|-------|------|
| 0 | id | String |
| 1 | ssid | String |
| 2 | password | String |
| 3 | createdAt | DateTime |
| 4 | updatedAt | DateTime? |
| 5 | bssid | String? |

**Regla crítica**: los índices 0-5 son parte del contrato de serialización persistida. Nunca reutilizarlos. Nuevos campos deben usar índices ≥ 6.

#### Use Cases — validaciones de negocio

`SaveWiFiNetwork` y `UpdateWiFiNetwork` validan localmente en el use case (antes de llegar al repositorio) que el SSID tenga 2-32 caracteres y la contraseña 8-63. La unicidad de SSID se valida en el datasource lanzando `ValidationException` si ya existe.

`GetWiFiNetworks` implementa paginación con validación: page ≥ 1, pageSize 1-100. El datasource ordena por `createdAt` descendente.

#### BLoC — estados completos

| Estado | Descripción |
|--------|-------------|
| `WiFiInitial` | Estado inicial |
| `WiFiLoading` | Cargando lista |
| `WiFiLoadingMore` | Cargando siguiente página (mantiene lista visible) |
| `WiFiLoaded` | Lista cargada con info de paginación |
| `WiFiSaving` | Guardando o actualizando |
| `WiFiSaved` | Operación exitosa, recarga automáticamente |
| `WiFiDeleting(id)` | Eliminando red específica |
| `WiFiDeleted(id)` | Eliminación exitosa, recarga automáticamente |
| `WiFiScanning` | Escaneando redes cercanas via `wifi_iot` |
| `WiFiNearbyLoaded` | Redes EntomoLab cercanas cargadas |
| `WiFiSavedFromNearby` | Red guardada desde escaneo, mantiene vista de escaneo |
| `WiFiError(message)` | Error con mensaje descriptivo |

El escaneo filtra solo redes cuyo SSID empieza con `ENTOMO` (case-insensitive), ordenadas por señal descendente.

#### WiFiListItem

Cada item de la lista muestra intensidad de señal Wi-Fi en tiempo real:
- Actualización cada 5 segundos via `Timer.periodic`
- Búsqueda por BSSID primero (más preciso), SSID como fallback
- Conversión RSSI → porcentaje: `clamp((2 * (rssi + 100)), 0, 100)`
- El botón "Conectar" se deshabilita si `signalLevel == null` (fuera de alcance)

---

### Feature: files

Exploración y descarga de archivos desde el dispositivo IoT.

#### Flujo

```
ApiCheckScreen
├── Sin API Key → ApiConfigScreen
└── Con API Key → FilesListScreen
     ├── Binding Wi-Fi (12 intentos con backoff)
     ├── GET /files → lista de archivos
     ├── Selección simple → descarga individual
     └── Selección múltiple → descarga masiva con progreso global
```

#### FilesListScreen — estados de carga

La pantalla tiene una "cortina" (`_FilesLoadingCurtain`) que se superpone en tres situaciones: binding Wi-Fi inicial, descarga individual y descarga múltiple. La cortina muestra título, nombre de archivo actual y barra de progreso.

#### Visualizadores inline

- **Imágenes** (`isImage`): `InteractiveViewer` con zoom 5x sobre `Image.file()`
- **JSON** (`isJson`): `SelectableText` con toggle pretty/compact via `JsonEncoder.withIndent`
- Ambos solo disponibles si el archivo ya fue descargado localmente

#### ApiConfigScreen — credenciales duales

Gestiona dos conjuntos independientes de credenciales:

**IoT (API Key + baseUrl)**:
- Almacenadas en `ApiConfigService` (namespace `ecotrap_api_prefs`)
- Validación: alphanumérico, mínimo 16 caracteres

**Sincronización (usuario + contraseña)**:
- Almacenadas en `SyncService` (namespace `ecotrap_sync_prefs`)
- Botón "Probar conexión" ejecuta login real contra el backend

---

### Feature: stream

Visualización del stream MJPEG de la cámara del dispositivo IoT.

#### Puerto dedicado

El servicio de stream corre en `puerto 8081`. La URL se construye transformando la baseUrl guardada: `http://host/api` → `http://host:8081/api`.

#### Parser MJPEG

El stream es un flujo de bytes continuo. El parser `_processBuffer()` busca marcadores JPEG en el buffer acumulado:
- Start: `0xFF 0xD8`
- End: `0xFF 0xD9`

Cuando encuentra un frame completo, lo renderiza con `Image.memory(frame, gaplessPlayback: true)`. Los frames anteriores se descartan del buffer.

#### Ciclo de vida del stream

- **Timeout automático**: 3 minutos con cuenta regresiva en AppBar (color rojo cuando quedan ≤ 30s)
- **Ping periódico**: `GET /stream/ping` cada 10s para mantener la cámara activa en el IoT
- **Cierre explícito**: `POST /stream/close` libera la cámara al salir o al perder el foco
- **`WidgetsBindingObserver`**: pausa el stream cuando la app pasa a background

#### Popup de salud del dispositivo

`GET /health` devuelve datos del dispositivo IoT agrupados en:
- **General**: `last_cycle.id_trap`, `last_cycle.last_key`, `last_cycle.last_run`, `time_local`
- **Sensores**: `sensors.battery.battery_pct`, `sensors.dht22.hum_pct`, `sensors.dht22.temp_c`, `sensors.ds18b20.temp_c`
- **Offline**: `offline_queue.jpg`, `offline_queue.json`

---

### Feature: upload

Sincronización de archivos JSON de campo al backend EntomoLab.

#### Detección de estado de sincronización

La pantalla busca archivos `.json` en el directorio de descargas y comprueba si existe el correspondiente `{nombre}.synced`. Los archivos pendientes se muestran primero, ordenados por fecha descendente.

#### Selección múltiple y subida masiva

Con long-press se entra en modo selección. El FAB muestra el conteo de archivos seleccionados. La subida masiva itera secuencialmente, actualiza la cortina de carga con el archivo actual y el progreso total, y al finalizar muestra un resumen con éxitos y errores.

#### Re-login automático

Si el token JWT expira durante la sincronización (respuesta 401), `SyncService` elimina el token, hace login automático con las credenciales guardadas y reintenta la sincronización del archivo actual.

---

## Navegación (main.dart)

| Ruta | Widget | Descripción |
|------|--------|-------------|
| `/home` | `HomePage` | Panel principal (arranque directo, sin splash) |
| `/wifi-list` | `WiFiListPage` | Gestión de trampas IoT → archivos |
| `/camera-wifi` | `WiFiListPage` (modo stream) | Selección de trampa para cámara |
| `/camera-stream` | `CameraStreamPage` | Stream MJPEG en vivo |
| `/upload` | `UploadPage` | Sincronización JSON |
| `/api-check` | `ApiCheckScreen` | Verificación de API Key |
| `/api-config` | `ApiConfigScreen` | Configuración API y sync |
| `/files-list` | `FilesListScreen` | Explorador de archivos IoT |

`WiFiListPage` es reutilizable: acepta `pageTitle`, `connectLabel` y `connectRoute` para adaptarse al flujo IoT (`/files-list`) y al flujo de cámara (`/camera-stream`).

```dart
// Flujo archivos IoT (valores por defecto)
WiFiListPage()

// Flujo cámara (configurado desde main.dart)
WiFiListPage(
  pageTitle: 'Stream',
  connectLabel: 'Conexión a cámara',
  connectRoute: '/camera-stream',
)
```

---

## Pruebas unitarias

Stack: `flutter_test` + `mockito` + `bloc_test`

Mocks generados con `@GenerateMocks` + `build_runner`. Cada archivo de test tiene su propio `.mocks.dart` generado.

| Suite | Tests | Feature | Capa |
|-------|------:|---------|------|
| `wifi_local_datasource_test` | 13 | wifi | data |
| `get_wifi_networks_test` | 5 | wifi | domain |
| `save_wifi_network_test` | 8 | wifi | domain |
| `wifi_bloc_test` | 6 | wifi | presentation |
| `file_entity_test` | 17 | files | domain |
| `get_files_test` | 3 | files | domain |
| `download_file_test` | 3 | files | domain |
| `files_bloc_test` | 5 | files | presentation |
| **Total** | **60** | | |

Ejecutar:
```bash
flutter test test/features/
```

---

## Paleta corporativa (`AppColors`)

| Constante | Hex | Uso |
|-----------|-----|-----|
| `primary` | `#006633` | Verde oscuro — principal |
| `secondary` | `#3AAA35` | Verde claro — secundario / éxito |
| `forest` | `#597D60` | Verde bosque |
| `golden` | `#E3B947` | Dorado — advertencias |
| `burnt` | `#D45219` | Naranja quemado — errores |
| `surface` | `#F4FAF6` | Fondo de pantallas |

Gradientes predefinidos: `gradientPrimary`, `gradientSecondary`, `gradientBackground`.

---

## Notas técnicas críticas

**Android Wi-Fi binding**: En Android 10+ con datos móviles activos, el tráfico HTTP no va por Wi-Fi. `WifiNetworkClient` lo resuelve via código nativo. Este binding DEBE asegurarse antes de cualquier petición al dispositivo IoT.

**Secure storage namespaces**: Hay tres namespaces separados. No mezclar claves entre ellos:
- `ecotrap_api_prefs` (prefijo `api_`) — API Key y baseUrl IoT
- `ecotrap_sync_prefs` (prefijo `ecotrap_`) — credenciales backend
- `ecotrap_wifi_prefs` — credenciales reconexión Wi-Fi

**HiveField indices**: Los índices 0-5 de `WiFiNetworkModel` son fijos por contrato de serialización. Nuevos campos usan índices ≥ 6.

**build_runner**: Ejecutar `dart run build_runner build --delete-conflicting-outputs` siempre que se modifique un modelo Hive (`@HiveType`, `@HiveField`).
