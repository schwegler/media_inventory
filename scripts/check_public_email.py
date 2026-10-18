"""Guard the public contact surface without dependencies."""
from pathlib import Path
from html.parser import HTMLParser
from html import unescape
import re
ROOT = Path(__file__).resolve().parent.parent
ADDRESS = "andrew" + "@" + "schweg.xyz"
for directory in ["app/views", "app/helpers"]:
    for path in (ROOT / directory).rglob("*"):
        if path.is_file():
            assert ADDRESS not in path.read_text(), f"Public email needs encoding: {path}"
print("No plaintext public creator email in application templates/helpers.")
