# iWatchRoutines

Convierte una rutina de gimnasio escrita en prosa en una sesión guiada paso a paso en el Apple Watch.

```
Prosa → Claude → routines/actual.json (en GitHub) → el reloj la descarga → sesión guiada
```

La app se instala una sola vez. Para cambiar la rutina solo se actualiza `routines/actual.json`; el reloj la descarga al abrirse o con el botón **Actualizar**, y guarda la última copia para funcionar sin conexión.

## Qué hace la app en el reloj

- Recorre calentamiento → series → descansos, con el progreso y el pulso en pantalla.
- Descansos con rango (60–90 s): vibración suave al mínimo ("ya puedes seguir") y fuerte al máximo.
- **Double Tap** (juntar índice y pulgar) marca la serie como hecha. Requiere watchOS 11 y un Series 9 o posterior, o un Ultra 2.
- **Cambiar ejercicio** cuando la máquina está ocupada. Conserva la serie en la que ibas.
- Ejercicios unilaterales: primer lado y segundo lado antes de descansar.
- Muestra los recordatorios de salud en los descansos y al terminar.
- Guarda la sesión en Salud como entrenamiento de fuerza.

## Estructura

| Ruta | Contenido |
|---|---|
| `routines/actual.json` | Rutina que descarga el reloj |
| `schema/routine.schema.json` | Formato de la rutina (JSON Schema 2020-12) |
| `examples/plan-adaptacion.json` | Plan de 3 días usado en los tests |
| `RoutineKit/` | Paquete Swift con el modelo y la lógica de la sesión, con tests |
| `WatchApp/Sources/` | App de watchOS (SwiftUI + HealthKit) |
| `project.yml` | Definición del proyecto Xcode (XcodeGen) |

## Instalar en el reloj

Necesitas una Mac con Xcode y el iPhone emparejado con el Watch.

1. `brew install xcodegen`
2. En la carpeta del repo: `xcodegen generate` y abre `iWatchRoutines.xcodeproj`.
3. En el target **iWatchRoutines** → *Signing & Capabilities*, elige tu Apple ID como *Team*. Si Xcode dice que el identificador ya está en uso, cambia `PRODUCT_BUNDLE_IDENTIFIER` en `project.yml`.
4. Activa el **Modo de desarrollador** en el iPhone y en el Watch (Configuración → Privacidad y seguridad).
5. Elige tu Apple Watch como destino y pulsa *Run*. La primera instalación puede tardar varios minutos.

Con un Apple ID gratuito la app caduca a los 7 días y hay que repetir el paso 5. Con el Programa de Desarrolladores de Apple dura un año.

## Actualizar la rutina

1. Pide a Claude que convierta la nueva rutina en prosa al formato de `schema/routine.schema.json`.
2. Reemplaza `routines/actual.json`, valida con `python3 scripts/validate_routines.py` y súbelo a la rama principal del repo.
3. En el reloj, pulsa **Actualizar**. GitHub puede tardar unos minutos en servir la versión nueva.

El repositorio es público, así que cualquiera puede leer la rutina. Para mantenerla privada, alójala en otro lugar y cambia `RoutineURL` en `project.yml`.

## Formato de la rutina

- `defaults` define series, repeticiones y descanso; cada ejercicio solo declara lo que cambia.
- Los rangos ("10 a 12", "60 a 90 s") se guardan como `{min, max}`.
- `target.kind` es `reps` o `time`. Si una duración no está definida (`seconds: null`), el reloj usa un cronómetro abierto.
- `alternatives`: sustitutos que se pueden elegir durante la sesión.
- `perSide`: ejercicio unilateral.
- `openQuestions`: dudas que el texto original no resuelve; el reloj las lista en "Por definir".
- `safetyReminders`: avisos antes, durante o después de la sesión.

## Desarrollo

- Tests de la lógica: `swift test --package-path RoutineKit`
- El CI de GitHub valida las rutinas, corre los tests y compila la app del Watch en macOS.
