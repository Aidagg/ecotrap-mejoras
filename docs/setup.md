# Guía de configuración — EcoTrap

## Requisitos previos

| Herramienta | Versión mínima | Notas |
|-------------|---------------|-------|
| Flutter SDK | 3.x | `sdk: '>=3.0.0 <4.0.0'` en pubspec |
| Dart | 3.0.0 | Incluido con Flutter |
| VS Code | Última estable | Con extensiones Flutter y Dart |
| Android Studio | Última estable | Para emulador y Android SDK |
| Xcode | 14+ | Solo macOS, para builds iOS |

La app requiere **Android 12 (API 31) mínimo** en tiempo de ejecución por los permisos Wi-Fi.

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone git@github.com:entomolab-es/EcotrapIOT.git
cd EcotrapIOT
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Generar código

Este paso es **obligatorio**. Genera los adaptadores Hive (`WiFiNetworkModel`) y los mocks de test. Sin ejecutarlo, la app no compila y los tests fallan.

```bash
dart run build_runner build --delete-conflicting-outputs
```

Ejecutar de nuevo cada vez que se modifique:
- Un modelo con `@HiveType` o `@HiveField`
- Una clase anotada con `@GenerateMocks` en los tests

### 4. Ejecutar los tests

```bash
flutter test test/features/
```

### 5. Ejecutar la app

```bash
flutter run
```

---

## Configuración en la app

Al primer inicio, la app pide configurar dos conjuntos de credenciales desde `ApiConfigScreen` (accesible via el icono ⚙️ en la pantalla principal):

**API Key + URL Base (comunicación con el dispositivo IoT)**
- Ir a *Configurar API* en la app
- Ingresar la API Key del dispositivo IoT (alfanumérica, mínimo 16 caracteres)
- La URL base por defecto es `http://192.168.100.10/api`

**Usuario + contraseña (sincronización con backend EntomoLab)**
- En la misma pantalla, sección *Credenciales de sincronización*
- Usar el botón *Probar conexión* para verificar antes de guardar

Todas las credenciales se almacenan cifradas en `flutter_secure_storage` con `encryptedSharedPreferences: true` en Android.

---

## Builds de producción

### Android

```bash
# APK
flutter build apk --release

# App Bundle (recomendado para Play Store)
flutter build appbundle --release
```

Requiere `android/key.properties` configurado (ver sección Firma Android).

### iOS

```bash
flutter build ios --release
```

Requiere macOS con Xcode y cuenta de Apple Developer.

---

## Firma Android

Crear `android/key.properties` (no se versiona, está en `.gitignore`):

```properties
storePassword=TU_CONTRASEÑA_KEYSTORE
keyPassword=TU_CONTRASEÑA_CLAVE
keyAlias=TU_ALIAS
storeFile=RUTA/A/TU/keystore.jks
```

---

## Permisos requeridos

La app gestiona permisos automáticamente via `PermissionService` con diálogos contextuales.

| Permiso | Android | Uso |
|---------|---------|-----|
| `ACCESS_FINE_LOCATION` | 12 (SDK 31-32) | Requerido por Android para escáner Wi-Fi |
| `ACCESS_BACKGROUND_LOCATION` | 12 (SDK 31-32) | Mantener conexión Wi-Fi estable |
| `NEARBY_WIFI_DEVICES` | 13+ (SDK 33+) | Reemplaza ubicación para Wi-Fi en Android 13+ |
| `NSLocationWhenInUseUsageDescription` | iOS | Escaneo de redes Wi-Fi |

Android < 12 no está soportado.

---

## Solución de problemas

### `build_runner` falla con conflictos

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### La app no puede conectar al dispositivo IoT

En Android con datos móviles activos, el sistema puede redirigir el tráfico fuera del Wi-Fi. La app gestiona esto automáticamente via `WifiNetworkClient`. Si persiste: desactivar datos móviles temporalmente.

### Error de permisos Wi-Fi en Android 13+

El permiso `NEARBY_WIFI_DEVICES` puede no estar disponible en algunas ROMs. La app hace fallback automático a `locationWhenInUse`.

### CocoaPods (iOS)

```bash
cd ios
pod install
cd ..
flutter run
```

### `flutter doctor` — Android licenses

```bash
flutter doctor --android-licenses
```
