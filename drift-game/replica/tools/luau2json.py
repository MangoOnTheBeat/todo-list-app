# Converts the Roblox game's data modules (CourseData, Cars, CarMeshes/*) into JSON for the browser replica.
# A tiny parser for Luau table literals: numbers, strings, true/false/nil, nested tables with `key = value`,
# table.concat({...}) and Color3.fromHex("...") (kept as "#rrggbb").
import json, re, sys, os

TOK = re.compile(r'\s*(?:--\[\[.*?\]\]|--[^\n]*\n|(?P<num>-?\d+\.?\d*(?:[eE][-+]?\d+)?)|(?P<str>"(?:[^"\\]|\\.)*")|(?P<name>[A-Za-z_][A-Za-z0-9_.]*)|(?P<sym>[{}=,();\[\]]))', re.S)
def tokens(src):
    pos = 0
    out = []
    while pos < len(src):
        m = TOK.match(src, pos)
        if not m or m.end() == pos:
            if src[pos:].strip() == '': break
            raise SyntaxError('at ' + src[pos:pos + 60])
        pos = m.end()
        for k in ('num', 'str', 'name', 'sym'):
            if m.group(k) is not None: out.append((k, m.group(k))); break
    return out

class P:
    def __init__(s, t): s.t, s.i = t, 0
    def peek(s, o=0): return s.t[s.i + o] if s.i + o < len(s.t) else (None, None)
    def take(s, v=None):
        k, x = s.t[s.i]; s.i += 1
        if v is not None and x != v: raise SyntaxError(f'expected {v} got {x}')
        return x
    def value(s):
        k, x = s.peek()
        if k == 'num': s.i += 1; return float(x) if ('.' in x or 'e' in x.lower()) else int(x)
        if k == 'str': s.i += 1; return json.loads(x)
        if x == '{': return s.table()
        if k == 'name':
            s.i += 1
            if x == 'true': return True
            if x == 'false': return False
            if x == 'nil': return None
            if x in ('table.concat', 'Color3.fromHex'):
                s.take('('); v = s.value(); s.take(')')
                if x == 'table.concat': return ''.join(v)
                return '#' + v.lstrip('#').lower()
            if x == 'Color3.fromRGB' or x == 'Color3.new':
                s.take('('); a = [s.value()]
                while s.peek()[1] == ',': s.take(','); a.append(s.value())
                s.take(')')
                if x == 'Color3.new': a = [round(c * 255) for c in a]
                return '#%02x%02x%02x' % tuple(int(c) for c in a)
            raise SyntaxError('unknown name ' + x)
        raise SyntaxError(f'bad value {x}')
    def table(s):
        s.take('{'); arr, d = [], {}
        while s.peek()[1] != '}':
            k, x = s.peek()
            if k == 'name' and s.peek(1)[1] == '=':
                s.i += 2; d[x] = s.value()
            elif x == '[':
                s.take('['); key = s.value(); s.take(']'); s.take('='); d[str(key)] = s.value()
            else: arr.append(s.value())
            if s.peek()[1] in (',', ';'): s.i += 1
        s.take('}')
        if d and arr: d['_array'] = arr; return d
        return d if d else arr

def module_value(path):
    src = open(path, encoding='utf-8').read()
    src = src[src.index('return') + 6:]
    return P(tokens(src)).value()

if __name__ == '__main__':
    root, out = sys.argv[1], sys.argv[2]
    data = {'course': module_value(os.path.join(root, 'CourseData.luau')), 'cars': module_value(os.path.join(root, 'Cars.luau'))}
    meshes = {}
    md = os.path.join(root, 'CarMeshes')
    for f in sorted(os.listdir(md)):
        if f.endswith('.luau') and not f.startswith('_'): meshes[f[:-5]] = module_value(os.path.join(md, f))
    open(os.path.join(out, 'game.json'), 'w').write(json.dumps(data, separators=(',', ':')))
    open(os.path.join(out, 'carmeshes.json'), 'w').write(json.dumps(meshes, separators=(',', ':')))
    c = data['course']
    print('course keys', list(c.keys()), 'points', len(c['POINTS']) // 4, 'cells', len(c['CELLS']) // 4, 'lakes', len(c['LAKES']) // 2, 'cars', len(data['cars']), 'meshes', list(meshes))
