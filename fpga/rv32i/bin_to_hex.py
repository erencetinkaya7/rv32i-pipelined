from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

data = src.read_bytes()

with dst.open("w") as f:
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i+4], "little")
        f.write(f"{word:08x}\n")
