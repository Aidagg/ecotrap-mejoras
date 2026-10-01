# EcoTrap

**Aplicación móvil de campo para monitoreo y control de trampas fitosanitarias IoT**

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)
![Version](https://img.shields.io/badge/Versión-2.9.1-006633)
![Android](https://img.shields.io/badge/Android-API%2023+-3DDC84?logo=android&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-60%20pasando-brightgreen)
![License](https://img.shields.io/badge/Licencia-Privada-red)

---

## Descripción

**EcoTrap** es la aplicación móvil oficial de **EntomoLab** para la gestión de trampas fitosanitarias inteligentes. Permite al técnico de campo conectarse directamente al dispositivo IoT vía Wi-Fi, descargar los registros generados por la trampa, visualizar la cámara en tiempo real y subir los datos al servidor central cuando hay conexión disponible.

El flujo principal es completamente **offline-first**: la app trabaja en la red local del dispositivo IoT sin necesidad de internet, y sincroniza con el servidor backend cuando el técnico regresa a zona con conectividad.

---

## Funcionalidades

### Conexión al dispositivo IoT
- Guarda y gestiona redes Wi-Fi de trampas con contraseña cifrada (Hive + EncryptedSharedPreferences)
- Escanea redes ENTOMOLAB cercanas y las guarda con un solo toque
- Se vincula automáticamente al proceso Android para forzar el tráfico HTTP por la red local del dispositivo (`ConnectivityManager.bindProcessToNetwork`)
- Reconexión automática a la última red conocida en sesiones posteriores

### Descarga de archivos
- Lista los archivos disponibles en el dispositivo IoT (`GET /api/files`)
- Descarga archivos individuales o en selección múltiple a la carpeta local del móvil
- Visualizador integrado de imágenes JPG y archivos JSON
- Indicadores de progreso por archivo y por lote

### Stream de cámara en tiempo real
- Stream MJPEG directo desde el dispositivo IoT (`GET /api/stream`, puerto 8081)
- Parser de frames JPEG por marcadores SOI/EOI sin dependencias externas
- Ping automático cada 10 s para mantener la cámara activa (`GET /api/stream/ping`)
- Llamada explícita a `POST /api/stream/close` al salir, para liberar la cámara en el IoT
- Cierre automático y liberación de la cámara tras **3 minutos** de transmisión continua
- Desconexión segura ante cualquier cambio de ciclo de vida (pausa, minimizado, cierre)
- Zoom interactivo hasta 4×

### Estado del dispositivo
- Popup de salud con datos de `GET /api/health` (puerto 8081)
- Tres secciones: **General** (trampa, marca, archivo, hora), **Sensores** (batería, temperatura, humedad) y **Offline** (imágenes y JSON pendientes)

### Subida de datos
- Lista los archivos JSON generados en el dispositivo móvil
- Subida individual o masiva al servidor central con barra de progreso
- Marca los archivos ya sincronizados para evitar duplicados

### Configuración
- API Key cifrada con `flutter_secure_storage` + `EncryptedSharedPreferences`
- URL base configurable (por defecto: `http://192.168.100.10/api`)
- Prueba de conexión integrada antes de guardar
- Gestión de carpeta de almacenamiento local

---

## Endpoints del dispositivo IoT

La app se comunica con el dispositivo en dos puertos:

| Puerto | Servicio |
|--------|----------|
| `80`   | API principal (archivos, configuración, salud general) |
| `8081` | Servicio de stream (cámara, ping, health de cámara) |

| Método | Endpoint | Uso en la app |
|--------|----------|---------------|
| `GET` | `/api/files` | Listar archivos disponibles |
| `GET` | `/api/files/{name}` | Descargar archivo |
| `GET` | `/api/health` | Estado general del dispositivo |
| `GET` | `/api/stream` | Stream MJPEG de la cámara |
| `GET` | `/api/stream/ping` | Heartbeat para mantener cámara activa |
| `POST` | `/api/stream/close` | Liberar cámara al desconectar |
| `GET` | `/api/stream/health` | Estado del stream y cámara |

Todos los endpoints requieren la cabecera `X-API-Key: <api_key>`.

---

## Arquitectura

El proyecto sigue **Clean Architecture** con separación estricta en tres capas por feature:

```
lib/
├── core/
│   ├── di/                      # Inyección de dependencias (GetIt)
│   ├── errors/                  # Excepciones y failures tipados
│   ├── network/                 # Servicios HTTP, WiFi, sync, config
│   ├── services/                # Permisos, conexión WiFi nativa
│   ├── usecases/                # Contrato base UseCase
│   └── utils/                   # AppColors, AppConstants
│
└── features/
    ├── files/                   # Descarga y visualización de archivos
    │   ├── data/                # Datasource, modelo, repositorio impl
    │   ├── domain/              # Entidad, repositorio, casos de uso
    │   └── presentation/        # BLoC, páginas, widgets
    ├── home/                    # Pantalla principal de navegación
    ├── stream/                  # Cámara en tiempo real (MJPEG)
    │   └── presentation/
    │       └── pages/           # CameraStreamPage
    ├── upload/                  # Subida de JSON al servidor
    └── wifi/                    # Gestión de redes Wi-Fi
        ├── data/
        ├── domain/
        └── presentation/        # BLoC, páginas, widgets
```

**Gestión de estado:** BLoC + Equatable  
**Inyección de dependencias:** GetIt  
**Almacenamiento local:** Hive (NoSQL embebido, cifrado)  
**Almacenamiento seguro:** flutter_secure_storage + EncryptedSharedPreferences  
**Programación funcional:** Dartz (Either para manejo de errores)

---

## Stack tecnológico

| Categoría | Paquete | Versión |
|-----------|---------|---------|
| Framework | Flutter | ≥ 3.x |
| Lenguaje | Dart | ≥ 3.0.0 |
| Estado | flutter_bloc + equatable | ^8.1.3 |
| Inyección de dependencias | get_it | ^7.6.4 |
| Base de datos local | hive + hive_flutter | ^2.2.3 |
| HTTP client | dio | ^5.4.0 |
| Almacenamiento seguro | flutter_secure_storage | ^9.0.0 |
| Preferencias | shared_preferences | ^2.2.0 |
| Conexión Wi-Fi | wifi_iot | ^0.3.18 |
| Conectividad | connectivity_plus | ^6.0.3 |
| Permisos | permission_handler | ^11.3.1 |
| Info del dispositivo | device_info_plus | ^10.1.0 |
| Archivos | file_picker + path_provider | ^8.0.3 |
| UI extra | flutter_slidable + cupertino_icons | ^3.0.1 |
| Utilidades | uuid + dartz | ^4.2.2 |

---

## Instalación

### Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.0.0`
- Dart `>=3.0.0 <4.0.0`
- Android Studio con Android SDK (API 23+)
- VS Code con extensiones **Flutter** y **Dart** (recomendado)

### Pasos

```bash
# 1. Clonar el repositorio
git clone <url-del-repositorio>
cd ecotrap

# 2. Instalar dependencias
flutter pub get

# 3. Generar adaptadores Hive y mocks de test
dart run build_runner build --delete-conflicting-outputs

# 4. Ejecutar en modo desarrollo
flutter run

# 5. Build release Android
flutter build apk --release
```

---

## Configuración inicial en la app

1. Abrir la app → icono de ajustes en la pantalla principal
2. Introducir la **API Key** del dispositivo IoT
3. (Opcional) Cambiar la **URL base** si la IP del dispositivo es diferente a `192.168.100.10`
4. Pulsar **Guardar** — la configuración queda cifrada en el dispositivo

---

## Plataformas soportadas

| Plataforma | Estado | Versión mínima |
|------------|--------|----------------|
| Android | Soportado | Android 6.0 (API 23) |
| iOS | No probado | — |

> El soporte Android incluye manejo nativo de binding de red vía `ConnectivityManager` para garantizar que las peticiones HTTP vayan por la red Wi-Fi de la trampa y no por la red móvil del operador.

---

## Testing

```bash
# Generar mocks (obligatorio antes de la primera ejecución)
dart run build_runner build --delete-conflicting-outputs

# Ejecutar todos los tests unitarios
flutter test

# Con informe de cobertura
flutter test --coverage

# Test de un feature específico
flutter test test/features/wifi/
flutter test test/features/files/
```

Stack: `flutter_test` + `mockito` + `bloc_test`

### Cobertura actual — 60 tests unitarios

#### Feature: files

| Archivo de test | Tests | Qué cubre |
|-----------------|------:|-----------|
| `domain/entities/file_entity_test.dart` | 17 | `sizeFormatted`, `extension`, `isImage`, `isJson` |
| `domain/usecases/get_files_test.dart` | 3 | `GetFiles` — lista, vacía, excepción |
| `domain/usecases/download_file_test.dart` | 3 | `DownloadFile` — ruta, callback de progreso, excepción |
| `presentation/bloc/files_bloc_test.dart` | 5 | `FilesBloc` — `LoadFiles` y `DownloadFileEvent` |
| **Subtotal** | **28** | |

#### Feature: wifi

| Archivo de test | Tests | Qué cubre |
|-----------------|------:|-----------|
| `data/datasources/wifi_local_datasource_test.dart` | 13 | CRUD Hive, paginación, excepciones tipadas |
| `domain/usecases/get_wifi_networks_test.dart` | 5 | `GetWiFiNetworks` — paginación, validaciones |
| `domain/usecases/save_wifi_network_test.dart` | 8 | `SaveWiFiNetwork` — validaciones SSID/contraseña |
| `presentation/bloc/wifi_bloc_test.dart` | 6 | `WiFiBloc` — carga, guardado, borrado |
| **Subtotal** | **32** | |

---

## Paleta de colores corporativa

| Token | Hex | Uso |
|-------|-----|-----|
| `primary` | `#006633` | Color principal, AppBar, botones |
| `secondary` | `#3AAA35` | Éxito, FAB, confirmaciones |
| `forest` | `#597D60` | Textos secundarios, bordes suaves |
| `olive` | `#949644` | Acentos informativos |
| `golden` | `#E3B947` | Advertencias |
| `burnt` | `#D45219` | Errores, desconexión |
| `brown` | `#63442B` | Botón acceso cámara |

---

## Rutas de navegación

| Ruta | Pantalla |
|------|----------|
| `/splash` | Splash screen con logo EntomoLab |
| `/home` | Panel principal |
| `/wifi-list` | Redes Wi-Fi — acceso a descarga de archivos |
| `/camera-wifi` | Redes Wi-Fi — acceso a stream de cámara |
| `/camera-stream` | Stream MJPEG en tiempo real |
| `/files-list` | Lista y descarga de archivos del IoT |
| `/upload` | Subida de archivos JSON al servidor |
| `/api-config` | Configuración de API Key y URL base |
| `/api-check` | Verificación de configuración |

---

## Convención de commits

| Prefijo | Uso |
|---------|-----|
| `feat:` | Nueva funcionalidad |
| `fix:` | Corrección de bug |
| `docs:` | Cambios en documentación |
| `refactor:` | Refactorización sin cambio funcional |
| `test:` | Añadir o corregir tests |
| `chore:` | Tareas de mantenimiento |

---

## Licencia

Proyecto **privado y confidencial** — EntomoLab.  
Todos los derechos reservados. Prohibida su distribución o uso sin autorización expresa.

---

*EcoTrap v2.9.1 — EntomoLab · Flutter · Clean Architecture · Offline-First*
