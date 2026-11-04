#!/usr/bin/env python3
"""Adds the source scripts to the original Place13 binary without changing its assets.
Requires: python -m pip install zstandard. Source paths are relative to repo root.
"""
import struct
from pathlib import Path
import zstandard

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / 'Place13.rbxl').read_bytes()
if source[:14] != b'<roblox!\x89\xff\r\n\x1a\n':
    raise ValueError('Expected a binary Roblox place')
header = bytearray(source[:32])
class_count, instance_count = struct.unpack_from('<II', header, 16)
chunks = []
offset = 32
while offset < len(source):
    tag, compressed, uncompressed, reserved = struct.unpack_from('<4sIII', source, offset)
    end = offset + 16 + (compressed or uncompressed)
    raw = source[offset:end]
    payload = raw[16:]
    if compressed:
        payload = zstandard.ZstdDecompressor().decompress(payload, max_output_size=uncompressed)
    chunks.append((tag, payload, raw))
    offset = end
    if tag == b'END\x00':
        break

def u32(x): return struct.pack('<I', x)
def string(s):
    data = s.encode('utf-8')
    return u32(len(data)) + data

def encode_refs(values):
    previous = 0
    words = []
    for value in values:
        delta = value - previous
        previous = value
        words.append(((delta << 1) ^ (delta >> 31)) & 0xffffffff)
    return b''.join(bytes((word >> shift) & 255 for word in words) for shift in (24, 16, 8, 0))

def decode_refs(data, offset, count):
    result = []
    prev = 0
    for i in range(count):
        word = sum(data[offset + i + count*j] << (24-8*j) for j in range(4))
        prev += (word >> 1) ^ -(word & 1)
        result.append(prev)
    return result

def chunk(tag, payload):
    return struct.pack('<4sIII', tag, 0, len(payload), 0) + payload

# Referents and service IDs checked against Place13, not arbitrary IDs in another place.
entries = [
    ('ModuleScript', 'Config', 'src/ReplicatedStorage/Config.luau', 275),
    ('ModuleScript', 'Placement', 'src/ReplicatedStorage/Placement.luau', 275),
    ('ModuleScript', 'CombatRules', 'src/ReplicatedStorage/CombatRules.luau', 275),
    ('ModuleScript', 'Towers', 'src/ReplicatedStorage/Towers.luau', 275),
    ('ModuleScript', 'Enemies', 'src/ReplicatedStorage/Enemies.luau', 275),
    ('ModuleScript', 'Waves', 'src/ReplicatedStorage/Waves.luau', 275),
    ('ModuleScript', 'MapBuilder', 'src/ServerScriptService/MapBuilder.luau', 276),
    ('ModuleScript', 'Enemy', 'src/ServerScriptService/Enemy.luau', 276),
    ('ModuleScript', 'Tower', 'src/ServerScriptService/Tower.luau', 276),
    ('Script', 'Game', 'src/ServerScriptService/Game.server.luau', 276),
    ('LocalScript', 'UI', 'src/StarterPlayer/StarterPlayerScripts/UI.client.luau', 245),
    ('LocalScript', 'Effects', 'src/StarterPlayer/StarterPlayerScripts/Effects.client.luau', 245),
    ('LocalScript', 'Ultimate', 'src/StarterPlayer/StarterPlayerScripts/Ultimate.client.luau', 245),
]
# This build is intentionally specific to the checked-in original.
assert (class_count, instance_count) == (106, 307), 'Unexpected Place13 version'
new_chunks = []
next_id = instance_count
children, parents = [], []
for class_offset, classname in enumerate(('ModuleScript', 'Script', 'LocalScript')):
    group = [e for e in entries if e[0] == classname]
    refs = list(range(next_id, next_id + len(group)))
    next_id += len(group)
    class_id = class_count + class_offset
    new_chunks.append(chunk(b'INST', u32(class_id) + string(classname) + b'\0' + u32(len(group)) + encode_refs(refs)))
    for prop, values in [('Name', [e[1] for e in group]), ('Source', [(ROOT/e[2]).read_text(encoding='utf-8') for e in group])]:
        new_chunks.append(chunk(b'PROP', u32(class_id) + string(prop) + b'\x01' + b''.join(string(v) for v in values)))
    children.extend(refs)
    parents.extend(e[3] for e in group)

struct.pack_into('<II', header, 16, class_count + 3, instance_count + len(entries))
output = bytearray(header)
for tag, payload, raw in chunks:
    if tag == b'PRNT':
        assert payload[0] == 0
        count = struct.unpack_from('<I', payload, 1)[0]
        existing_children = decode_refs(payload, 5, count)
        existing_parents = decode_refs(payload, 5 + 4 * count, count)
        assert count == instance_count and set(existing_children) == set(range(instance_count))
        output.extend(b''.join(new_chunks))
        output.extend(chunk(b'PRNT', b'\0' + u32(count + len(children)) + encode_refs(existing_children + children) + encode_refs(existing_parents + parents)))
    else:
        output.extend(raw)
(ROOT / 'ArtoTowerDefense.rbxl').write_bytes(output)
print('Built ArtoTowerDefense.rbxl with', len(entries), 'scripts')
