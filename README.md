# TokTik + Firebase + ML Kit

Copia de TikTok hecha en Flutter. Puedes iniciar sesión, subir videos y
fotos, verlos en un feed vertical en tiempo real, dar like y ponerle
**filtros faciales** a tus fotos (lentes, bigote, sombrero de fiesta,
corona, perrito y calabaza 🎃).

Todos los que usen esta app comparten **el mismo feed**: lo que sube una
persona aparece al instante en el teléfono de las demás.

Proyecto de Desarrollo de Aplicaciones Móviles (ESEN). Clase 23 (Firebase)
y Clase 24 (ML Kit), a partir de la base `dam-353n/copiaTikTokCompleta`.

---

## Qué hace

| Función | Cómo se usa |
|---|---|
| **Cuenta** | Registro e inicio de sesión con correo y contraseña. |
| **Feed** | Desliza hacia arriba o abajo. Muestra los videos y fotos de todos, del más nuevo al más viejo. Toca un video para pausarlo. |
| **Subir** | Botón **+** arriba a la derecha → video o foto, de la galería o de la cámara → descripción → **Publicar**. |
| **Filtros faciales** | Al elegir una foto: **Filtros faciales**. O en el menú **+**: **Cámara con filtros en vivo**. Se pueden combinar varios. |
| **Like ❤️** | Un like por persona. Tocarlo otra vez lo quita. |
| **Vistas 👁️** | Se suma una por persona cada vez que abre la app y ve el post. |
| **Borrar 🗑️** | Solo aparece en tus propias publicaciones. |
| **Usuario** | Arriba de la descripción sale `@usuario`, tomado del correo de quien lo subió. |

## Cómo funciona (en corto)

```
App Flutter
 ├─ Firebase Auth     → cuentas (correo y contraseña)
 ├─ Cloud Firestore   → colección "posts": descripción, autor, likes, vistas, URL del archivo
 ├─ Cloud Storage     → los archivos de video y foto (posts/<uid>/...)
 └─ ML Kit (on-device)→ detecta caras y sus puntos (ojos, nariz, boca) para colocar los filtros
```

- **Patrón repository:** las pantallas solo conocen la interfaz
  `PostsRepository`. `FirebasePostsRepository` usa Firestore y Storage.
  `LocalPostsRepository` usa los videos locales del proyecto original.
- **Tiempo real:** el feed escucha un `Stream` de Firestore, así que no hay
  que recargar.
- **AuthGate:** un `StreamBuilder<User?>` sobre `authStateChanges()`. Sin
  sesión muestra el login; con sesión, el feed.
- **Likes:** se guardan en `likedBy` (uid de quienes dieron like). Se
  actualizan con una transacción y `FieldValue.increment`.
- **Seguridad:** las reglas (`firestore.rules` y `storage.rules`, ya
  publicadas en la consola) exigen sesión. Nadie puede publicar a nombre de
  otro, borrar lo ajeno ni inflar likes o vistas.
- **Filtros:** ML Kit corre en el teléfono, sin internet. La geometría está
  en `lib/presentation/filters/face_filter_painter.dart`. La foto con
  filtros se guarda como PNG y se sube como cualquier otra foto.

### Estructura

```
lib/
  domain/          entidad VideoPost y contrato PostsRepository
  infrastructure/  Firebase (repositorio, modelo) y AuthService
  presentation/
    providers/     DiscoverProvider (estado del feed)
    screens/       auth (login), discover (feed), upload, filters
    filters/       lista de filtros, painter y selector
    widgets/       reproductor, foto, botones, avisos
assets/filtros/    PNG de los filtros
```

---

## Cómo probarla (para compañeros)

La app ya está conectada al proyecto de Firebase `clase23-firebase-demo`.
Si usas este código tal cual, **subes y ves el mismo feed que todos**. No
tienes que crear nada en Firebase.

### 1. Requisitos

- **Flutter 3.47 o más nuevo** (`flutter --version`).
- Para **Android** (Windows, Mac o Linux): **Android Studio**, y un emulador
  o un celular Android 7.0 o más nuevo. Es lo recomendado, lo más fácil.
- Para **iPhone**: una Mac con **Xcode** y **CocoaPods**, más tu iPhone con cable.

Revisa que todo esté bien con:
```bash
flutter doctor
```
Lo importante es que **Android toolchain** (o **Xcode**, si vas con iPhone)
salga con ✓.

> ⚠️ **El simulador de iOS no sirve** para esta app. ML Kit (los filtros)
> no se puede compilar para el simulador en Macs con Apple Silicon. Usa el
> **emulador de Android** o un **iPhone real**.

### 2. Bajar el proyecto e instalar dependencias

```bash
git clone https://github.com/sonali-218/TokTik-Apps.git
cd TokTik-Apps
flutter pub get
```

### 3A. Correr en Android (recomendado)

En Android **no hay que cambiar nada del proyecto**: el `applicationId`
(`com.example.toktik`) ya está registrado en Firebase y no hace falta firmar
la app para probarla.

**Preparar Android Studio (solo la primera vez)**

