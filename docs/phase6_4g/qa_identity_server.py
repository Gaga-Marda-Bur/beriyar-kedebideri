"""Reuse approved synthetic fixtures, relocated to this lot's isolated runtime."""
from pathlib import Path
source=Path(__file__).resolve().parents[1]/'phase6_4c/qa_server.py'
exec(compile(source.read_text(encoding='utf-8-sig'),str(__file__),'exec'))
