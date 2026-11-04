#!/usr/bin/env python3
"""Check the rebuilt RBXL keeps the original rigs and embeds current Luau sources."""
from pathlib import Path
import struct
import zstandard

root = Path(__file__).resolve().parent.parent
f = (root / 'ArtoTowerDefense.rbxl').open('rb')
assert f.read(14) == b'<roblox!\x89\xff\r\n\x1a\n'
f.read(18)
chunks = []
while True:
    tag, compressed, uncompressed, _ = struct.unpack('<4sIII', f.read(16))
    data = f.read(compressed or uncompressed)
    if compressed:
        data = zstandard.ZstdDecompressor().decompress(data, max_output_size=uncompressed)
    chunks.append((tag, data))
    if tag == b'END\x00':
        break

def uint(d, pos): return struct.unpack_from('<I', d, pos)[0]
def string(d, pos):
    n = uint(d, pos)
    return d[pos+4:pos+4+n].decode('utf-8'), pos+4+n

def refs(d, pos, count):
    result, last = [], 0
    for i in range(count):
        value = sum(d[pos+i+count*j] << (24-8*j) for j in range(4))
        last += (value >> 1) ^ -(value & 1)
        result.append(last)
    return result, pos+4*count

classes, objects = {}, {}
for tag, data in chunks:
    if tag == b'INST':
        class_id = uint(data, 0)
        class_name, pos = string(data, 4)
        ids, _ = refs(data, pos+5, uint(data, pos+1))
        classes[class_id] = (class_name, ids)
        for ref in ids:
            objects[ref] = {'class': class_name}
for tag, data in chunks:
    if tag == b'PROP':
        class_id = uint(data, 0)
        property_name, pos = string(data, 4)
        if property_name in ('Name', 'Source') and data[pos] == 1:
            pos += 1
            for ref in classes[class_id][1]:
                value, pos = string(data, pos)
                objects[ref][property_name] = value
    elif tag == b'PRNT':
        count = uint(data, 1)
        children, pos = refs(data, 5, count)
        parents, _ = refs(data, pos, count)
        for child, parent in zip(children, parents):
            objects[child]['parent'] = parent
for name in ('dibil1488777', 'ZamestitelDiomchica', 'silv3r_candy', 'eurtyoeyrntiu'):
    assert any(o.get('Name') == name and o['class'] == 'Model' and o['parent'] == 0 for o in objects.values()), name
for ref, obj in objects.items():
    if obj.get('Source') and obj['class'] in ('Script', 'LocalScript', 'ModuleScript'):
        name = obj['Name']
        if obj['class'] == 'LocalScript':
            path = root / f'src/StarterPlayer/StarterPlayerScripts/{name}.client.luau'
            assert obj['parent'] == 245
        elif obj['class'] == 'Script':
            path = root / f'src/ServerScriptService/{name}.server.luau'
            assert obj['parent'] == 276
        elif obj['parent'] == 275:
            path = root / f'src/ReplicatedStorage/{name}.luau'
        else:
            assert obj['parent'] == 276
            path = root / f'src/ServerScriptService/{name}.luau'
        assert obj['Source'] == path.read_text(encoding='utf-8'), path
expected = {'Config','Placement','Towers','Enemies','Waves','MapBuilder','Enemy','Tower','Game','UI','Effects'}
found = {o.get('Name') for o in objects.values() if o.get('Source') and o['class'] in ('Script','LocalScript','ModuleScript')}
assert found == expected, (found, expected)
print('OK: four source rigs and 11 matching scripts with correct parents')
