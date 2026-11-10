// Offline build-time conversion only. The native application does not run JavaScript.
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
const root = path.resolve(import.meta.dirname, '../reference/upstream');
const output = path.resolve(import.meta.dirname, '../native/data');
await fs.mkdir(output, { recursive: true });
let seed = 8675309;
const math = Object.create(Math);
math.random = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);
const context = vm.createContext({ console, Math: math, Float32Array, Uint32Array, Uint16Array, Int32Array, ArrayBuffer, setTimeout });
const cache = new Map();
const files = ['vendor/three/three.module.js', 'vendor/three/addons/utils/BufferGeometryUtils.js', ...(await fs.readdir(path.join(root, 'src'))).filter(f => f.endsWith('.js')).map(f => 'src/' + f)];
for (const relative of files) {
  const file = path.join(root, relative);
  cache.set(file, new vm.SourceTextModule((await fs.readFile(file, 'utf8')) + (relative === 'src/enemies.js' ? '\nexport { buildBomber, buildFlyer };' : ''), { context, identifier: file }));
}
async function moduleFor(file) {
  const mod = cache.get(file);
  if (mod.status === 'unlinked') await mod.link((specifier, parent) => cache.get(specifier === 'three' ? path.join(root, 'vendor/three/three.module.js') : specifier.startsWith('three/addons/') ? path.join(root, 'vendor/three/addons', specifier.slice(13)) : path.resolve(path.dirname(parent.identifier), specifier)));
  return mod;
}
const levelModule = await moduleFor(path.join(root, 'src/level.js'));
await levelModule.evaluate();
const THREE = cache.get(path.join(root, 'vendor/three/three.module.js')).namespace;
const render = cache.get(path.join(root, 'src/render.js')).namespace;
function geometry(g) {
  const non = g.index ? g.toNonIndexed() : g;
  const p = non.getAttribute('position'), n = non.getAttribute('normal');
  // Reverse triangle winding: Three.js CCW -> Godot clockwise.
  const vertices = [], normals = [];
  for (let i = 0; i < p.count; i += 3) for (const j of [i, i + 2, i + 1]) {
    vertices.push(p.getX(j), p.getY(j), p.getZ(j));
    normals.push(n.getX(j), n.getY(j), n.getZ(j));
  }
  return { vertices, normals };
}
function nodeData(o) {
  return { name: o.name || o.type, position: o.position.toArray(), quaternion: o.quaternion.toArray(), scale: o.scale.toArray(), visible: o.visible,
    ...(o.isMesh ? { mesh: geometry(o.geometry), ink: o.material.inkId ?? 0, fill: o.material.uniforms?.uFill?.value === 1 } : {}), children: o.children.map(nodeData) };
}
for (const key of ['district', 'mexico']) for (const arena of [false, true]) {
  const scene = new THREE.Scene();
  const boxes = [];
  const world = { addBox(min, max, data) { const b = { min, max, data }; boxes.push(b); return b; }, finalize() {} };
  const level = levelModule.namespace.buildLevel(scene, world, key, { arena });
  for (const a of level.animated) a.update(0);
  const result = { key, arena, player_start: level.playerStart.toArray(), spawns: level.spawns.map(v => v.toArray()), snipers: level.snipers.map(v => v.toArray()), pickups: level.pickups.map(v => v.toArray()), arena_spawns: level.arenaSpawns.map(v => v.toArray()), rings: level.rings.map(v => v.toArray()),
    boxes: boxes.map(b => ({ min: Object.values(b.min), max: Object.values(b.max), no_grapple: !!b.data.noGrapple, no_shoot: !!b.data.noShoot, breakable: b.data.breakable?.id ?? -1 })),
    children: scene.children.map(nodeData), breakables: level.breakables.map(b => ({ id: b.id, kind: b.kind, hp: b.hp, node: scene.children.indexOf(b.group), position: b.pos.toArray() })),
    movers: level.grappleMovers.map(m => scene.children.indexOf(m.mesh)) };
  const name = `${key}${arena ? '_arena' : ''}`;
  await fs.writeFile(path.join(output, `${name}.json`), JSON.stringify(result));
  console.log(name, boxes.length, 'colliders', scene.children.length, 'nodes');
}
const enemyModule = cache.get(path.join(root, 'src/enemies.js'));
const models = {};
for (const [key, type] of Object.entries(enemyModule.namespace.TYPES)) {
  const builder = type.model === 'flyer' ? enemyModule.namespace.buildFlyer : type.model ? enemyModule.namespace.buildBomber : enemyModule.namespace.buildHumanoid;
  const model = builder(render.makeInkMaterial({ ink: type.ink ?? 1 }), render.makeInkMaterial({ ink: type.ink ?? 1, fill: true }), type, type.model === 'blob');
  for (const [joint, node] of Object.entries(model.J)) if (node) node.name = joint;
  // Some models alias head and torso; name only the parts used for hits.
  for (const [part] of model.hit) model.parts[part].name = "hit_" + part;
  models[key] = { ...nodeData(model.root), hit_spheres: model.hit };
}
await fs.writeFile(path.join(output, 'enemies.json'), JSON.stringify(models));
const englishNames = { grunt: 'Grunt', rusher: 'Rusher', bomber: 'Bomber', sniper: 'Sniper', flyer: 'Flyer', heavy: 'Heavy', shield: 'Shield Bearer', boss: 'The Doodler', eraser: 'The Eraser', inkblot: 'The Inkblot' };
const stats = Object.fromEntries(Object.entries(enemyModule.namespace.TYPES).map(([key, value]) => [key, { ...value, name: englishNames[key] }]));
await fs.writeFile(path.join(output, 'enemy_stats.json'), JSON.stringify(stats));
const weaponsModule = await moduleFor(path.join(root, 'src/weapons.js'));
await weaponsModule.evaluate();
const weapons = {};
for (const key of ['Rifle', 'Shotgun', 'Sniper', 'Katana']) {
  const w = new weaponsModule.namespace[key]({});
  w.root.visible = true;
  weapons[key.toLowerCase()] = { model: nodeData(w.root), position: w.basePos.toArray(), aim_position: w.aimPos.toArray(), damage: w.damage ?? 80, magazine: w.magSize ?? 0, reserve: w.reserve ?? 0, interval: w.interval ?? 0.4, reload: w.reloadDur ?? 0, pellets: w.pellets ?? 1, spread: w.spread ?? 0, ads_spread: w.adsSpread ?? 0, fov: w.adsFov ?? 65 };
}
await fs.writeFile(path.join(output, 'weapons.json'), JSON.stringify(weapons));
console.log('Enemy and weapon models converted.');
