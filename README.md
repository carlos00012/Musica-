# Música

Reproductor Flutter de audio local para Android, con controles de reproducción en
segundo plano y dos widgets de pantalla de inicio.

## Funciones

- Biblioteca local indexada con MediaStore: canciones y carátulas.
- Filtros para mostrar música clasificada por Android, ocultar tonos/sonidos del
  sistema y definir la duración mínima; la selección de filtros y el orden se
  conservan al reiniciar la app.
- Búsqueda por canción, artista y álbum; orden por título, artista o álbum.
- Favoritos, historial local y listas de reproducción.
- Reproducción continua, cola, seek, volumen, shuffle y repetición.
- `audio_service` y `just_audio` para MediaSession, pantalla de bloqueo y
  notificación multimedia.
- Widgets Android compacto y con carátula; los controles se comunican con la
  sesión multimedia y reflejan los cambios de pista.
- GitHub Actions compila el APK release y lo publica como artefacto descargable.

La app reproduce archivos de audio almacenados en el teléfono. No conecta a
Spotify ni a otro servicio de streaming.

## Descargar el APK

Abre la pestaña **Actions**, selecciona la ejecución terminada de **Build Android
APK** y descarga el artefacto `musica-android-apk`. Extrae el ZIP e instala
`app-release.apk`. Al instalarlo fuera de Play Store, Android puede pedir que
autorices la instalación desde esa fuente.

Las ejecuciones se disparan al hacer push a `main` o manualmente desde
**Actions → Build Android APK → Run workflow**.

## Ejecutar localmente

Requiere Flutter estable, Android SDK y Java 17 o la versión de Java requerida
por la plantilla Android que genere Flutter.

```powershell
flutter create --project-name musica --org com.musica --platforms android build\android
Copy-Item pubspec.yaml build\android\pubspec.yaml -Force
Remove-Item build\android\lib -Recurse -Force
New-Item build\android\lib -ItemType Directory -Force
Copy-Item lib\* build\android\lib -Recurse -Force
Copy-Item android_overlay\app\src\main\* build\android\android\app\src\main\ -Recurse -Force
Set-Location build\android
flutter pub get
flutter run
```

Para compilar:

```powershell
flutter build apk --release
```

## Permisos y HyperOS

La app pide permiso de audio local y permiso de notificaciones. El servicio
declara `FOREGROUND_SERVICE_MEDIA_PLAYBACK` y usa la sesión multimedia de
Android. Si HyperOS detiene la reproducción al cerrar la app, permite actividad
en segundo plano y notificaciones en los ajustes de batería y aplicaciones de
HyperOS. La disponibilidad de esas opciones puede variar por versión del
sistema.

Los widgets se agregan desde el selector de widgets del launcher. El launcher o
HyperOS puede limitar la frecuencia de actualización cuando la app está
restringida por batería.
