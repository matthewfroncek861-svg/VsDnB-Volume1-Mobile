import os
import re

TARGET_EXT = (".hx",)

# Patterns to replace
REPLACEMENTS = {
    r"import\s+flixel\.animation\.FlxFrameation\s*;": 
        "import flixel.graphics.frames.FlxFrame;",

    r"\bFlxFrameation\b": 
        "FlxFrame",
}

def patch_file(path):
    with open(path, "r", encoding="utf-8") as f:
        original = f.read()

    patched = original
    for pattern, replacement in REPLACEMENTS.items():
        patched = re.sub(pattern, replacement, patched)

    if patched != original:
        # Backup
        backup_path = path + ".backup"
        with open(backup_path, "w", encoding="utf-8") as f:
            f.write(original)

        # Write patched
        with open(path, "w", encoding="utf-8") as f:
            f.write(patched)

        print(f"[FIXED] {path}")
    else:
        print(f"[OK]    {path}")


def scan_and_patch(root):
    for folder, _, files in os.walk(root):
        for file in files:
            if file.lower().endswith(TARGET_EXT):
                patch_file(os.path.join(folder, file))


if __name__ == "__main__":
    print("=== FlxAnimate Auto-Patch ===")
    print("Scanning 'source/' for FlxFrameation leftovers...\n")

    scan_and_patch("source")

    print("\nDone! All FlxFrameation references patched.")
    print("Backup copies are saved as *.backup")
