# 🧠 QuizDaily+

**App Android de microaprendizaje diario.** Cargás preguntas a mano o las generás con IA a partir de tus apuntes, y la app te propone un quiz corto cada día, con meta diaria, racha y estadísticas.

![Version](https://img.shields.io/badge/version-1.0.0-red?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.35+-02569B?style=flat-square&logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/plataforma-Android-3DDC84?style=flat-square&logo=android&logoColor=white)

Proyecto personal. No está publicado en ninguna tienda.

| Inicio | Quiz diario | Generador con IA |
|:---:|:---:|:---:|
| <img src="docs/screenshots/inicio.jpeg" width="220" alt="Inicio con el progreso del día (7 de 10) y una racha de 6 días" /> | <img src="docs/screenshots/quiz.jpeg" width="220" alt="Pregunta del quiz diario con cuatro opciones" /> | <img src="docs/screenshots/generador-ia.jpeg" width="220" alt="Generador con IA con la categoría y el texto de los apuntes" /> |
| **Banco de preguntas** (modo oscuro) | **Progreso** (modo oscuro) | **Configuración** (modo oscuro) |
| <img src="docs/screenshots/banco-oscuro.jpeg" width="220" alt="Banco de preguntas con búsqueda, filtros por materia y botón para borrar" /> | <img src="docs/screenshots/progreso-oscuro.jpeg" width="220" alt="Estadísticas: racha, total, precisión, gráfico semanal y precisión por materia" /> | <img src="docs/screenshots/configuracion-oscuro.jpeg" width="220" alt="Configuración con modo oscuro, recordatorio diario y respaldo" /> |

<sub>Capturas de un emulador Android con datos de ejemplo.</sub>

---

## Funcionalidades

- **Quiz diario** con meta configurable (preguntas por día) y racha de días seguidos.
- **Repaso inteligente:** las preguntas que fallás aparecen más seguido hasta que las acertás.
- **Modo examen:** prioriza una materia hasta la fecha del parcial.
- **Generación con IA (Gemini):** a partir de texto, un PDF o una imagen genera 5 preguntas de opción múltiple con explicación. Se pueden revisar y editar antes de guardarlas.
- **Banco de preguntas** con búsqueda, filtro por materia y filtro de "difíciles". Carga manual con imagen opcional, edición y borrado (con "Deshacer").
- **Estadísticas:** precisión global y por materia, gráfico de la semana y logros.
- **Recordatorio diario** con notificación local a la hora elegida.
- **Respaldo y restauración** en un archivo JSON que se puede compartir.
- **Modo claro y oscuro.**
- Todo se guarda en el teléfono con Hive: la app funciona sin conexión, salvo el generador con IA.

## Stack

| Área | Tecnología |
|---|---|
| App | Flutter 3.35+ / Dart 3.9 |
| Persistencia local | Hive + `hive_generator` (adapters generados con `build_runner`) |
| Estado | `provider` (repositorios como `ChangeNotifier`) |
| IA | Gemini 2.5 Flash con `google_generative_ai` |
| Notificaciones | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| UI | Material 3, `fl_chart`, `google_fonts` |
| Archivos | `file_picker`, `image_picker`, `share_plus`, `path_provider` |

## Arquitectura

```
lib/
├── main.dart                  # Arranque: abre Hive, crea los repositorios y los comparte con Provider
├── models/                    # Question, UserProgress, DailyStats (+ adapters *.g.dart generados)
├── data/
│   ├── question_repository.dart   # Preguntas: alta, edición, borrado/deshacer, respuestas
│   └── progress_repository.dart   # Meta, racha, cambio de día, preferencias e historial diario
├── screens/                   # Una pantalla por archivo
├── services/
│   ├── storage_service.dart       # Abre las cajas de Hive (nombres en HiveBoxes) y maneja errores
│   ├── gemini_service.dart        # Prompt, esquema JSON y validación de la respuesta de la IA
│   ├── notification_service.dart  # Recordatorio diario en la zona horaria del dispositivo
│   ├── data_sync_service.dart     # Exporta el respaldo JSON
│   └── import_service.dart        # Importa respaldos (formato viejo y nuevo)
├── widgets/day_rollover_on_resume.dart  # Recalcula el día cuando la app vuelve del segundo plano
└── theme/app_colors.dart      # Paleta de colores
test/
├── data/                      # Repositorios (Hive en una carpeta temporal)
├── services/                  # Importación y validación de Gemini
└── screens/                   # Widgets del quiz, el banco y el cambio de día
```

- **Screens:** widgets de Flutter. No tocan Hive: leen los repositorios con `context.watch` / `context.select` y escriben con `context.read`.
- **Data (repositorios):** son el único acceso a Hive y extienden `ChangeNotifier`. Escuchan su caja con `box.watch()`, así que cualquier cambio (una respuesta, una importación) redibuja las pantallas que lo usan. La lógica de racha y cambio de día vive en `ProgressRepository`.
- **Services:** integraciones y tareas puntuales: Gemini, notificaciones, respaldo y apertura de Hive.
- **Models + Hive:** tres cajas.
  - `questionsBox`: las preguntas (`Question`).
  - `progressBox`: un único `UserProgress` con meta, racha y preferencias.
  - `statsBox`: un `DailyStats` por día, con respondidas y acertadas.

  Los campos que se agregaron después de la primera versión tienen `defaultValue` para poder leer datos viejos. Si Hive no puede abrir una caja, la app no borra nada: muestra una pantalla para reintentar o restablecer solo esa caja, y antes guarda una copia de los archivos.

Después de cambiar un modelo, regenerar los adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Cómo correrlo

Requisitos: Flutter 3.35 o superior (probado con 3.44) y un emulador o teléfono Android.

```bash
git clone https://github.com/JuanEspinoza8/app_quiz.git
cd app_quiz
flutter pub get
```

### API key de Gemini

La generación con IA usa una API key de [Google AI Studio](https://aistudio.google.com/apikey). La clave no está en el código: se pasa al compilar con `--dart-define`.

```bash
cp env.example.json env.json   # env.json está en .gitignore
# editar env.json y completar GEMINI_API_KEY
flutter run --dart-define-from-file=env.json
```

Sin la clave, la app funciona igual, pero el generador con IA muestra un error que avisa que falta configurarla.

> **Importante:** en una app cliente, cualquier valor que viaja en el APK (incluido un `--dart-define`) se puede extraer descompilándolo. `--dart-define` sirve para no subir la clave al repo, no para ocultarla. Por eso conviene restringirla en Google Cloud Console → *Credenciales*:
>
> - **Restricción de API:** solo *Generative Language API*. Funciona sin cambios en la app.
> - **Restricción de aplicación Android** (nombre de paquete `io.github.juanespinoza8.quizdaily` + huella SHA-1 del certificado de firma). Google valida esta restricción con los headers `X-Android-Package` y `X-Android-Cert`, que el SDK de Dart no envía solo. La app los agrega si se define `ANDROID_CERT_SHA1` en `env.json` (y `ANDROID_PACKAGE` si cambia el `applicationId`):
>
>   ```json
>   { "GEMINI_API_KEY": "...", "ANDROID_CERT_SHA1": "AA:BB:CC:..." }
>   ```
>
>   La huella sale de `cd android && ./gradlew signingReport`. Sin estos valores, una clave restringida a Android responde 403.
>
> Ninguna de las dos impide que alguien con el APK reutilice la clave: la protección real es un backend propio (o Firebase App Check) entre la app y Gemini.

## Tests

```bash
flutter analyze
flutter test
```

- **Repositorios:** cambio de día, racha consecutiva y rota, meta cumplida, historial diario, preferencias, borrado y deshacer.
- **Servicios:** importación de respaldos (formato viejo y nuevo, duplicados) y validación de las respuestas de Gemini.
- **Widgets:** el quiz se desbloquea al día siguiente de cumplir la meta, responder suma al progreso, borrar y deshacer en el Banco, y el cambio de día al volver a la app.

La fecha se inyecta en `ProgressRepository`, así que los tests no dependen del reloj. Los unitarios usan Hive en una carpeta temporal; los de widgets, cajas en memoria.

## Limitaciones conocidas

- **Solo probada en Android.** Las carpetas de iOS, web y escritorio son las que genera Flutter y las notificaciones solo se configuran para Android.
- **La API key viaja en el APK.** No hay backend propio (ver la sección de la API key).
- **`google_generative_ai` está deprecado** por Google en favor de Firebase AI Logic. Migrar está pendiente.
- **Fuente:** Poppins se descarga con `google_fonts` la primera vez que se abre la app. Sin conexión se usa la fuente del sistema.
- **Imágenes:** se guarda la ruta del archivo que devuelve `image_picker`, que puede estar en la caché de la app. El respaldo JSON no incluye las imágenes.
- **No está lista para publicar:** el build de release se firma con la clave de debug.
- **Cambio de `applicationId`:** pasó de `com.example.quiz_daily` a `io.github.juanespinoza8.quizdaily`. Android la trata como otra app: para conservar los datos de una instalación anterior, crear un respaldo en la vieja y restaurarlo en la nueva.
- **Tests de widgets parciales:** cubren el quiz, el Banco y el cambio de día; el resto de las pantallas no tiene.

## Autor

**Juan Espinoza** — [github.com/JuanEspinoza8](https://github.com/JuanEspinoza8)

Licencia [MIT](LICENSE).