1. Instala [Android Studio](https://developer.android.com/studio) y ábrelo una
   vez para que descargue el **Android SDK**.
2. En **Settings → Languages & Frameworks → Android SDK → SDK Tools**, marca
   **Android SDK Command-line Tools** y dale **Apply**.
3. Acepta las licencias:
   ```bash
   flutter doctor --android-licenses
   ```
   Responde `y` a todo.

**Opción 1: emulador**

1. En Android Studio: **More Actions → Virtual Device Manager → Create
   Virtual Device** (o el **+**).
2. Elige un teléfono (por ejemplo **Pixel 8**) y una imagen de sistema
   reciente (**API 35 o 36**). En Mac con Apple Silicon, elige una imagen
   **arm64**.
3. Para probar la **cámara con filtros**, antes de terminar abre **Show
   Advanced Settings** (o **Additional settings**) y pon **Front camera:
   Webcam0**. Así el emulador usa la cámara de tu computadora.
4. Abre el emulador y corre la app:
   ```bash
   flutter emulators                    # lista tus emuladores
   flutter emulators --launch <nombre>  # abre uno
   flutter run
   ```

**Opción 2: tu celular Android con cable**

1. En el celular: **Ajustes → Acerca del teléfono** y toca **Número de
   compilación** 7 veces, hasta que diga que ya eres desarrollador.
2. Entra a **Ajustes → Sistema → Opciones de desarrollador** y activa
   **Depuración por USB**.
3. Conéctalo por cable. En el celular, acepta **¿Permitir depuración USB?**
   (marca "Permitir siempre").
4. Revisa que aparezca y corre la app:
   ```bash
   flutter devices
   flutter run
   ```

**Notas de Android**

- La **primera compilación tarda varios minutos** (Gradle descarga todo).
  Las siguientes son mucho más rápidas.
- Cuando la app lo pida, permite **Cámara** y **Fotos y videos**.
- Para meter videos o fotos al emulador, **arrástralos a la ventana del
  emulador**. Quedan en la carpeta *Download* y se eligen desde la galería
  de la app.
- A diferencia de iPhone, en Android sí puedes abrir la app desde su ícono
  aunque la hayas instalado con `flutter run`.

### 3B. Correr en tu iPhone

1. Instala los pods:
   ```bash
   cd ios && pod install --repo-update && cd ..
   ```
2. Abre `ios/Runner.xcworkspace` en Xcode → **Runner** → **TARGETS: Runner**
   → **Signing & Capabilities**:
   - Marca **Automatically manage signing**.
   - **Team**: tu Apple ID (Personal Team).
   - **Bundle Identifier**: cámbialo por uno tuyo, por ejemplo
     `com.tunombre.toktik`. Apple no deja usar el mismo en dos cuentas.
3. En el iPhone, activa **Ajustes → Privacidad y seguridad → Modo de desarrollador**.
4. Cierra Xcode y corre:
   ```bash
   flutter run
   ```
5. La primera vez:
   - Si la Mac pide la contraseña del llavero para `codesign`, pon la
     contraseña de tu Mac y elige **Always Allow**.
   - Si el iPhone dice **"Desarrollador no confiable"**, ve a **Ajustes →
     General → VPN y gestión de dispositivos → tu Apple ID → Confiar**, y
     vuelve a correr `flutter run`.
   - Permite **Red local** y **Cámara** cuando la app lo pida.

> En modo debug la app solo se abre desde `flutter run`. Si tocas el ícono
> directamente, iOS muestra un aviso. Para usarla sin la Mac:
> `flutter run --release`. Con un Apple ID gratuito, esa versión deja de
> abrir a los 7 días.

> Si al cambiar el Bundle ID Firebase da errores de configuración en iOS,
> pídele a Alisson que te agregue al proyecto de Firebase y corre
> `dart pub global activate flutterfire_cli` y
> `flutterfire configure --project=clase23-firebase-demo`.

### 4. Probar

1. Crea tu cuenta. Puede ser cualquier correo, no se verifica.
2. Toca **+** y sube un video o una foto. Debe aparecer en el feed de todos.
3. Dale like a lo que subieron otros y prueba los filtros con una selfie.

---

## Problemas comunes

| Mensaje | Solución |
|---|---|
| `command not found: flutterfire` | `export PATH="$PATH":"$HOME/.pub-cache/bin"` |
| `Android license status unknown` | `flutter doctor --android-licenses` y responde `y`. |
| `No supported devices connected` (Android) | Abre el emulador primero, o revisa la **Depuración por USB** y acepta el aviso en el celular. |
| Error de Gradle / Java al compilar Android | En Android Studio usa el JDK incluido (**Settings → Build Tools → Gradle → Gradle JDK**). Luego `flutter clean`, `flutter pub get` y `flutter run`. |
| Cámara negra en el emulador | En el **Virtual Device Manager**, edita el emulador y pon **Front camera: Webcam0**. |
| `Building for 'iOS-simulator', but linking ... MLImage` | Es el simulador de iOS. Usa Android o un iPhone real. |
| `Failed Registering Bundle Identifier` | Cambia el Bundle Identifier por uno único (paso 3B). |
| `The Dart VM Service was not discovered...` | iPhone desbloqueado. Permite que la Terminal controle Xcode y **Red local** en el iPhone. |
| "No se detectó ningún rostro" | Usa una foto de frente, bien iluminada, con la cara grande. |
| `unauthorized` / `permission-denied` | Inicia sesión otra vez. Solo puedes borrar lo tuyo. |

## Notas

- Los archivos `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`
  y `android/app/google-services.json` conectan la app con Firebase. Sus
  claves no son secretas: la seguridad está en las reglas.
- El proyecto de Firebase usa la prueba gratuita de Google Cloud hasta el
  15 de enero de 2027. Después Storage deja de funcionar si no se renueva.
- Para tener un feed propio y separado, crea tu proyecto de Firebase y corre
  `flutterfire configure` con ese proyecto.
- Para probar la interfaz sin Firebase, cambia en `main.dart`
  `FirebasePostsRepository()` por `LocalPostsRepository()` y pon los videos
  en `assets/videos/1.mp4` … `8.mp4`.
