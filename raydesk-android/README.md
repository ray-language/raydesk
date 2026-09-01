# App Android generada por `ray bundle --android`

- `app/src/main/jniLibs/<abi>/libray_app.so` es el programa raylang compilado como cdylib;
  para regenerarlo tras cambiar el programa: `ray bundle --android` de nuevo
  (`--android-abi arm64|x86_64|all` construye solo un ABI; el otro `.so` se conserva).
- Compilar el APK (Gradle del sistema + JDK 17+; `gradle wrapper` si quieres pinnear):
  `gradle assembleDebug` → `app/build/outputs/apk/debug/app-debug.apk`.
- Emulador/dispositivo: `adb install -r app/build/outputs/apk/debug/app-debug.apk` y lanza la
  app (o `adb shell am start -n <applicationId>/org.raylang.shell.MainActivity`). OJO: un APK
  solo-arm64 no instala en un emulador x86_64 (INSTALL_FAILED_NO_MATCHING_ABIS) — usa
  `--android-abi all`.
- stdout/stderr del programa van a **logcat** con tag `ray`: `adb logcat -s ray`.
- El puente IPC (M152) funciona igual que en escritorio/iOS: `window.ray.send(text)` llega
  como evento `"message"` (window 0). Los eventos `lifecycle` llegan en onPause/onResume.
- `std/fs`/`std/kv`: escribe en el directorio privado de la app (el cwd no es tuyo); las
  rutas externas están restringidas (scoped storage) — también para `fs.watch`.
- Firma: el debug keystore de Gradle basta para instalar; firma de release = v2 (keystore
  propio, fuera del v1).
