# 🧠 QuizDaily+

**App educativa de microaprendizaje diario** — Genera, carga y responde quizzes para retener el conocimiento en el tiempo.

Estudia cualquier tema mediante repasos diarios. Crea cuestionarios manualmente, impórtalos o géneralos automáticamente usando Inteligencia Artificial. Haz un seguimiento de tu progreso y alcanza tus metas de aprendizaje directamente desde tu dispositivo móvil.

![Version](https://img.shields.io/badge/version-1.0.0-red?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Status](https://img.shields.io/badge/status-Production-brightgreen?style=flat-square)

---

## Funcionalidades

- Generación automática de preguntas usando Inteligencia Artificial (Gemini)
- Creación manual e importación de bancos de preguntas
- Quizzes diarios para mantener el hábito de estudio
- Notificaciones locales para recordar tus sesiones de aprendizaje
- Gráficos y estadísticas para el seguimiento de tu progreso
- Establecimiento de metas de estudio diarias
- Base de datos local ultra-rápida (Funciona 100% offline)

---

## Stack

### Mobile Frontend
<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Google_Fonts-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Google Fonts" />
  <img src="https://img.shields.io/badge/Fl_Chart-FF6E40?style=for-the-badge&logo=flutter&logoColor=white" alt="Fl Chart" />
</p>

### Estado y Datos
<p>
  <img src="https://img.shields.io/badge/Hive_NoSQL-FFB11B?style=for-the-badge&logo=hive&logoColor=black" alt="Hive" />
  <img src="https://img.shields.io/badge/File_Picker-3E67B1?style=for-the-badge" alt="File Picker" />
  <img src="https://img.shields.io/badge/Share_Plus-000000?style=for-the-badge" alt="Share Plus" />
</p>

### Inteligencia Artificial & Servicios
<p>
  <img src="https://img.shields.io/badge/Google_Gemini_AI-8E75B2?style=for-the-badge&logo=google&logoColor=white" alt="Gemini" />
  <img src="https://img.shields.io/badge/Local_Notifications-4CAF50?style=for-the-badge&logo=android&logoColor=white" alt="Notifications" />
</p>

---

## Setup

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
> - **Restricción de aplicación Android** (nombre de paquete + huella SHA-1 del certificado de firma). Google valida esta restricción con los headers `X-Android-Package` y `X-Android-Cert`, que el SDK de Dart no envía solo. La app los agrega si se define `ANDROID_CERT_SHA1` en `env.json` (y `ANDROID_PACKAGE` si cambia el `applicationId`):
>
>   ```json
>   { "GEMINI_API_KEY": "...", "ANDROID_CERT_SHA1": "AA:BB:CC:..." }
>   ```
>
>   La huella sale de `cd android && ./gradlew signingReport`. Sin estos valores, una clave restringida a Android responde 403.
>
> Ninguna de las dos impide que alguien con el APK reutilice la clave: la protección real es un backend propio (o Firebase App Check) entre la app y Gemini.

---

## Equipo

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/JuanEspinoza8">
        <img src="https://github.com/JuanEspinoza8.png" width="80px;" alt=""/><br />
        <b>Juan Espinoza</b>
      </a>
      <br />
      Lead Developer
    </td>
  </tr>
</table>
