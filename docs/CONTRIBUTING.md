# Guía de contribución — EcoTrap

---

## Flujo de trabajo Git

### Ramas

| Rama | Propósito |
|------|-----------|
| `main` | Código estable. Siempre funcional. |
| `develop` | Integración. Features van aquí antes de `main`. |

### Nomenclatura de ramas

```
feat/nombre-funcionalidad
fix/descripcion-bug
docs/que-documentacion
refactor/que-se-refactoriza
chore/tarea-mantenimiento
```

### Flujo

```bash
git checkout develop
git pull origin develop
git checkout -b feat/mi-funcionalidad

# trabajar...
git add .
git commit -m "feat: descripción"
git push origin feat/mi-funcionalidad
# → abrir Pull Request hacia develop
```

---

## Convención de commits (Conventional Commits)

```
<tipo>(<scope opcional>): <descripción en minúsculas>
```

| Tipo | Uso |
|------|-----|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `docs` | Cambios en documentación |
| `refactor` | Refactorización sin cambio funcional |
| `test` | Tests |
| `chore` | Dependencias, mantenimiento |
| `style` | Formato sin cambio lógico |

**Ejemplos correctos:**
```bash
git commit -m "feat(wifi): añadir soporte para redes ocultas"
git commit -m "fix(stream): corregir parser MJPEG en frames grandes"
git commit -m "docs: actualizar setup.md con paso build_runner"
git commit -m "chore: actualizar flutter_bloc a 8.1.4"
```

**Incorrectos:**
```bash
git commit -m "cambios"
git commit -m "Fix bug"
git commit -m "wip"
```

---

## Estructura de una nueva feature

Respetar siempre la estructura de Clean Architecture:

```
lib/features/nueva_feature/
├── data/
│   ├── datasources/nueva_feature_datasource.dart
│   ├── models/nueva_feature_model.dart
│   └── repositories/nueva_feature_repository_impl.dart
├── domain/
│   ├── entities/nueva_feature_entity.dart
│   ├── repositories/nueva_feature_repository.dart
│   └── usecases/get_nueva_feature.dart
└── presentation/
    ├── bloc/
    │   ├── nueva_feature_bloc.dart
    │   ├── nueva_feature_event.dart
    │   └── nueva_feature_state.dart
    ├── pages/nueva_feature_page.dart
    └── widgets/nueva_feature_widget.dart
```

Registrar en `core/di/injection.dart` en el orden: datasource → repository → use cases → BLoC.

---

## Reglas específicas del proyecto

**Modelos Hive**: al añadir un campo `@HiveField`, usar el siguiente índice libre (actualmente ≥ 6 para `WiFiNetworkModel`). Nunca reutilizar índices eliminados. Siempre ejecutar `build_runner` después.

**Secure storage**: respetar los tres namespaces existentes y no crear claves fuera de ellos sin documentarlo.

**Wi-Fi binding**: cualquier petición HTTP al dispositivo IoT debe llamar primero a `WifiNetworkClient.ensureWifiBinding()`. Ver `ApiService._getDio()` como referencia.

**Errores**: usar `Either<Failure, T>` en use cases y repositorios. Las exceptions de la capa de datos se convierten en failures en `WiFiRepositoryImpl` o `FilesRepositoryImpl`. Nunca dejar `catch (e)` sin convertir a `UnexpectedFailure`.

---

## Tests

### Patrón de tests existente

Los tests usan `mockito` con generación de código. Cada archivo de test sigue este esquema:

```dart
@GenerateMocks([ClaseAMockear])
void main() {
  late MockClaseAMockear mockObj;
  late Sujeto sujeto;

  setUp(() {
    mockObj = MockClaseAMockear();
    sujeto = Sujeto(mockObj);
  });

  group('NombreGrupo', () {
    test('debe hacer X cuando Y', () async {
      // Arrange
      when(mockObj.metodo()).thenAnswer((_) async => resultado);
      // Act
      final result = await sujeto.metodo();
      // Assert
      expect(result, resultado);
      verify(mockObj.metodo());
    });
  });
}
```

Para BLoCs usar `blocTest<BLoC, State>` de `bloc_test`.

### Regenerar mocks tras cambiar interfaces

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Cobertura actual

| Feature | Tests |
|---------|------:|
| wifi (data + domain + presentation) | 32 |
| files (domain + presentation) | 28 |
| **Total** | **60** |

---

## Checklist antes de abrir Pull Request

- [ ] `flutter analyze` sin warnings
- [ ] `flutter test test/features/` pasa (60/60)
- [ ] `build_runner` ejecutado si se modificaron modelos Hive o `@GenerateMocks`
- [ ] `CHANGELOG.md` actualizado en la sección `[En desarrollo]`
- [ ] Commits siguen Conventional Commits
- [ ] `docs/features.md` actualizado si se añadió o modificó un feature

---

## Configuración de VS Code recomendada

Crear `.vscode/settings.json` (no se versiona):

```json
{
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code"
  }
}
```
