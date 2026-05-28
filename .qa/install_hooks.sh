#!/bin/bash
# =============================================================================
# install_hooks.sh — Installe les hooks Claude Code (à exécuter UNE FOIS)
# Usage: bash /d/mob/.qa/install_hooks.sh
# =============================================================================

HOOKS_DIR="/c/Users/DALI/.claude/hooks"
SCRIPTS_DIR="/d/mob/.qa"
SETTINGS="/c/Users/DALI/.claude/settings.json"

echo "=== Installation des hooks Claude Code Flutter Portfolio ==="
echo ""

# 1. Créer le dossier hooks
mkdir -p "$HOOKS_DIR"
echo "✅ $HOOKS_DIR créé"

# 2. Copier les scripts
cp "$SCRIPTS_DIR/track_flutter_edit.sh"  "$HOOKS_DIR/"
cp "$SCRIPTS_DIR/validate_on_stop.sh"    "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/track_flutter_edit.sh"
chmod +x "$HOOKS_DIR/validate_on_stop.sh"
echo "✅ Scripts copiés + chmod +x"

# 3. Mettre à jour settings.json (ajouter le bloc hooks)
# Backup d'abord
cp "$SETTINGS" "${SETTINGS}.bak"
echo "✅ Backup: ${SETTINGS}.bak"

# Injection du bloc hooks dans settings.json via Python
python3 - <<'PYEOF'
import json, sys

settings_path = '/c/Users/DALI/.claude/settings.json'
with open(settings_path, 'r') as f:
    cfg = json.load(f)

hooks = {
    "PostToolUse": [
        {
            "matcher": "Edit|Write",
            "hooks": [
                {
                    "type": "command",
                    "command": "bash /c/Users/DALI/.claude/hooks/track_flutter_edit.sh",
                    "timeout": 5
                }
            ]
        }
    ],
    "Stop": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": "bash /c/Users/DALI/.claude/hooks/validate_on_stop.sh",
                    "timeout": 300
                }
            ]
        }
    ]
}

cfg['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(cfg, f, indent=2)

print("✅ settings.json mis à jour avec les hooks")
PYEOF

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ Installation terminée !                  ║"
echo "║                                              ║"
echo "║  Hooks actifs pour toutes les sessions :     ║"
echo "║  • Edit/Write → trace l'app modifiée        ║"
echo "║  • Stop       → flutter analyze + rapport   ║"
echo "║                                              ║"
echo "║  Rapport : /d/mob/.qa/regression_log.md     ║"
echo "╚══════════════════════════════════════════════╝"
