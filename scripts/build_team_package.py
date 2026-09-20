#!/usr/bin/env python3
"""Build a teammate-safe source archive without local secrets or build caches."""

from __future__ import annotations

import argparse
from datetime import date
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = "StudyCompanionHarmony"

EXCLUDED_NAMES = {
    ".DS_Store",
    ".env",
    ".git",
    ".hvigor",
    ".idea",
    ".test",
    "__pycache__",
    "build",
    "dist",
    "local.properties",
    "node_modules",
    "oh_modules",
}

EXCLUDED_SECRET_SUFFIXES = {".cer", ".jks", ".key", ".p12", ".p7b", ".pem", ".pfx"}

SAFE_BUILD_PROFILE = """{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "targetSdkVersion": "6.1.1(24)",
        "compatibleSdkVersion": "5.0.0(12)",
        "runtimeOS": "HarmonyOS",
        "buildOption": {
          "strictMode": {
            "caseSensitiveCheck": true,
            "useNormalizedOHMUrl": true
          }
        }
      }
    ],
    "buildModeSet": [
      {
        "name": "debug"
      },
      {
        "name": "release"
      }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default",
          "applyToProducts": [
            "default"
          ]
        }
      ]
    }
  ]
}
"""


def excluded(relative_path: Path) -> bool:
    return (
        any(part in EXCLUDED_NAMES for part in relative_path.parts)
        or relative_path.suffix.lower() in EXCLUDED_SECRET_SUFFIXES | {".pyc"}
    )


def build(output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output_path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for source_path in sorted(PROJECT_ROOT.rglob("*")):
            relative_path = source_path.relative_to(PROJECT_ROOT)
            if source_path.is_dir() or source_path.is_symlink() or excluded(relative_path):
                continue
            archive_path = f"{PACKAGE_ROOT}/{relative_path.as_posix()}"
            if relative_path == Path("build-profile.json5"):
                archive.writestr(archive_path, SAFE_BUILD_PROFILE)
            else:
                archive.write(source_path, archive_path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=PROJECT_ROOT / "dist" / f"StudyCompanionHarmony-team-{date.today().isoformat()}.zip",
    )
    args = parser.parse_args()
    output_path = args.output.resolve()
    build(output_path)
    print(output_path)


if __name__ == "__main__":
    main()
