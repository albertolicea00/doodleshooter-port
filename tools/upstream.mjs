import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
export async function loadUpstream(globals = {}, exports = {}) {
  const root = path.resolve(import.meta.dirname, '../reference/upstream');
  let seed = 8675309;
  const math = Object.create(Math);
  math.random = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);
  const context = vm.createContext({ console, Math: math, Float32Array, Uint32Array, Uint16Array, Int32Array, ArrayBuffer, setTimeout, ...globals });
  const cache = new Map();
  const files = ['vendor/three/three.module.js', 'vendor/three/addons/utils/BufferGeometryUtils.js', ...(await fs.readdir(path.join(root, 'src'))).filter(f => f.endsWith('.js')).map(f => 'src/' + f)];
  for (const relative of files) {
    const file = path.join(root, relative);
    cache.set(file, new vm.SourceTextModule((await fs.readFile(file, 'utf8')) + (exports[relative] || ''), { context, identifier: file }));
  }
  return async relative => {
    const module = cache.get(path.join(root, relative));
    if (module.status === 'unlinked') await module.link((specifier, parent) => cache.get(specifier === 'three' ? path.join(root, 'vendor/three/three.module.js') : specifier.startsWith('three/addons/') ? path.join(root, 'vendor/three/addons', specifier.slice(13)) : path.resolve(path.dirname(parent.identifier), specifier)));
    if (module.status === 'linked') await module.evaluate();
    return module.namespace;
  };
}
