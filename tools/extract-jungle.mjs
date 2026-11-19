// Build-time conversion of the deployed original Doodle Jungle map.
// Preserve reference/upstream: Jungle is absent from that historical snapshot.
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import { createHash } from 'node:crypto';
const root = path.resolve(import.meta.dirname, '..');
const reference = path.join(root, 'reference/web-2026-11-19');
const manifest = JSON.parse(await fs.readFile(path.join(reference, 'manifest.json'), 'utf8'));
const source = await fs.readFile(path.join(reference, 'game.7LCERBLR.js'), 'utf8');
if (createHash('sha256').update(source).digest('hex') !== manifest.files_sha256['game.7LCERBLR.js']) throw new Error('Deployed reference hash mismatch');
// Stop after the level builder, before any browser game initialization.
const boundary = source.indexOf('import*as Ut from"three";', source.indexOf('function Bo('));
if (boundary < 0) throw new Error('Level module boundary not found');
let seed = 8675309;
const math = Object.create(Math);
math.random = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);
const context = vm.createContext({ console, Math: math, Float32Array, Uint32Array, Uint16Array, Int32Array, ArrayBuffer, setTimeout });
const three = new vm.SourceTextModule(await fs.readFile(path.join(root, 'reference/upstream/vendor/three/three.module.js'), 'utf8'), { context });
const merge = new vm.SourceTextModule(await fs.readFile(path.join(root, 'reference/upstream/vendor/three/addons/utils/BufferGeometryUtils.js'), 'utf8'), { context });
// Record the parameters captured by the original animation closures without changing the snapshot.
let levelSource = source.slice(0, boundary);
function instrument(before, after) {
  if (levelSource.split(before).length !== 2) throw new Error('Animation instrumentation changed: ' + before);
  levelSource = levelSource.replace(before, after);
}
instrument('e.grappleMovers.push({mesh:lt,radius:1.3});', 'e.grappleMovers.push({mesh:lt,radius:1.3});(e.nativeAnimations??=[]).push({type:"vine",mesh:lt,rope:ct,anchor:[m,E,z],length:_,phase:H,yaw:J});');
instrument('s.animated.push({mesh:G,update:kt=>{', '(s.nativeAnimations??=[]).push({type:"bird",mesh:G,radius:dt,height:R,phase:j,speed:W,direction:U});s.animated.push({mesh:G,update:kt=>{');
instrument('e.animated.push({mesh:H,update:J=>{H.scale.set', '(e.nativeAnimations??=[]).push({type:"flame",mesh:H,x:m,z:z});e.animated.push({mesh:H,update:J=>{H.scale.set');
const deployed = new vm.SourceTextModule(levelSource + '\nexport { Bo as buildLevel };', { context });
const resolve = name => {
  if (name === 'three') return three;
  if (name === 'three/addons/utils/BufferGeometryUtils.js') return merge;
  throw new Error('Unexpected import: ' + name);
};
await deployed.link(resolve);
await deployed.evaluate();
const THREE = three.namespace;
function geometry(g) {
  const non = g.index ? g.toNonIndexed() : g;
  const p = non.getAttribute('position'), n = non.getAttribute('normal');
  const vertices = [], normals = [];
  for (let i = 0; i < p.count; i += 3) for (const j of [i, i + 2, i + 1]) {
    vertices.push(...[p.getX(j), p.getY(j), p.getZ(j)].map(v => Number(v.toFixed(5))));
    normals.push(...[n.getX(j), n.getY(j), n.getZ(j)].map(v => Number(v.toFixed(5))));
  }
  return { vertices, normals };
}
function nodeData(o) {
  return { name: o.name || o.type, position: o.position.toArray(), quaternion: o.quaternion.toArray(), scale: o.scale.toArray(), visible: o.visible,
    ...(o.isMesh ? { mesh: geometry(o.geometry), ink: o.material.inkId ?? 0, fill: o.material.uniforms?.uFill?.value === 1, shade: [o.material.uniforms?.uShadeScale?.value ?? 1, o.material.uniforms?.uShadeBias?.value ?? 0] } : {}), children: o.children.map(nodeData) };
}
for (const arena of [false, true]) {
  seed = 8675309;
  const scene = new THREE.Scene();
  const boxes = [];
  const world = { addBox(min, max, data) { const b = { min, max, data }; boxes.push(b); return b; }, finalize() {} };
  const level = deployed.namespace.buildLevel(scene, world, 'jungle', { arena });
  for (const animated of level.animated) animated.update(0);
  const result = { key: 'jungle', arena, bounds: level.bounds, style: level.style,
    player_start: level.playerStart.toArray(), spawns: level.spawns.map(v => v.toArray()), snipers: level.snipers.map(v => v.toArray()), pickups: level.pickups.map(v => v.toArray()), arena_spawns: level.arenaSpawns.map(v => v.toArray()), rings: level.rings.map(v => v.toArray()),
    boxes: boxes.map(b => ({ min: Object.values(b.min), max: Object.values(b.max), no_grapple: !!b.data.noGrapple, no_shoot: !!b.data.noShoot, breakable: b.data.breakable?.id ?? -1 })),
    children: scene.children.map(nodeData), breakables: level.breakables.map(b => ({ id: b.id, kind: b.kind, hp: b.hp, node: scene.children.indexOf(b.group), position: b.pos.toArray() })),
    movers: [],
    grapple_targets: level.grappleMovers.map(m => ({ node: scene.children.indexOf(m.mesh), radius: m.radius })),
    animations: (level.nativeAnimations || []).map(({mesh, rope, ...params}) => ({ ...params, node: scene.children.indexOf(mesh), ...(rope ? {rope: scene.children.indexOf(rope)} : {}) })) };
  if (result.animations.length !== level.animated.length) throw new Error('Unconverted Jungle animation');
  if (result.grapple_targets.some(target => target.node < 0) || result.animations.some(animation => animation.node < 0)) throw new Error('Invalid Jungle node index');
  if (!arena) {
    const samples = [0, 1.25, 7].map(time => {
      for (const animation of level.animated) animation.update(time);
      return { time, nodes: (level.nativeAnimations || []).map(({mesh, rope}) => ({ node: scene.children.indexOf(mesh), position: mesh.position.toArray(), quaternion: mesh.quaternion.toArray(), scale: mesh.scale.toArray(), ...(rope ? { rope_position: rope.position.toArray(), rope_quaternion: rope.quaternion.toArray(), rope_scale: rope.scale.toArray() } : {}), children: mesh.children.map(child => ({quaternion:child.quaternion.toArray()})) })) };
    });
    await fs.writeFile(path.join(root, 'tests/jungle_motion.json'), JSON.stringify(samples));
  }
  const name = `jungle${arena ? '_arena' : ''}`;
  await fs.writeFile(path.join(root, 'native/data', name + '.json'), JSON.stringify(result));
  console.log(name, boxes.length, 'colliders', scene.children.length, 'nodes', level.animated.length, 'animations', result.grapple_targets.length, 'grapple targets', result.animations.length, 'native animations');
}
