# Copyright: Ankitects Pty Ltd and contributors
# License: GNU AGPL, version 3 or later; http://www.gnu.org/licenses/agpl.html

import subprocess
import sys
from pathlib import Path

# If no arguments provided, build for the anki_mac_helper package
if len(sys.argv) == 1:
    script_dir = Path(__file__).parent
    out_dylib = script_dir / "anki_mac_helper" / "libankihelper.dylib"
    src_files = [*script_dir.glob("*.swift"), *script_dir.glob("*.m")]
else:
    out_dylib, *src_files = sys.argv[1:]

out_dylib = Path(out_dylib)
out_dir = out_dylib.parent.resolve()
src_files = [Path(file).resolve() for file in src_files]
out_dir.mkdir(parents=True, exist_ok=True)

# Build for both architectures
architectures = ["arm64", "x86_64"]
temp_files = []

for arch in architectures:
    target = f"{arch}-apple-macos11"
    temp_out = out_dir / f"temp_{arch}.dylib"
    temp_files.append(temp_out)

    args = [
        "swiftc",
        "-target",
        target,
        "-emit-library",
        "-module-name",
        "ankihelper",
        "-O",
    ]
    objects = []
    for source in src_files:
        if source.suffix == ".m":
            obj = out_dir / f"{source.stem}_{arch}.o"
            subprocess.run(
                [
                    "clang",
                    "-target",
                    target,
                    "-fno-objc-arc",
                    "-O2",
                    "-c",
                    str(source),
                    "-o",
                    str(obj),
                ],
                check=True,
            )
            objects.append(obj)
    args.extend(file for file in src_files if file.suffix == ".swift")
    args.extend(objects)
    args.extend(["-o", str(temp_out)])
    subprocess.run(args, check=True, cwd=out_dir)
    for obj in objects:
        obj.unlink()

# Create universal binary
lipo_args = ["lipo", "-create", "-output", str(out_dylib)] + [
    str(f) for f in temp_files
]
subprocess.run(lipo_args, check=True)

# Clean up temporary files
for temp_file in temp_files:
    temp_file.unlink()
