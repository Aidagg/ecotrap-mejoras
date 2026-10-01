# Features — EcoTrap v2.9.1

Descripción funcional y técnica de cada feature de la aplicación.

---

## Índice

- [Home](#home)
- [WiFi](#wifi)
- [Files](#files)
- [Stream](#stream)
- [Upload](#upload)
- [Configuración](#configuración)

---

## Home

**Ruta:** `lib/features/home/presentation/pages/home_page.dart`  
**Ruta de navegación:** `/home`

Pantalla de bienvenida y panel de navegación principal. Es la primera pantalla que ve el usuario al abrir la app.

### Pantalla

Fondo con gradiente corporativo (`AppColors.gradientBackground`) y tres botones grandes (`_HeroButton`) con gradiente, ícono y subtítulo descriptivo:

| Botón | Ícono | Destino | Gradiente |
|-------|-------|---------|-----------|
| Conectar a trampa | `devices` | `/wifi-list` | `primary → primaryDark` |
| Subir datos | `cloud_upload` | `/upload` | `secondary → secondaryDark` |
| Ver cámara en tiempo real | `videocam_rounded` | `/camera-wifi` | `forest → brown` |

El contenido está envuelto en `SingleChildScrollView` para evitar overflow en pantallas pequeñas.

### Diseño técnico

- `StatelessWidget` sin BLoC (no gestiona estado propio)
- Versión (`AppConstants.version`) y empresa (`AppConstants.company`) mostrados al pie
- Todos los colores provienen de `AppColors`

---

## WiFi

**Rutas:** `lib/features/wifi/`  
**Rutas de navegación:** `/wifi-list`, `/camera-wifi`

Gestiona el listado, creación, edición y eliminación de las redes Wi-Fi de los dispositivos IoT. También permite escanear redes cercanas con prefijo `ENTOMO`.

### Arquitectura

```
domain/
├── entities/wifi_network.dart          ← WiFiNetwork (id, ssid, password, bssid, createdAt)
├── repositories/wifi_repository.dart   ← Contrato abstracto con Either<Failure, T>
└── usecases/
    ├── get_wifi_networks.dart           ← Paginación validada (page ≥ 1, pageSize 1-100)
    ├── save_wifi_network.dart           ← Valida SSID (2-32 chars), contraseña (8-63 chars)
    ├── update_wifi_network.dart         ← Mismas validaciones + id
    ├── delete_wifi_network.dart         ← Solo id
    └── get_total_count.dart             ← Cuenta total para paginación

data/
├── models/wifi_network_model.dart      ← @HiveType(0), campos 0-5 fijos
├── datasources/wifi_local_datasource.dart ← CRUD Hive, unicidad SSID case-insensitive
└── repositories/wifi_repository_impl.dart ← Convierte Exception → Failure

presentation/
├── bloc/wifi_bloc.dart                 ← 9 eventos, 12 estados
├── pages/wifi_list_page.dart           ← Parametrizable (pageTitle, connectLabel, connectRoute)
└── widgets/
    ├── wifi_list_item.dart             ← Tarjeta con señal en tiempo real
    └── add_wifi_dialog.dart            ← Formulario crear/editar
```

### WiFiListPage — reutilización dual

La misma pantalla sirve para dos flujos gracias a sus parámetros:

```dart
// Flujo "Descargar archivos"
WiFiListPage()
// connectRoute = '/files-list' (por defecto)

// Flujo "Ver cámara"
WiFiListPage(
  pageTitle: 'Stream',
  connectLabel: 'Conexión a cámara',
  connectRoute: '/camera-stream',
)
```

### Escaneo de redes cercanas

Al pulsar el ícono de radar en el AppBar:

1. Verifica que el Wi-Fi esté activo
2. Lee la red conectada actualmente (SSID + BSSID)
3. Llama `wifi_iot.WiFiForIoTPlugin.loadWifiList()`
4. Filtra redes cuyo SSID empieza por `ENTOMO` (case-insensitive)
5. Ordena por intensidad de señal descendente
6. Emite `WiFiNearbyLoaded` con redes cercanas y guardadas

### Persistencia

Base de datos Hive, box `wifi_networks`, adaptador `WiFiNetworkModelAdapter` (generado por `build_runner`).

**Índices HiveField fijos — no reutilizar:**

| Índice | Campo |
|--------|-------|
| 0 | id |
| 1 | ssid |
| 2 | password |
| 3 | createdAt |
| 4 | updatedAt |
| 5 | bssid |

Nuevos campos usan índices ≥ 6.

### Tests

```
test/features/wifi/
├── data/datasources/wifi_local_datasource_test.dart  (13 tests)
├── domain/usecases/get_wifi_networks_test.dart       (5 tests)
├── domain/usecases/save_wifi_network_test.dart       (8 tests)
└── presentation/bloc/wifi_bloc_test.dart             (6 tests)
```
**Total: 32 tests**

---

## Files

**Rutas:** `lib/features/files/`  
**Rutas de navegación:** `/api-check`, `/api-config`, `/files-list`

Permite al técnico explorar y descargar los archivos generados por el dispositivo IoT (imágenes JPG y registros JSON).

### Flujo de usuario

```
/wifi-list → conectar a red IoT
    ↓
/api-check → verificar API Key
    ├── Sin API Key → /api-config
    └── Con API Key → /files-list
         ├── GET /files → lista archivos
         ├── Tap archivo → descargar individual
         └── Selección múltiple → descarga masiva
```

### Arquitectura

```
domain/
├── entities/file_entity.dart          ← name, size + sizeFormatted, extension, isImage, isJson
├── repositories/files_repository.dart ← getFiles(), downloadFile(name, onProgress)
└── usecases/
    ├── get_files.dart                  ← delega a repositorio
    └── download_file.dart              ← delega con callback de progreso

data/
├── models/file_model.dart              ← extiende FileEntity, JSON serializable
├── datasources/files_remote_datasource.dart ← wraps ApiService
└── repositories/files_repository_impl.dart  ← convierte ApiResponse → throw Exception

presentation/
├── bloc/files_bloc.dart                ← LoadFiles + DownloadFileEvent
└── pages/
    ├── api_check_screen.dart           ← guard de configuración
    ├── api_config_screen.dart          ← formulario API Key + credenciales sync
    └── files_list_screen.dart          ← tabla, descarga, visualizadores
```

### Estados del BLoC

| Estado | Cuándo |
|--------|--------|
| `FilesInitial` | Al crear el BLoC |
| `FilesLoading` | Cargando lista |
| `FilesLoaded(files)` | Lista disponible |
| `FilesError(message)` | Error de red o config |
| `FileDownloading(name, progress)` | Descargando (0.0 → 1.0) |
| `FileDownloaded(filePath)` | Guardado en disco |
| `FileDownloadError(message)` | Error en descarga |

### Descarga con progreso

El callback de progreso se pasa desde el BLoC hasta `ApiService.downloadFile`, que lo invoca con cada chunk de datos recibido por Dio. Cada invocación emite un nuevo estado `FileDownloading` que actualiza la barra de progreso en la UI.

### Visualizadores inline

- **Imagen** (`.jpg`, `.jpeg`, `.png`, etc.): `InteractiveViewer` zoom 5× sobre `Image.file()`
- **JSON** (`.json`): `SelectableText` con toggle pretty/compact vía `JsonEncoder.withIndent`

Solo disponibles si el archivo ya está descargado en disco.

### Carpeta de descarga

Principal: `/storage/emulated/0/Download/EntomoLab-EcoTrap/`  
Fallback: `getApplicationDocumentsDirectory()/EntomoLab-EcoTrap/`

### Tests

```
test/features/files/
├── domain/entities/file_entity_test.dart          (17 tests)
├── domain/usecases/get_files_test.dart            (3 tests)
├── domain/usecases/download_file_test.dart        (3 tests)
└── presentation/bloc/files_bloc_test.dart         (5 tests)
```
**Total: 28 tests**

---

## Stream

**Rutas:** `lib/features/stream/`  
**Rutas de navegación:** `/camera-wifi` → `/camera-stream`

Visualización del stream de cámara MJPEG del dispositivo IoT en tiempo real.

### Endpoints (puerto 8081)

La URL se construye reemplazando el puerto de la baseUrl guardada:

```
http://192.168.100.10/api  →  http://192.168.100.10:8081
```

| Endpoint | Método | Frecuencia | Propósito |
|----------|--------|-----------|-----------|
| `/stream` | GET | Una vez | Stream MJPEG continuo |
| `/stream/ping` | GET | Cada 10 s | Mantener cámara activa |
| `/stream/close` | POST | Al salir | Liberar cámara en IoT |
| `/stream/health` | GET | Al abrir popup | Estado del stream |
| `/health` | GET | Al abrir popup | Estado del dispositivo |

### Parser MJPEG

El stream llega como bytes crudos (`ResponseType.stream`). El parser busca marcadores JPEG:

```
SOI: 0xFF 0xD8  ← inicio del frame
EOI: 0xFF 0xD9  ← fin del frame
```

Cada frame completo se pasa a `Image.memory(frame, gaplessPlayback: true)`. `gaplessPlayback: true` elimina el parpadeo entre frames.

### Gestión del ciclo de vida

La página implementa `WidgetsBindingObserver`:

| Ciclo de vida | Acción |
|--------------|--------|
| `paused` / `inactive` / `detached` | `_closeAndStop()` (detiene stream + libera cámara) |
| `resumed` | No reconecta automáticamente |
| `dispose()` | `_stopInternals()` + `_callClose()` (fire-and-forget) |

`_closeAndStop()` siempre llama `POST /stream/close` para garantizar que el IoT libera la cámara, independientemente de cómo salga el usuario.

### Timeout y cuenta regresiva

- **Duración:** 3 minutos desde que inicia el stream
- **Countdown:** se actualiza cada segundo en el AppBar
- **Color de alerta:** rojo cuando quedan ≤ 30 segundos
- **Al expirar:** diálogo con opciones "Reconectar" y "Salir"

### Heartbeat

```dart
Timer.periodic(Duration(seconds: 10), (_) async {
  await _dio.get(_urlPing);
});
```

Sin el ping, el IoT cierra la sesión de cámara por inactividad.

### Popup de estado del dispositivo

Botón `Icons.monitor_heart_outlined` en AppBar. Hace dos peticiones en paralelo y muestra:

**Sección GENERAL**

| Etiqueta | Path JSON |
|----------|-----------|
| Trampa | `last_cycle.id_trap` |
| Última Marca | `last_cycle.last_key` |
| Último Archivo | `last_cycle.last_run` |
| Hora Local | `time_local` |

**Sección SENSORES**

| Etiqueta | Path JSON |
|----------|-----------|
| Batería | `sensors.battery.battery_pct` |
| Humedad | `sensors.dht22.hum_pct` |
| Temperatura Externa (°C) | `sensors.dht22.temp_c` |
| Temp. Interna (°C) | `sensors.ds18b20.temp_c` |

**Sección OFFLINE**

| Etiqueta | Path JSON |
|----------|-----------|
| Imágenes | `offline_queue.jpg` |
| Json | `offline_queue.json` |

Valores ausentes se muestran como `—`.

### Sin tests unitarios actualmente

La lógica de parsing MJPEG y el ciclo de vida están acoplados al widget. Si se extrae a un servicio, añadir tests de:
- `_buildStreamBase()` — transformación de URL con puerto 8081
- `_processBuffer()` — parser de frames JPEG

---

## Upload

**Rutas:** `lib/features/upload/`  
**Ruta de navegación:** `/upload`

Sincronización de archivos JSON descargados del IoT al servidor de monitorización EntomoLab.

### Destino

```
https://backendmonitorizacion.ecotrap.es/api/v1
```

Enrutamiento por `option_menu` del JSON:

| `option_menu` | Endpoint |
|--------------|----------|
| `0063` | `POST /web/monitorizacion` |
| `0064` | `POST /web/monitorizacion/medicion` |

### Seguimiento de archivos sincronizados

Cuando un archivo se sube correctamente, se crea `{nombre}.synced` junto al JSON. Al recargar la pantalla, se buscan estos archivos `.synced` para marcar visualmente cuáles ya están sincronizados.

```
/Download/EntomoLab-EcoTrap/
  ciclo_001.json         ← pendiente
  ciclo_001.json.synced  ← marcador de sincronizado
  ciclo_002.json         ← pendiente
```

### Autenticación JWT

1. Token leído de secure storage
2. Si no hay token → login automático con credenciales guardadas
3. Si el servidor responde 401 → borrar token → re-login → reintentar
4. Si no hay credenciales → diálogo de login

Las llamadas HTTP van a través de `WifiNetworkClient.runWithInternet()` para usar internet (no la red Wi-Fi del IoT).

### Diseño técnico

- `StatefulWidget` sin BLoC (estado gestionado localmente)
- Overlay de progreso con `Stack` + `IgnorePointer` durante la subida
- Long-press activa modo selección múltiple
- Chips de resumen: Total / Sincronizados / Pendientes

---

## Configuración

### ApiCheckScreen

**Ruta:** `/api-check`

Pantalla de puerta de entrada al explorador de archivos. Verifica en `ApiConfigService` si hay API Key guardada:

- **Con API Key** → navega directamente a `/files-list`
- **Sin API Key** → navega a `/api-config`

Muestra un `CircularProgressIndicator` mientras comprueba. El usuario normalmente no la ve más de un instante.

### ApiConfigScreen

**Ruta:** `/api-config`

Formulario de configuración con dos bloques independientes:

**Bloque IoT** (almacenado en `ApiConfigService`, namespace `ecotrap_api_prefs`):

| Campo | Validación |
|-------|-----------|
| API Key | Alfanumérico, mínimo 16 caracteres |
| URL Base | HTTP o HTTPS válida; vacío → usa `http://192.168.100.10/api` |

**Bloque Sincronización** (almacenado en `SyncService`, namespace `ecotrap_sync_prefs`):

| Campo | Validación |
|-------|-----------|
| Usuario | No vacío |
| Contraseña | No vacío |

Botones adicionales:
- **Probar conexión**: hace `GET /files` antes de guardar para verificar la API Key
- **Probar sincronización**: hace login real contra el servidor de monitorización
- **Cerrar sesión sync**: borra credenciales y token JWT del secure storage
