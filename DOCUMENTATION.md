# Documentación técnica — EcoTrap

**Versión:** 2.9.1 · **Empresa:** EntomoLab · **Plataforma:** Android (Flutter)

---

## Índice

1. [Visión general del proyecto](#1-visión-general-del-proyecto)
2. [Arquitectura](#2-arquitectura)
3. [Punto de entrada — `main.dart`](#3-punto-de-entrada--maindart)
4. [Capa Core](#4-capa-core)
   - 4.1 [Inyección de dependencias](#41-inyección-de-dependencias--corediinjectiondart)
   - 4.2 [Gestión de errores](#42-gestión-de-errores)
   - 4.3 [ApiConfigService](#43-apiconfigservice)
   - 4.4 [ApiService](#44-apiservice)
   - 4.5 [WifiNetworkClient](#45-wifinetworkclient)
   - 4.6 [SyncService](#46-syncservice)
   - 4.7 [WiFiConnectionService](#47-wificonnectionservice)
   - 4.8 [WiFiReconnectService](#48-wifireconnectservice)
   - 4.9 [PermissionService](#49-permissionservice)
   - 4.10 [AppColors](#410-appcolors)
   - 4.11 [AppConstants](#411-appconstants)
5. [Feature: WiFi](#5-feature-wifi)
   - 5.1 [Entidad WiFiNetwork](#51-entidad-wifinetwork)
   - 5.2 [Repositorio abstracto WiFiRepository](#52-repositorio-abstracto-wifirepository)
   - 5.3 [Modelo WiFiNetworkModel (Hive)](#53-modelo-wifinetworkmodel-hive)
   - 5.4 [DataSource local](#54-datasource-local)
   - 5.5 [Implementación del repositorio](#55-implementación-del-repositorio)
   - 5.6 [Casos de uso](#56-casos-de-uso)
   - 5.7 [WiFiBloc](#57-wifibloc)
   - 5.8 [Pantalla WiFiListPage](#58-pantalla-wifilistpage)
6. [Feature: Files](#6-feature-files)
   - 6.1 [Entidad FileEntity](#61-entidad-fileentity)
   - 6.2 [Repositorio y DataSource](#62-repositorio-y-datasource)
   - 6.3 [Casos de uso](#63-casos-de-uso)
   - 6.4 [FilesBloc](#64-filesbloc)
   - 6.5 [Pantalla FilesListScreen](#65-pantalla-fileslistscreen)
7. [Feature: Stream (cámara en tiempo real)](#7-feature-stream-cámara-en-tiempo-real)
8. [Feature: Upload](#8-feature-upload)
9. [Feature: Home](#9-feature-home)
10. [Pantallas de configuración](#10-pantallas-de-configuración)
11. [Flujos de datos completos](#11-flujos-de-datos-completos)
12. [Pruebas unitarias](#12-pruebas-unitarias)
13. [Guía de desarrollo](#13-guía-de-desarrollo)

---

## 1. Visión general del proyecto

EcoTrap es una aplicación Android desarrollada con Flutter cuya misión es facilitar el trabajo de los técnicos de campo de EntomoLab cuando visitan una trampa fitosanitaria IoT. El dispositivo IoT es un ordenador embebido (Raspberry Pi o similar) que:

- Captura imágenes con una cámara
- Registra datos de sensores (temperatura, humedad, batería)
- Expone una API REST local por Wi-Fi
- No tiene acceso permanente a internet

El flujo de trabajo del técnico es:

```
1. Ir al campo → conectar el teléfono al Wi-Fi del dispositivo IoT
2. Con EcoTrap → descargar archivos (JPG y JSON) al móvil
3. Opcionalmente → ver la cámara en tiempo real para verificar la trampa
4. Volver a zona con cobertura → subir los JSON al servidor de monitorización
```

La aplicación es **offline-first**: no necesita internet para las operaciones con el IoT.

---

## 2. Arquitectura

El proyecto sigue **Clean Architecture** con tres capas por cada feature:

```
┌─────────────────────────────────────────────────────────┐
│                  Presentation Layer                     │
│         BLoC ← Events / States → Widgets/Pages         │
├─────────────────────────────────────────────────────────┤
│                    Domain Layer                         │
│    Entities · Repositories (abstract) · Use Cases      │
├─────────────────────────────────────────────────────────┤
│                     Data Layer                          │
│    Models · DataSources · Repository Implementations   │
└─────────────────────────────────────────────────────────┘
```

**Regla de dependencia:** cada capa solo conoce a la capa inmediatamente inferior. La capa de dominio es 100 % pura en Dart, sin dependencias de Flutter ni de paquetes externos.

**Estructura de directorios:**

```
lib/
├── core/                        ← Código compartido por todos los features
│   ├── di/
│   │   └── injection.dart       ← Registro de dependencias (GetIt)
│   ├── errors/
│   │   ├── exceptions.dart      ← Excepciones de la capa de datos
│   │   └── failures.dart        ← Failures de la capa de dominio
│   ├── network/
│   │   ├── api_config_service.dart   ← API Key y URL base (cifrado)
│   │   ├── api_service.dart          ← Cliente HTTP principal (Dio)
│   │   ├── download_config_service.dart ← Preferencia de carpeta de descarga
│   │   ├── sync_service.dart         ← Subida de JSON al servidor central
│   │   ├── wifi_network_client.dart  ← Binding del proceso a la red Wi-Fi
│   │   └── wifi_reconnect_service.dart ← Reconexión automática
│   ├── services/
│   │   ├── permission_service.dart   ← Permisos Android
│   │   └── wifi_connection_service.dart ← Conexión Wi-Fi con permisos
│   ├── usecases/
│   │   └── usecase.dart              ← Contrato base UseCase<T, P>
│   └── utils/
│       ├── app_colors.dart           ← Paleta de colores
│       └── app_constants.dart        ← Constantes globales
│
└── features/
    ├── files/                   ← Descarga de archivos del IoT
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   └── files_remote_datasource.dart
    │   │   ├── models/
    │   │   │   └── file_model.dart
    │   │   └── repositories/
    │   │       └── files_repository_impl.dart
    │   ├── domain/
    │   │   ├── entities/
    │   │   │   └── file_entity.dart
    │   │   ├── repositories/
    │   │   │   └── files_repository.dart
    │   │   └── usecases/
    │   │       ├── get_files.dart
    │   │       └── download_file.dart
    │   └── presentation/
    │       ├── bloc/
    │       │   ├── files_bloc.dart
    │       │   ├── files_event.dart
    │       │   └── files_state.dart
    │       └── pages/
    │           ├── api_check_screen.dart
    │           ├── api_config_screen.dart
    │           └── files_list_screen.dart
    ├── home/
    │   └── presentation/pages/
    │       └── home_page.dart
    ├── stream/
    │   └── presentation/pages/
    │       └── camera_stream_page.dart
    ├── upload/
    │   └── presentation/pages/
    │       └── upload_page.dart
    └── wifi/
        ├── data/
        │   ├── datasources/
        │   │   └── wifi_local_datasource.dart
        │   ├── models/
        │   │   └── wifi_network_model.dart
        │   └── repositories/
        │       └── wifi_repository_impl.dart
        ├── domain/
        │   ├── entities/
        │   │   └── wifi_network.dart
        │   ├── repositories/
        │   │   └── wifi_repository.dart
        │   └── usecases/
        │       ├── get_wifi_networks.dart
        │       ├── save_wifi_network.dart
        │       ├── update_wifi_network.dart
        │       ├── delete_wifi_network.dart
        │       └── get_total_count.dart
        └── presentation/
            ├── bloc/
            │   ├── wifi_bloc.dart
            │   ├── wifi_event.dart
            │   └── wifi_state.dart
            └── pages/
                └── wifi_list_page.dart
```

---

## 3. Punto de entrada — `main.dart`

**Ruta:** `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([...portrait...]);
  await initDependencies();   // registra todos los servicios en GetIt
  runApp(const EcotrapApp());
}
```

### Qué hace antes de arrancar la UI

| Paso | Acción | Por qué |
|------|--------|---------|
| `ensureInitialized()` | Inicializa el binding de Flutter | Necesario para llamadas async antes de `runApp` |
| `setPreferredOrientations` | Fuerza portrait | La UI no está diseñada para landscape |
| `initDependencies()` | Inicializa Hive y registra todo en GetIt | Los widgets necesitan acceder al contenedor de DI |

### Tema global (`ThemeData`)

El tema define todos los estilos una sola vez, de forma que ningún widget necesita escribir colores hardcoded. Los valores importantes:

- `primaryColor` → `AppColors.primary` (`#006633`)
- `colorScheme` → generado con `ColorScheme.fromSeed` para que Material 3 derive todos los colores restantes
- `AppBarTheme` → fondo `primary`, texto blanco, sin elevación, `centerTitle: true`
- `ElevatedButtonTheme` → fondo `primary`, bordes redondeados 12 px, padding cómodo para dedos
- `InputDecorationTheme` → borde redondeado 12 px, fondo `primarySurface`, borde activo verde
- `SnackBarTheme` → flotante, en la parte inferior con insets para no tapar el FAB

### Rutas declaradas

```
/home          → HomePage (pantalla principal)
/wifi-list     → WiFiListPage (modo archivos: connectRoute='/files-list')
/camera-wifi   → WiFiListPage (modo cámara: connectRoute='/camera-stream')
/camera-stream → CameraStreamPage
/upload        → UploadPage
/api-check     → ApiCheckScreen
/api-config    → ApiConfigScreen
/files-list    → FilesListScreen
```

La misma `WiFiListPage` sirve para dos flujos distintos gracias a los parámetros `pageTitle`, `connectLabel` y `connectRoute`. El BLoC se crea en línea con `BlocProvider(create: (_) => sl<WiFiBloc>())` para que cada pantalla tenga su propia instancia independiente.

---

## 4. Capa Core

### 4.1 Inyección de dependencias — `core/di/injection.dart`

Usa el paquete **GetIt** como contenedor de servicios (service locator). GetIt permite obtener cualquier dependencia en cualquier parte del árbol sin pasar parámetros por los constructores de los widgets.

```dart
final sl = GetIt.instance;   // "sl" = service locator
```

**Tipos de registro usados:**

| Método | Cuándo se crea | Cuántas instancias |
|--------|---------------|-------------------|
| `registerLazySingleton` | Primera vez que se pide | Una sola (compartida) |
| `registerFactory` | Cada vez que se pide | Nueva cada vez |

Los BLoCs usan `registerFactory` porque cada pantalla necesita su propia instancia que empiece en estado inicial y tenga su propio ciclo de vida.

**Orden de registro:**

1. **Dependencias externas** (Hive, Uuid) — primero porque todo lo demás depende de ellas
2. **DataSources** — dependen de Hive o ApiService
3. **Repositories** — dependen de DataSources
4. **Use Cases** — dependen de Repositories
5. **BLoCs** — dependen de Use Cases

---

### 4.2 Gestión de errores

EcoTrap usa dos tipos de objetos para representar errores, cada uno en su capa correspondiente.

#### `core/errors/exceptions.dart` — Capa de datos

Las **Exceptions** se lanzan con `throw` en DataSources cuando algo va mal con el almacenamiento o la red.

| Clase | Cuándo se lanza |
|-------|----------------|
| `CacheException(message)` | Fallo al leer/escribir Hive |
| `ValidationException(message)` | Datos inválidos al guardar (SSID duplicado, etc.) |
| `NotFoundException(message)` | Se pide un recurso que no existe en la BD local |

**No se propagan a la UI directamente.** El repositorio las captura y las convierte en `Failure`.

#### `core/errors/failures.dart` — Capa de dominio

Los **Failures** extienden `Equatable` para poder compararlos en tests y en estados BLoC. Son inmutables y se devuelven en el lado izquierdo del tipo `Either<Failure, T>`.

| Clase | Origen típico |
|-------|--------------|
| `CacheFailure(message)` | Convertido desde `CacheException` |
| `ValidationFailure(message)` | Validaciones en Use Cases o desde `ValidationException` |
| `NotFoundFailure(message)` | Convertido desde `NotFoundException` |
| `UnexpectedFailure(message)` | Cualquier error no tipado |

**Patrón Either:** en lugar de lanzar excepciones en la capa de dominio, las funciones devuelven `Either<Failure, T>`. El llamador usa `.fold(onFailure, onSuccess)` para manejar ambos casos de forma explícita y sin try-catch.

---

### 4.3 ApiConfigService

**Ruta:** `core/network/api_config_service.dart`

Servicio estático responsable de guardar y recuperar la configuración de acceso a la API del IoT. Todo se almacena cifrado en `EncryptedSharedPreferences` de Android (a través de `flutter_secure_storage`).

```
Almacenamiento: SharedPreferences cifrado
Nombre del fichero: "ecotrap_api_prefs"
Prefijo de claves: "api_"
```

**Métodos principales:**

| Método | Descripción |
|--------|-------------|
| `saveApiKey(String)` → `bool` | Borra la clave anterior y escribe la nueva cifrada |
| `getApiKey()` → `String?` | Lee y devuelve la API Key, o `null` si no existe |
| `hasApiKey()` → `bool` | Comprueba si hay API Key guardada |
| `deleteApiKey()` → `bool` | Elimina la API Key del almacenamiento seguro |
| `saveBaseUrl(String)` → `bool` | Guarda la URL base cifrada |
| `getBaseUrl()` → `String` | Devuelve la URL guardada o `defaultBaseUrl` si no hay ninguna |
| `isValidApiKey(String)` → `bool` | Valida: mínimo 16 caracteres, solo alfanuméricos |
| `isValidBaseUrl(String)` → `bool` | Valida que sea HTTP o HTTPS |
| `getConfig()` → `ApiConfig` | Devuelve objeto con API Key + URL en una sola llamada |
| `saveConfig({apiKey, baseUrl?})` → `bool` | Guarda ambos; si `baseUrl` está vacía, borra la clave (vuelve al default) |
| `clearConfig()` → `bool` | Elimina API Key y URL |
| `deleteAll()` → `void` | Limpia todo el almacenamiento seguro |

**Clase `ApiConfig`:**

```dart
class ApiConfig {
  final String? apiKey;
  final String baseUrl;
  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;
}
```

`isConfigured` es la propiedad que usa `ApiService` para decidir si puede hacer peticiones.

**URL por defecto:** `http://192.168.100.10/api` (IP estática típica de la red Wi-Fi del IoT).

---

### 4.4 ApiService

**Ruta:** `core/network/api_service.dart`

Cliente HTTP principal que se comunica con la API del dispositivo IoT. Usa **Dio** internamente.

**Diseño:**

- `_dio` es `null` hasta que se hace la primera petición. Se inicializa perezosamente en `_getDio()` con la configuración leída de `ApiConfigService`.
- El constructor registra un callback en `WifiNetworkClient.onWifiRebound` para resetear `_dio` a `null` cada vez que la red Wi-Fi se re-vincula. Así la próxima petición creará un Dio nuevo vinculado correctamente.

**Constantes:**

```dart
static const int timeoutSeconds = 10;
static const int maxRetries = 3;
static const String _folderName = 'EntomoLab-EcoTrap';
```

**Inicialización de Dio (`_getDio`):**

1. Verifica la configuración con `ApiConfigService.getConfig()`
2. Llama `WifiNetworkClient.ensureWifiBinding()` para garantizar que el tráfico salga por Wi-Fi
3. Crea `Dio` con `baseUrl`, timeouts y cabecera `x-api-key`
4. Llama `WifiNetworkClient.bindDioToWifi(dio)` para configurar el adaptador HTTP nativo
5. Añade un interceptor que registra todas las peticiones/respuestas/errores en consola

**Métodos públicos:**

#### `getFiles()` → `ApiResponse<List<FileInfo>>`

- Implementa reintentos (hasta 3 veces) con backoff (`attempts * 2` segundos)
- No reintenta en errores 400/401/403/404 (son definitivos)
- Acepta respuesta del servidor tanto como `Map` como `String` (algunos servidores no envían `Content-Type: application/json`)
- Extrae el array `files` y lo mapea a objetos `FileInfo`

#### `downloadFile({fileName, onProgress})` → `ApiResponse<String>`

- Guarda el archivo en `/storage/emulated/0/Download/EntomoLab-EcoTrap/`
- Si la carpeta pública no está disponible, usa el directorio privado de la app como fallback
- Llama `GET /download?file=<nombre>` usando `dio.download()` que descarga directo a disco
- El callback `onProgress(double)` recibe valores entre 0.0 y 1.0

#### `_handleDioError<T>` (privado)

Convierte `DioException` en `ApiResponse.error` con mensajes en español según el código HTTP:

| HTTP | Mensaje |
|------|---------|
| 401 | "API Key incorrecta. Ve a Configuración para actualizarla." |
| 403 | "Acceso prohibido. Verifica tu API Key." |
| 404 | "Archivo no encontrado en el servidor" |
| 5xx | "Error interno del servidor." |
| timeout | "Tiempo de espera agotado." |
| connectionError | "No se pudo conectar... Verifica la red WiFi correcta." |

**Clase `FileInfo`:**

Objeto de datos simple con `name` y `size` más las mismas propiedades calculadas que `FileEntity` (`sizeFormatted`, `extension`, `isImage`, `isJson`).

**Clase `ApiResponse<T>`:**

```dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final ErrorType? errorType;
}
```

`ErrorType` es un enum con: `badRequest`, `unauthorized`, `forbidden`, `notFound`, `serverError`, `timeout`, `connectionError`, `permissionDenied`, `storageError`, `unknown`.

---

### 4.5 WifiNetworkClient

**Ruta:** `core/network/wifi_network_client.dart`

Esta es la pieza más compleja del núcleo. Gestiona la vinculación del proceso Android a la red Wi-Fi del IoT.

**El problema:** Android, a partir de API 21, cuando detecta que una red Wi-Fi no tiene acceso a internet, redirige automáticamente todo el tráfico de la app por la red de datos móviles. Esto hace que las peticiones a `192.168.100.10` fallen porque van por la red móvil.

**La solución:** llamar a `ConnectivityManager.bindProcessToNetwork()` de Android, que obliga a que todo el tráfico del proceso use esa red Wi-Fi aunque no tenga internet.

**Comunicación con Android nativo:**

```dart
static const _channel = MethodChannel('es.ecotrap.ecotrap/wifi_network');
```

El código nativo en `MainActivity.kt` implementa los métodos:
- `bindToWifi` → llama `ConnectivityManager.bindProcessToNetwork()`
- `unbindNetwork` → llama `ConnectivityManager.bindProcessToNetwork(null)`
- `getWifiIpAddress` → devuelve la IP de la interfaz Wi-Fi

**Métodos estáticos:**

#### `bindProcessToWifi()` → `bool`

Invoca el canal nativo `bindToWifi`. Devuelve `true` si el binding tuvo éxito.

#### `unbindNetwork()`

Elimina el binding para que el tráfico pueda salir por internet (necesario para subir al servidor).

#### `ensureWifiBinding()`

Método de alto nivel llamado antes de cada operación de red con el IoT:

1. Espera si otro hilo está usando internet (`_isRunningWithInternet = true`)
2. Intenta binding directo
3. Si falla, intenta reconexión automática (`_bindWithAutoReconnect`)
4. Si tampoco funciona, informa por consola

#### `bindDioToWifi(Dio dio)`

Configura el `httpClientAdapter` de Dio con un `IOHttpClientAdapter` personalizado. Esto garantiza que las conexiones TCP que abra Dio usen el socket vinculado a la red Wi-Fi.

#### `runWithInternet<T>(action)` → `T`

Patrón muy importante: deshabilita el binding de Wi-Fi temporalmente para que la app pueda acceder a internet, ejecuta la acción y luego restaura el binding.

```
1. Esperar turno (si otro runWithInternet está en ejecución)
2. _isRunningWithInternet = true
3. unbindNetwork()
4. Esperar 800ms (Android necesita tiempo para redirigir el tráfico)
5. await action()   ← aquí se hace la petición a internet
6. (en finally) _bindWithAutoReconnect()
7. notificar ApiService para resetear _dio
8. _isRunningWithInternet = false
```

#### `_bindWithAutoReconnect()` → `bool` (privado)

1. Intento 1: binding directo
2. Si falla: `WiFiReconnectService.reconnectToLastWifi()`
3. Espera 2 segundos y reintenta el binding hasta 5 veces con backoff

---

### 4.6 SyncService

**Ruta:** `core/network/sync_service.dart`

Gestiona la autenticación y subida de datos JSON al servidor de monitorización central.

**URL del servidor:** `https://backendmonitorizacion.ecotrap.es/api/v1`

**Almacenamiento de credenciales:**

```
SharedPreferences cifrado: "ecotrap_sync_prefs"
Prefijo: "ecotrap_"
Claves: sync_user, sync_password, sync_token
```

**Método de sincronización `syncJson(appDirPath, fileName)`:**

El campo `option_menu` del JSON determina el endpoint de destino:

| `option_menu` | Endpoint |
|--------------|----------|
| `"0063"` | `POST /web/monitorizacion` |
| `"0064"` | `POST /web/monitorizacion/medicion` |

**Flujo completo:**

```
1. Leer token guardado
2. Si no hay token → login automático con credenciales guardadas
3. Leer el archivo JSON del disco
4. Extraer option_menu
5. WifiNetworkClient.runWithInternet(() → POST al servidor)
6. Si 401 (token expirado) → borrar token, re-login, reintentar
7. markAsSynced() → crear fichero .synced en disco
```

**Seguimiento de archivos sincronizados:**

Crea un archivo vacío con el sufijo `.synced` junto a cada JSON subido. Ejemplo: `ciclo_001.json.synced`. Este mecanismo es 100 % local y no requiere base de datos.

```dart
static bool isSynced(appDirPath, fileName)  // comprueba si .synced existe
static Future markAsSynced(appDirPath, fileName)  // crea el .synced
static Set<String> loadSyncedFiles(appDirPath)  // lista todos los .synced
```

---

### 4.7 WiFiConnectionService

**Ruta:** `core/services/wifi_connection_service.dart`

Servicio de alto nivel que orquesta la conexión a una red Wi-Fi guardada. Combina la verificación de permisos, la conexión mediante `wifi_iot` y el guardado de la red en `WiFiReconnectService`.

Devuelve un objeto `WiFiConnectionResult` con:
- `success: bool`
- `errorMessage: String?`

---

### 4.8 WiFiReconnectService

**Ruta:** `core/network/wifi_reconnect_service.dart`

Persiste el SSID, contraseña y BSSID de la última red usada en `SharedPreferences` y los usa para reconectarse automáticamente cuando el binding falla (ver `WifiNetworkClient._bindWithAutoReconnect`).

---

### 4.9 PermissionService

**Ruta:** `core/services/permission_service.dart`

Gestiona los permisos de Android necesarios para usar Wi-Fi:

- En Android 12+ (`SDK >= 31`): permiso `NEARBY_WIFI_DEVICES`
- En versiones anteriores: `ACCESS_FINE_LOCATION`

Si el usuario deniega el permiso permanentemente, muestra un diálogo que lleva a los ajustes del sistema (`openAppSettings()`).

---

### 4.10 AppColors

**Ruta:** `core/utils/app_colors.dart`

Clase sellada (`AppColors._()`) que centraliza toda la paleta de colores. **Ningún widget debe usar colores hardcoded** fuera de esta clase.

| Token | Hex | Uso principal |
|-------|-----|--------------|
| `primary` | `#006633` | AppBar, botones principales, bordes activos |
| `primaryDark` | `#004D22` | Hover/pressed, SnackBar |
| `primaryLight` | `#33885A` | Iconos sobre fondo claro |
| `primarySurface` | `#E8F4EE` | Fondo de cards, input fill |
| `secondary` | `#3AAA35` | FAB, estados de éxito |
| `secondaryDark` | `#2A8A25` | Hover sobre secondary |
| `forest` | `#597D60` | Textos secundarios, bordes |
| `olive` | `#949644` | Acentos informativos |
| `golden` | `#E3B947` | Advertencias, íconos de batería |
| `burnt` | `#D45219` | Errores, estados de error |
| `brown` | `#63442B` | Botón de cámara |
| `surface` | `#F4FAF6` | Fondo general de pantallas |
| `textPrimary` | `#1A2E22` | Texto principal |
| `textSecondary` | `#4A6B52` | Texto secundario, hints |

También define tres gradientes predefinidos usados en la pantalla Home.

---

### 4.11 AppConstants

**Ruta:** `core/utils/app_constants.dart`

```dart
class AppConstants {
  static const String version = '2.9.1';
  static const String appName = 'EcoTrap';
  static const String company = 'EntomoLab';
}
```

---

## 5. Feature: WiFi

Este feature gestiona el listado de redes Wi-Fi guardadas con las que la app puede conectarse al dispositivo IoT. Implementa Clean Architecture completo.

### 5.1 Entidad WiFiNetwork

**Ruta:** `features/wifi/domain/entities/wifi_network.dart`

```dart
class WiFiNetwork extends Equatable {
  final String id;           // UUID generado al crear
  final String ssid;         // Nombre de la red
  final String password;     // Contraseña
  final String? bssid;       // MAC de la red (opcional, para reconexión precisa)
  final DateTime createdAt;
  final DateTime? updatedAt;
}
```

Extiende `Equatable` para que dos instancias con los mismos datos sean consideradas iguales sin sobrescribir `==` manualmente. Tiene método `copyWith()` para hacer copias modificadas de forma inmutable.

### 5.2 Repositorio abstracto WiFiRepository

**Ruta:** `features/wifi/domain/repositories/wifi_repository.dart`

Define el contrato que la capa de datos debe cumplir. Usa `Either<Failure, T>` para que los errores sean tipados:

```dart
abstract class WiFiRepository {
  Future<Either<Failure, List<WiFiNetwork>>> getWiFiNetworks({int page, int pageSize});
  Future<Either<Failure, WiFiNetwork>> saveWiFiNetwork({String ssid, String password, String? bssid});
  Future<Either<Failure, WiFiNetwork>> updateWiFiNetwork({String id, String ssid, String password, String? bssid});
  Future<Either<Failure, void>> deleteWiFiNetwork(String id);
  Future<Either<Failure, int>> getTotalCount();
}
```

### 5.3 Modelo WiFiNetworkModel (Hive)

**Ruta:** `features/wifi/data/models/wifi_network_model.dart`

Extiende `WiFiNetwork` y añade las anotaciones de Hive para la serialización:

```
@HiveType(typeId: 0)
Campos: id(0), ssid(1), password(2), createdAt(3), updatedAt(4), bssid(5)
```

La clase adaptadora `WiFiNetworkModelAdapter` es generada automáticamente por `hive_generator` al ejecutar `build_runner`.

También implementa `fromJson()` y `toJson()` por si se necesita serialización JSON adicional.

### 5.4 DataSource local

**Ruta:** `features/wifi/data/datasources/wifi_local_datasource.dart`

**Interfaz:**

```dart
abstract class WiFiLocalDataSource {
  Future<List<WiFiNetworkModel>> getWiFiNetworks({int page, int pageSize});
  Future<WiFiNetworkModel> getWiFiNetworkById(String id);
  Future<WiFiNetworkModel> saveWiFiNetwork(WiFiNetworkModel network);
  Future<WiFiNetworkModel> updateWiFiNetwork(WiFiNetworkModel network);
  Future<void> deleteWiFiNetwork(String id);
  Future<int> getTotalCount();
}
```

**Implementación `WiFiLocalDataSourceImpl`:**

Usa el box de Hive `wifi_networks`. Aquí se lanzan las `Exception` (nunca `Failure`):

- `getWiFiNetworks`: ordena todos los registros por `createdAt` descendente, luego pagina con `skip`/`take`
- `saveWiFiNetwork`: verifica duplicados de SSID (case-insensitive) y lanza `ValidationException` si existe
- `getWiFiNetworkById`: lanza `NotFoundException` si no encuentra el id
- `deleteWiFiNetwork`: lanza `NotFoundException` si la clave no existe

### 5.5 Implementación del repositorio

**Ruta:** `features/wifi/data/repositories/wifi_repository_impl.dart`

Convierte las excepciones de datos en failures de dominio usando try-catch:

```dart
try {
  final result = await localDataSource.saveWiFiNetwork(...);
  return Right(result);
} on ValidationException catch (e) {
  return Left(ValidationFailure(e.message));
} on CacheException catch (e) {
  return Left(CacheFailure(e.message));
} catch (e) {
  return Left(UnexpectedFailure(e.toString()));
}
```

También genera el UUID para los nuevos registros (dependencia inyectada `Uuid`).

### 5.6 Casos de uso

**Ruta:** `features/wifi/domain/usecases/`

Cada caso de uso implementa `UseCase<TReturn, TParams>` y contiene la lógica de negocio pura.

#### `GetWiFiNetworks`

Valida que `page >= 1` y `1 <= pageSize <= 100` antes de llamar al repositorio. Si la validación falla, devuelve `Left(ValidationFailure(...))` directamente sin ir al repositorio.

**Params:** `GetWiFiNetworksParams(page, pageSize)`

#### `SaveWiFiNetwork`

Valida antes de guardar:
- SSID no vacío (tras trim)
- SSID máximo 32 caracteres
- Contraseña no vacía
- Contraseña mínimo 8 caracteres
- Contraseña máximo 63 caracteres (límite WPA2)

Aplica `trim()` al SSID antes de guardarlo.

**Params:** `SaveWiFiNetworkParams(ssid, password, bssid?)`

#### `UpdateWiFiNetwork`

Mismas validaciones que `SaveWiFiNetwork` más el id del registro a actualizar.

#### `DeleteWiFiNetwork`

Solo recibe el id como parámetro (no usa la clase `Params` genérica, acepta `String` directamente).

#### `GetTotalCount`

Sin parámetros (`NoParams`). Devuelve `Either<Failure, int>`.

### 5.7 WiFiBloc

**Ruta:** `features/wifi/presentation/bloc/wifi_bloc.dart`

BLoC central que gestiona toda la interacción del usuario con las redes Wi-Fi.

**Dependencias inyectadas:** `GetWiFiNetworks`, `SaveWiFiNetwork`, `UpdateWiFiNetwork`, `DeleteWiFiNetwork`, `GetTotalCount`

**Constantes:**

```dart
static const int _pageSize = 10;
static const String _entomoPrefix = 'ENTOMO';  // filtro de redes cercanas
```

**Eventos y sus manejadores:**

| Evento | Manejador | Descripción |
|--------|-----------|-------------|
| `LoadWiFiNetworksEvent(page, pageSize)` | `_onLoadWiFiNetworks` | Carga página de redes guardadas |
| `LoadMoreWiFiNetworksEvent` | `_onLoadMoreWiFiNetworks` | Carga la siguiente página (paginación infinita) |
| `RefreshWiFiNetworksEvent` | `_onRefreshWiFiNetworks` | Recarga desde página 1 |
| `SaveWiFiNetworkEvent(ssid, password, bssid?)` | `_onSaveWiFiNetwork` | Guarda nueva red |
| `UpdateWiFiNetworkEvent(id, ssid, password, bssid?)` | `_onUpdateWiFiNetwork` | Actualiza red existente |
| `DeleteWiFiNetworkEvent(id)` | `_onDeleteWiFiNetwork` | Elimina red |
| `ScanNearbyNetworksEvent` | `_onScanNearbyNetworks` | Escanea redes ENTOMO cercanas |
| `BackToSavedNetworksEvent` | `_onBackToSavedNetworks` | Vuelve a lista guardada desde escaneo |
| `SaveAndConnectNearbyEvent` | `_onSaveAndConnectNearby` | Guarda una red escaneada |

**Escaneo de redes cercanas (`_onScanNearbyNetworks`):**

1. Carga las redes guardadas en paralelo
2. Verifica que el Wi-Fi esté activo con `WiFiForIoTPlugin.isEnabled()`
3. Obtiene SSID/BSSID de la red conectada actualmente
4. Llama `WiFiForIoTPlugin.loadWifiList()` (API deprecated pero funcional)
5. Filtra solo las redes cuyo SSID empieza por `ENTOMO` (case-insensitive)
6. Ordena por intensidad de señal descendente
7. Emite `WiFiNearbyLoaded` con redes cercanas + redes guardadas

**Estados posibles:**

| Estado | Cuándo | Datos |
|--------|--------|-------|
| `WiFiInitial` | Al crear el BLoC | — |
| `WiFiLoading` | Cargando lista | — |
| `WiFiLoadingMore` | Cargando siguiente página | Lista actual |
| `WiFiLoaded` | Carga exitosa | `networks`, `currentPage`, `totalCount`, `hasMorePages` |
| `WiFiError(message)` | Error en cualquier operación | Mensaje |
| `WiFiSaving` | Guardando/actualizando | — |
| `WiFiSaved(network)` | Guardado exitoso | Red guardada |
| `WiFiDeleting(id)` | Eliminando | id |
| `WiFiDeleted(id)` | Eliminado exitoso | id |
| `WiFiScanning` | Escaneando redes cercanas | — |
| `WiFiNearbyLoaded` | Escaneo terminado | Redes cercanas + guardadas + red conectada |
| `WiFiSavedFromNearby` | Red cercana guardada | Red + contexto del escaneo |

**Clase `NearbyWiFiNetwork`** (en `wifi_state.dart`):

```dart
class NearbyWiFiNetwork {
  final String ssid;
  final String bssid;
  final int signalStrength;   // RSSI en dBm (negativo)
  final bool isEntomo;

  int get signalPercentage  // convierte RSSI a porcentaje 0-100
  IconData get signalIcon   // icono según intensidad
}
```

### 5.8 Pantalla WiFiListPage

**Ruta:** `features/wifi/presentation/pages/wifi_list_page.dart`

Pantalla parametrizable que sirve para dos flujos:

```dart
class WiFiListPage extends StatefulWidget {
  final String pageTitle;       // título del AppBar
  final String connectLabel;    // texto del botón de conexión
  final String connectRoute;    // ruta de navegación tras conectar
}
```

**Valores por defecto** (flujo de descarga de archivos):
- `pageTitle = 'Mis Redes WiFi'`
- `connectLabel = 'Conectar a Trampa'`
- `connectRoute = '/files-list'`

**Valores para flujo de cámara** (configurados desde `main.dart`):
- `pageTitle = 'Stream'`
- `connectLabel = 'Conexión a cámara'`
- `connectRoute = '/camera-stream'`

**Funcionalidades:**

- Lista de redes guardadas con `WiFiListItem` (con deslizamiento para editar/eliminar)
- FAB para añadir red manualmente
- Botón de escaneo en AppBar para ver redes ENTOMO cercanas
- Paginación al llegar al final de la lista
- Diálogo `AddWiFiDialog` para crear/editar redes

**Widget `WiFiListItem`:**

Cada tarjeta de red muestra SSID, indicador de señal y dos acciones:
- Swipe derecho → editar
- Swipe izquierdo → eliminar
- Toque en botón → conectar (usando `WiFiConnectionService`)

Al conectar con éxito, navega a `widget.connectRoute` usando `Navigator.pushNamed`.

---

## 6. Feature: Files

Gestiona la obtención y descarga de archivos desde el dispositivo IoT.

### 6.1 Entidad FileEntity

**Ruta:** `features/files/domain/entities/file_entity.dart`

```dart
class FileEntity {
  final String name;   // nombre del archivo (ej: "trampa_001.jpg")
  final int size;      // tamaño en bytes
}
```

**Propiedades calculadas:**

| Getter | Descripción | Ejemplo |
|--------|-------------|---------|
| `sizeFormatted` | Tamaño legible | `"2.0 KB"`, `"1.5 MB"` |
| `extension` | Extensión en MAYÚSCULAS | `"JPG"`, `"JSON"` |
| `isImage` | Si es jpg/jpeg/png/gif/webp | `true` / `false` |
| `isJson` | Si la extensión es json | `true` / `false` |

Umbral de `sizeFormatted`: `< 1024` → B, `< 1 MB` → KB con 1 decimal, `>= 1 MB` → MB con 1 decimal.

### 6.2 Repositorio y DataSource

**Repositorio abstracto** (`files_repository.dart`):

```dart
abstract class FilesRepository {
  Future<List<FileEntity>> getFiles();
  Future<String> downloadFile(String fileName, Function(double) onProgress);
}
```

Nótese que este repositorio **no usa `Either`**: propaga excepciones directamente. El BLoC las captura con try-catch. Esta diferencia con el feature de WiFi es intencional: el feature de Files es más simple y los errores se gestionan en la capa de presentación.

**DataSource** (`FilesRemoteDataSourceImpl`):

Envuelve `ApiService` y lo adapta a la interfaz del dominio:

```dart
class FilesRemoteDataSourceImpl implements FilesRemoteDataSource {
  Future<List<FileEntity>> getFiles() async {
    final response = await _apiService.getFiles();
    if (!response.success) throw Exception(response.errorMessage);
    return response.data!.map((f) => FileModel.fromFileInfo(f)).toList();
  }

  Future<String> downloadFile(String fileName, Function(double) onProgress) async {
    final response = await _apiService.downloadFile(fileName: fileName, onProgress: onProgress);
    if (!response.success) throw Exception(response.errorMessage);
    return response.data!;
  }
}
```

**Modelo** (`FileModel`):

Extiende `FileEntity` y añade serialización JSON. Se construye a partir de `FileInfo` de `ApiService`.

### 6.3 Casos de uso

Ambos siguen el patrón más simple (sin `Either`, sin validaciones de negocio):

**`GetFiles`:** llama `repository.getFiles()` y devuelve la lista.

**`DownloadFile`:** llama `repository.downloadFile(fileName, onProgress)` y devuelve la ruta local.

### 6.4 FilesBloc

**Ruta:** `features/files/presentation/bloc/files_bloc.dart`

**Eventos:**

| Evento | Datos |
|--------|-------|
| `LoadFiles` | Sin datos |
| `DownloadFileEvent` | `String fileName` |

**Estados:**

| Estado | Datos | Cuándo |
|--------|-------|--------|
| `FilesInitial` | — | Estado inicial |
| `FilesLoading` | — | Cargando lista |
| `FilesLoaded` | `List<FileEntity> files` | Carga exitosa |
| `FilesError` | `String message` | Error al cargar |
| `FileDownloading` | `String fileName`, `double progress` | Descargando |
| `FileDownloaded` | `String filePath` | Descarga completada |
| `FileDownloadError` | `String message` | Error en descarga |

**Flujo de carga:**

```
LoadFiles → emit(FilesLoading) → getFiles() → emit(FilesLoaded) / emit(FilesError)
```

**Flujo de descarga:**

```
DownloadFileEvent → downloadFile(name, callback)
  callback(0.3) → emit(FileDownloading(name, 0.3))
  callback(1.0) → emit(FileDownloading(name, 1.0))
  resolve → emit(FileDownloaded(path))
  error → emit(FileDownloadError(message))
```

Los estados `FileDownloading` se emiten progresivamente a medida que el callback de Dio reporta el progreso. El BLoC los emite dentro del propio `downloadFile`, lo que significa que los widgets pueden mostrar una barra de progreso en tiempo real.

### 6.5 Pantalla FilesListScreen

**Ruta:** `features/files/presentation/pages/files_list_screen.dart`

Pantalla de tabla con los archivos del dispositivo IoT. Funcionalidades:

- **Carga automática** al entrar (dispara `LoadFiles`)
- **Pull to refresh** con `RefreshIndicator`
- **Modo selección múltiple** (botón de selección en AppBar)
- **Descarga individual** con tap en el botón de descarga
- **Descarga múltiple** en modo selección con barra de progreso por archivo
- **Previsualización** de imágenes JPG con `Image.file`
- **Previsualización** de JSON formateado con `JsonViewer`
- Gestión de errores de autenticación (navega a `/api-config` si detecta error 401/403)

---

## 7. Feature: Stream (cámara en tiempo real)

**Ruta:** `features/stream/presentation/pages/camera_stream_page.dart`

### Endpoints del servicio de stream

El servicio de stream corre en el puerto **8081** (diferente al API principal que usa el 80). La URL base se construye dinámicamente:

```dart
const int _kStreamPort = 8081;

String _buildStreamBase(String configuredBaseUrl) {
  final uri = Uri.parse(configuredBaseUrl);
  return uri.replace(port: _kStreamPort).toString();
}
```

Si la URL configurada es `http://192.168.100.10/api`, el resultado es `http://192.168.100.10:8081`.

| Endpoint | Uso |
|----------|-----|
| `GET $streamBase/stream` | Flujo MJPEG de la cámara |
| `GET $streamBase/stream/ping` | Heartbeat cada 10 s |
| `POST $streamBase/stream/close` | Liberar cámara en el IoT |
| `GET $streamBase/stream/health` | Estado del stream (para popup) |
| `GET $streamBase/health` | Estado general del dispositivo (para popup) |

### Parser MJPEG

MJPEG es un formato en el que el servidor envía JPEGs uno tras otro dentro de un stream HTTP continuo. La app los extrae buscando los marcadores binarios:

```
SOI (Start Of Image): bytes 0xFF 0xD8
EOI (End Of Image):   bytes 0xFF 0xD9
```

El stream llega como bytes crudos (`ResponseType.stream`) y se acumulan en un buffer `List<int>`. Cada vez que el buffer contiene un frame completo (SOI...EOI), se extrae con `Uint8List.fromList(buffer)` y se actualiza el widget `Image.memory`.

`Image.memory(frameBytes, gaplessPlayback: true)` — la opción `gaplessPlayback` evita el parpadeo entre frames al no mostrar el estado de carga entre actualizaciones.

### Gestión del ciclo de vida

La página implementa `WidgetsBindingObserver` para detectar cuándo el usuario sale de la app:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.detached) {
    _closeAndStop();
  }
}
```

**Método `_closeAndStop()`:** detiene el stream local y llama `POST /stream/close` para liberar la cámara en el IoT. Es crítico llamar este endpoint para que el dispositivo no quede "enganchado" a la app.

**Método `_stopInternals()`:** cancela el `CancelToken` de Dio (aborta la petición de stream), cancela el `Timer` de ping y el `Timer` de countdown.

**`dispose()`:** llama a `_stopInternals()` y a `_callClose()` (fire-and-forget) y elimina el observer del binding.

### Temporizador de 3 minutos

```dart
_sessionTimer = Timer(const Duration(minutes: 3), _onTimeout);
_countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
  setState(() => _remainingSeconds--);
});
```

El countdown se muestra en el AppBar en rojo cuando quedan ≤ 30 segundos. Al expirar, se muestra un diálogo con opción de reconectar o salir.

### Heartbeat

```dart
_pingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
  await _dio.get(_urlPing);
});
```

Sin el ping, el dispositivo IoT cierra el stream por inactividad.

### Popup de estado del dispositivo

El botón del corazón en el AppBar abre un diálogo que:

1. Muestra un indicador de carga
2. Hace dos peticiones en paralelo: `GET /health` y `GET /stream/health`
3. Muestra los datos de `/health` en tres secciones (stream/cámara oculto):

**GENERAL:**

| Etiqueta | JSON path |
|----------|-----------|
| Trampa | `last_cycle.id_trap` |
| Última Marca | `last_cycle.last_key` |
| Último Archivo | `last_cycle.last_run` |
| Hora Local | `time_local` |

**SENSORES:**

| Etiqueta | JSON path |
|----------|-----------|
| Batería | `sensors.battery.battery_pct` |
| Humedad | `sensors.dht22.hum_pct` |
| Temperatura Externa (°C) | `sensors.dht22.temp_c` |
| Temp. Interna (°C) | `sensors.ds18b20.temp_c` |

**OFFLINE:**

| Etiqueta | JSON path |
|----------|-----------|
| Imágenes | `offline_queue.jpg` |
| Json | `offline_queue.json` |

El método `_get(map, path)` navega el JSON anidado de forma segura (devuelve `null` si cualquier nodo falta, mostrado como `—`).

### Zoom interactivo

Implementado con `InteractiveViewer` que permite pellizco hasta 4× (`maxScale: 4.0`).

---

## 8. Feature: Upload

**Ruta:** `features/upload/presentation/pages/upload_page.dart`

Pantalla para subir los archivos JSON descargados del IoT al servidor de monitorización. A diferencia de los otros features, **no usa BLoC** — gestiona el estado con `StatefulWidget` directamente.

**Funcionalidades:**

- Lista los archivos JSON en el directorio local de la app
- Indica con icono si cada archivo ya ha sido sincronizado (comprobando el archivo `.synced`)
- Chips de resumen: Total / Sincronizados / Pendientes
- Modo selección múltiple con "Seleccionar todos"
- Barra de progreso durante la subida (overlay semi-transparente)
- Manejo de error de autenticación: si el servidor devuelve 401, pide credenciales
- Re-login automático si el token ha expirado

**Flujo de subida:**

```
1. Usuario selecciona archivos y pulsa "Subir"
2. Si no hay credenciales → mostrar diálogo de login
3. Para cada archivo seleccionado:
   a. SyncService.syncJson(appDirPath, fileName)
   b. Si éxito → refrescar estado (.synced aparece)
   c. Si error de auth → mostrar login
   d. Si otro error → mostrar SnackBar con mensaje
4. Ocultar overlay de progreso
```

---

## 9. Feature: Home

**Ruta:** `features/home/presentation/pages/home_page.dart`

Pantalla de bienvenida con tres botones principales. Usa `SingleChildScrollView` para que el contenido no se desborde en pantallas pequeñas.

**Tres botones (`_HeroButton`):**

| Icono | Título | Subtítulo | Gradiente | Ruta |
|-------|--------|-----------|-----------|------|
| `devices` | Conectar a trampa | "Descarga archivos via Wi-Fi de la trampa" | `primary → primaryDark` | `/wifi-list` |
| `cloud_upload` | Subir datos | "Envía registros al servidor de monitoreo" | `secondary → secondaryDark` | `/upload` |
| `videocam_rounded` | Ver cámara en tiempo real | "Conecta y visualiza el stream de la trampa" | `forest → brown` | `/camera-wifi` |

Pie de pantalla con versión y empresa obtenidas de `AppConstants`.

---

## 10. Pantallas de configuración

### ApiCheckScreen

**Ruta:** `features/files/presentation/pages/api_check_screen.dart`

Pantalla de puerta de entrada. Al abrirse, comprueba si hay API Key configurada:

- Si `ApiConfigService.hasApiKey()` → navega a `/files-list`
- Si no → navega a `/api-config`

Muestra un indicador de carga mientras verifica. El usuario normalmente no ve esta pantalla más de un instante.

### ApiConfigScreen

**Ruta:** `features/files/presentation/pages/api_config_screen.dart`

Formulario con dos campos principales:

| Campo | Validación | Storage |
|-------|-----------|---------|
| API Key | Mínimo 16 chars, solo alfanumérico | `ApiConfigService.saveApiKey` |
| URL Base | HTTP o HTTPS válida | `ApiConfigService.saveBaseUrl` |

Funciones adicionales:
- **Probar conexión:** hace `GET /files` con la configuración introducida antes de guardar
- **Credenciales de sincronización:** usuario y contraseña para el servidor de monitorización (`SyncService.saveCredentials`)
- **Cerrar sesión de sincronización:** `SyncService.clearCredentials()`

---

## 11. Flujos de datos completos

### Flujo: Descargar archivos del IoT

```
Usuario toca "Conectar a trampa" en Home
    ↓
Navega a /wifi-list (WiFiListPage con connectRoute='/files-list')
    ↓
WiFiBloc emite LoadWiFiNetworksEvent
    ↓
GetWiFiNetworks(params) → WiFiRepository → WiFiLocalDataSource → Hive
    ↓
WiFiBloc emite WiFiLoaded con lista de redes
    ↓
Usuario toca "Conectar" en una red
    ↓
WiFiConnectionService.connect(ssid, password)
    → PermissionService verifica permisos
    → wifi_iot conecta a la red
    → WifiNetworkClient.bindProcessToWifi()
    → WiFiReconnectService guarda la red
    ↓
Navega a /files-list (FilesListScreen)
    ↓
FilesBloc emite LoadFiles
    ↓
GetFiles() → FilesRepository → FilesRemoteDataSource → ApiService
    → WifiNetworkClient.ensureWifiBinding()
    → Dio GET /files
    ↓
FilesBloc emite FilesLoaded(files)
    ↓
Usuario toca "Descargar" en un archivo
    ↓
FilesBloc emite DownloadFileEvent('trampa_001.jpg')
    ↓
DownloadFile(name, onProgress) → FilesRepository → FilesRemoteDataSource → ApiService
    → Dio download /download?file=trampa_001.jpg
    → onProgress(0.3) → emit FileDownloading(name, 0.3)
    → onProgress(1.0) → emit FileDownloading(name, 1.0)
    ↓
FilesBloc emite FileDownloaded('/storage/.../trampa_001.jpg')
```

### Flujo: Subir JSON al servidor

```
Usuario toca "Subir datos" en Home
    ↓
Navega a /upload (UploadPage)
    ↓
UploadPage lista JSONs en directorio local
SyncService.loadSyncedFiles() marca los ya subidos
    ↓
Usuario selecciona archivos y toca "Subir"
    ↓
Si no hay credenciales → diálogo de login → SyncService.login()
    ↓
Para cada archivo:
    SyncService.syncJson(appDirPath, fileName)
        → WifiNetworkClient.runWithInternet(() →
            → unbindNetwork()
            → Dio POST /web/monitorizacion o /web/monitorizacion/medicion
            → bindProcessToWifi()  ← siempre en finally
        )
        → SyncService.markAsSynced() crea archivo .synced
    ↓
Pantalla refresca estados
```

---

## 12. Pruebas unitarias

**Directorio:** `test/`

**Stack:** `flutter_test` + `mockito` + `bloc_test`

### Estructura de tests

```
test/
├── features/
│   ├── files/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── file_entity_test.dart          (17 tests)
│   │   │   └── usecases/
│   │   │       ├── get_files_test.dart             (3 tests)
│   │   │       └── download_file_test.dart         (3 tests)
│   │   └── presentation/bloc/
│   │       └── files_bloc_test.dart               (5 tests)
│   └── wifi/
│       ├── data/datasources/
│       │   └── wifi_local_datasource_test.dart    (13 tests)
│       ├── domain/usecases/
│       │   ├── get_wifi_networks_test.dart        (5 tests)
│       │   └── save_wifi_network_test.dart        (8 tests)
│       └── presentation/bloc/
│           └── wifi_bloc_test.dart               (6 tests)
└── widget_test.dart                              (stale — no ejecutar)
```

**Total: 60 tests unitarios**

### Patrón de mocks

Todos los tests usan el patrón de generación de mocks de `mockito`:

```dart
@GenerateMocks([ClaseAMockear])
void main() { ... }
```

El archivo `.mocks.dart` se genera con:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Descripción de cada suite

#### `file_entity_test.dart` — 17 tests

Prueba pura sin mocks. Verifica los getters calculados de `FileEntity`:

- `sizeFormatted`: bytes (`< 1024`), KB (`< 1 MB`), MB (`>= 1 MB`), redondeo a 1 decimal
- `extension`: mayúsculas, múltiples puntos, sin extensión → `DESCONOCIDO`
- `isImage`: verifica los 5 formatos (jpg, jpeg, png, gif, webp), y que JSON/TXT dan `false`
- `isJson`: solo `.json` es `true`

#### `get_files_test.dart` — 3 tests

Mock de `FilesRepository`. Cubre:
- Retorno exitoso de lista de archivos
- Retorno de lista vacía
- Propagación de excepción cuando el repositorio falla

#### `download_file_test.dart` — 3 tests

Mock de `FilesRepository`. Cubre:
- Retorno de la ruta local del archivo
- Invocación del callback de progreso con los valores correctos (se stubea el repositorio para que llame `onProgress(0.25)`, `onProgress(0.75)`, `onProgress(1.0)`)
- Propagación de excepción

#### `files_bloc_test.dart` — 5 tests (bloc_test)

Mocks de `GetFiles` y `DownloadFile`. Usa `blocTest<FilesBloc, FilesState>`:

```dart
blocTest<FilesBloc, FilesState>(
  'emite [FilesLoading, FilesLoaded] cuando la carga es exitosa',
  build: () { when(mockGetFiles()).thenAnswer((_) async => tFiles); return bloc; },
  act: (bloc) => bloc.add(LoadFiles()),
  expect: () => [FilesLoading(), FilesLoaded(tFiles)],
);
```

Para la descarga, el mock del use case invoca el callback:

```dart
when(mockDownloadFile(any, any)).thenAnswer((invocation) async {
  final callback = invocation.positionalArguments[1] as Function(double);
  callback(0.5);
  callback(1.0);
  return tFilePath;
});
```

#### `wifi_local_datasource_test.dart` — 13 tests

Mocks de `HiveInterface` y `Box<WiFiNetworkModel>`. Cubre operaciones CRUD con Hive, paginación correcta, manejo de errores (lanza `CacheException`, `ValidationException`, `NotFoundException`).

#### `get_wifi_networks_test.dart` — 5 tests

Mock de `WiFiRepository`. Cubre:
- Obtención correcta delegando al repositorio
- `ValidationFailure` cuando `page < 1`
- `ValidationFailure` cuando `pageSize < 1`
- `ValidationFailure` cuando `pageSize > 100`
- `CacheFailure` cuando el repositorio falla

#### `save_wifi_network_test.dart` — 8 tests

Cubre validaciones de SSID (vacío, solo espacios, mayor de 32 chars) y contraseña (vacía, menor de 8, mayor de 63). También verifica que el SSID se guarda con `trim()`.

#### `wifi_bloc_test.dart` — 6 tests

Mocks de los 5 use cases. Cubre estados de carga, error, guardado, borrado y paginación (`hasMorePages`).

---

## 13. Guía de desarrollo

### Requisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Flutter SDK | 3.x |
| Dart | 3.0.0 |
| Android Studio / VS Code | Última estable |
| Android SDK | API 23 (Android 6.0) |

### Configuración inicial

```bash
# 1. Clonar el repositorio
git clone <url>
cd ecotrap

# 2. Instalar dependencias
flutter pub get

# 3. Generar código (adaptadores Hive + mocks de test)
dart run build_runner build --delete-conflicting-outputs

# 4. Verificar que todo compila
flutter analyze

# 5. Ejecutar tests
flutter test test/features/

# 6. Lanzar en dispositivo/emulador
flutter run
```

### Añadir un nuevo feature

Sigue este orden para mantener Clean Architecture:

1. **Entidad** en `domain/entities/`
2. **Repositorio abstracto** en `domain/repositories/`
3. **Caso(s) de uso** en `domain/usecases/`
4. **Modelo** en `data/models/` (extiende la entidad)
5. **DataSource** (interfaz + implementación) en `data/datasources/`
6. **Implementación del repositorio** en `data/repositories/`
7. **BLoC** (event + state + bloc) en `presentation/bloc/`
8. **Pantalla(s)** en `presentation/pages/`
9. **Registrar en GetIt** en `core/di/injection.dart`
10. **Añadir ruta** en `main.dart`
11. **Escribir tests** siguiendo el patrón existente

### Regenerar mocks tras cambios en interfaces

Cada vez que cambies la firma de una clase que está siendo mockeada, regenera:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Actualizar la versión

1. Cambiar `version:` en `pubspec.yaml`
2. Cambiar `AppConstants.version` en `core/utils/app_constants.dart`
3. Actualizar el badge en `README.md`

### Convención de commits

```
feat: descripción      ← nueva funcionalidad
fix: descripción       ← corrección de bug
refactor: descripción  ← cambio sin impacto funcional
test: descripción      ← añadir o corregir tests
docs: descripción      ← cambios en documentación
chore: descripción     ← mantenimiento, dependencias
```

### Consideraciones de seguridad

- **Nunca** commitear claves API en el código fuente
- Toda la configuración sensible usa `flutter_secure_storage` con `AndroidOptions(encryptedSharedPreferences: true)`
- El token de sesión del servidor se almacena cifrado y se elimina al expirar
- La cabecera `x-api-key` solo se incluye si la API Key está configurada

---

*Documentación generada para EcoTrap v2.9.1 — EntomoLab*
