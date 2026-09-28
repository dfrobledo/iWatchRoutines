# iWatchRoutines

Convierte una rutina de gimnasio escrita en prosa en una sesión guiada paso a paso en el Apple Watch.

```
Prosa → Intérprete IA → Rutina estructurada (JSON) → Revisión en iPhone → Reproductor en el Watch
```

## Estructura

| Ruta | Contenido |
|---|---|
| `schema/routine.schema.json` | Formato intermedio (JSON Schema 2020-12) |
| `examples/plan-adaptacion.json` | Plan real de 3 días convertido al formato; es el caso de prueba |

## Ideas clave del formato

- **Valores por defecto con herencia:** `defaults` define series, repeticiones y descanso. Cada ejercicio solo declara lo que cambia.
- **Rangos en todas partes:** "10 a 12 repeticiones" o "60 a 90 s" se guardan como `{min, max}`. Un valor fijo es `min == max`.
- **Objetivo por repeticiones o por tiempo:** `target.kind` es `reps` o `time`, como en una plancha.
- **Alternativas por ejercicio:** sirven para cambiar de ejercicio en el momento, por ejemplo si la máquina está ocupada.
- **`perSide`:** en los ejercicios unilaterales, el Watch guía primero un lado y luego el otro.
- **`openQuestions`:** lo que el intérprete no pudo deducir del texto. El iPhone lo pregunta antes de enviar la rutina al Watch.
- **`progression.rule`:** doble progresión. El Watch sugiere subir repeticiones hasta el máximo del rango y después subir el peso.
- **`safetyReminders`:** avisos de conducta que se muestran antes, durante o después de la sesión.

Los suplementos del plan original quedan fuera del formato porque no forman parte de la sesión.

## Validar

```sh
pip install jsonschema
python3 -c "import json,jsonschema; jsonschema.validate(json.load(open('examples/plan-adaptacion.json')), json.load(open('schema/routine.schema.json')))"
```
