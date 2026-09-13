"""Build the core's 256-word instruction image; keep unchanged images untouched."""
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
data = src.read_bytes()
if len(data) > 1024:
    sys.exit(f"Program is {len(data)} bytes; instruction memory holds only 1024 bytes.")
if len(data) % 4:
    sys.exit("RV32I program size must be a multiple of four bytes.")

words = [f"{int.from_bytes(data[i:i+4], 'little'):08x}" for i in range(0, len(data), 4)]
words += ["00000013"] * (256 - len(words))  # Fill unused memory with NOPs.
image = "\n".join(words) + "\n"
if not dst.exists() or dst.read_text() != image:
    dst.write_text(image)
