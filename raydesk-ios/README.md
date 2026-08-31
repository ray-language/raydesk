# App iOS generada por `ray bundle --ios`

- `libs/` y `libs-sim/` llevan el staticlib del programa (dispositivo / simulador); el
  xcconfig elige por SDK. Para regenerarlos tras cambiar el programa:
  `ray bundle --ios` de nuevo (o `ray build --native --lib --target aarch64-apple-ios…`).
- Simulador (sin firma):
  `xcodebuild -project <Name>.xcodeproj -target <Name> -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`
  y luego `xcrun simctl boot <device>` + `install` + `launch`.
- Dispositivo: abrir el `.xcodeproj` en Xcode y elegir tu equipo de firma (Signing & Teams).
- El programa raylang corre DENTRO de la app (staticlib): su webserver embebido sirve la UI y
  `ui.open(title, url)` carga la URL en el webview. Los eventos de ciclo de vida llegan por
  `ui.next_event()` como kind="lifecycle", tag="background"/"foreground".
