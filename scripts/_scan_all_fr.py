# -*- coding: utf-8 -*-
"""Liste les chaînes FR encore en dur dans lib/."""
import re
from pathlib import Path

root = Path(r"C:\Users\Super\mtg_table\lib")
# Heuristique : apostrophes FR / accents dans littéraux
lit = re.compile(r"""(['"])([^'"]*[éèêëàâäùûüôöîïçÉÈÀÙÔÎÇ’][^'"]*)\1""")
hits = []
for p in root.rglob("*.dart"):
    if "l10n" in p.parts:
        continue
    for i, line in enumerate(p.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        if "context.t(" in line or line.strip().startswith("//"):
            continue
        for m in lit.finditer(line):
            s = m.group(2)
            if len(s) < 2:
                continue
            # ignorer chemins / assets / regex techniques
            if s.startswith("assets/") or "package:" in s:
                continue
            hits.append((str(p.relative_to(root)), i, s[:120], line.strip()[:140]))

print("TOTAL", len(hits))
for h in hits:
    print(f"{h[0]}:{h[1]} | {h[2]} | {h[3]}")
