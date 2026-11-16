"""Genera MANIFEST.sha256 de un pack de assets/third_party/.

Uso: python -I tools/third_party_manifest.py assets/third_party/<pack>

Escribe una linea por archivo ("<sha256>  <ruta relativa con />"), en orden, sin incluir
el propio manifiesto ni .gdignore. verify.ps1 deps comprueba despues que coincide.
"""

import hashlib
import sys
from pathlib import Path

SKIP = {"MANIFEST.sha256", ".gdignore"}


def build(pack: Path) -> list[str]:
    lines = []
    for path in sorted(p for p in pack.rglob("*") if p.is_file()):
        if path.name in SKIP:
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(pack).as_posix()}")
    return lines


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    pack = Path(sys.argv[1]).resolve()
    if not pack.is_dir() or pack.parent.name != "third_party":
        print("La ruta debe ser una carpeta dentro de assets/third_party/")
        return 2
    lines = build(pack)
    (pack / "MANIFEST.sha256").write_text("\n".join(lines) + "\n", encoding="ascii", newline="\n")
    print(f"{pack.name}: {len(lines)} archivos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
