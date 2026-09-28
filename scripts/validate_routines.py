"""Valida las rutinas JSON contra schema/routine.schema.json (requiere `pip install jsonschema`)."""
import json
import pathlib
import sys

from jsonschema import Draft202012Validator

root = pathlib.Path(__file__).resolve().parent.parent
validator = Draft202012Validator(json.loads((root / "schema/routine.schema.json").read_text()))

failed = False
for path in sorted([*root.glob("examples/*.json"), *root.glob("routines/*.json")]):
    errors = list(validator.iter_errors(json.loads(path.read_text())))
    for error in errors:
        print(f"{path.relative_to(root)}: {error.json_path}: {error.message}")
    print(f"{path.relative_to(root)}: {'ERROR' if errors else 'ok'}")
    failed |= bool(errors)

sys.exit(1 if failed else 0)
