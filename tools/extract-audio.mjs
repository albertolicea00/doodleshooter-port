// Render the original oscillators, envelopes, filters and scores offline.
// Only the resulting audio assets are included in the native app.
import fs from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { OfflineAudioContext } from 'node-web-audio-api';
import { loadUpstream } from './upstream.mjs';
const rate = 44100;
const output = path.resolve(import.meta.dirname, '../native/assets/audio');
await fs.mkdir(output, { recursive: true });
let current, clock = 0;
const getModule = await loadUpstream({ window: { AudioContext: function () { return current; } }, setInterval: () => 0, clearInterval: () => {} }, { 'src/audio.js': '\nexport { SONG, MEXICO };' });
const source = await getModule('src/audio.js');
const metadata = { source: 'reference/upstream/src/audio.js', sample_rate: rate, music: {}, effects: {} };
function context(duration) {
  const offline = new OfflineAudioContext(2, Math.ceil(duration * rate), rate);
  clock = 0;
  current = new Proxy(offline, { get(target, key) { if (key === 'currentTime') return clock; const value = Reflect.get(target, key, target); return typeof value === 'function' ? value.bind(target) : value; } });
  const sfx = new source.audio.constructor();
  sfx.init();
  return { offline, sfx };
}
async function write(name, audio, trimStart = 0, duration = audio.duration) {
  const length = Math.round(duration * rate), first = Math.round(trimStart * rate);
  const buffer = Buffer.alloc(44 + length * 4);
  buffer.write('RIFF', 0); buffer.writeUInt32LE(buffer.length - 8, 4); buffer.write('WAVEfmt ', 8);
  buffer.writeUInt32LE(16, 16); buffer.writeUInt16LE(1, 20); buffer.writeUInt16LE(2, 22);
  buffer.writeUInt32LE(rate, 24); buffer.writeUInt32LE(rate * 4, 28); buffer.writeUInt16LE(4, 32); buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36); buffer.writeUInt32LE(length * 4, 40);
  for (let ch = 0; ch < 2; ch++) {
    const samples = audio.getChannelData(ch);
    for (let i = 0; i < length; i++) buffer.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[first + i] || 0)) * 32767), 44 + i * 4 + ch * 2);
  }
  const wav = path.join(output, `${name}.wav`);
  await fs.writeFile(wav, buffer);
  if (name.startsWith('music_')) {
    execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'vorbis', '-strict', '-2', '-b:a', '160k', path.join(output, `${name}.ogg`)]);
    await fs.unlink(wav);
  }
}
for (const key of ['district', 'mexico']) {
  const duration = key === 'district' ? source.SONG.length * 60 / 156 / 4 : source.MEXICO.length * 60 / 150 / 4;
  metadata.music[key] = { duration, variants: [] };
  for (const intensity of [0, 0.5, 1]) {
    const name = `music_${key}_${Math.round(intensity * 2)}`;
    const ogg = path.join(output, name + '.ogg');
    const wav = path.join(output, name + '.wav');
    if (await fs.stat(wav).catch(() => null)) { execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'vorbis', '-strict', '-2', '-b:a', '160k', ogg]); await fs.unlink(wav); }
    if (await fs.stat(ogg).catch(() => null)) { metadata.music[key].variants.push(name + '.ogg'); continue; }
    const { offline, sfx } = context(duration * 2 + 1);
    sfx.setTune(key); sfx.musicOn(true); sfx._mus.next = 0; sfx.setIntensity(intensity);
    for (clock = 0; clock < duration * 2; clock += 0.1) sfx._musicTick();
    await write(name, await offline.startRendering(), duration, duration);
    metadata.music[key].variants.push(name + '.ogg');
    console.log(name, duration.toFixed(3), 'seconds');
  }
}
const exclude = new Set(['constructor', 'init', 'resume', 'setListener', 'noise', 'tone', 'remoteShot', 'reelLoop', 'musicOn', 'setIntensity', 'setTune', 'musicPlaying']);
metadata.effectDurations = {};
for (const name of Object.getOwnPropertyNames(Object.getPrototypeOf(source.audio))) {
  if (name.startsWith('_') || exclude.has(name)) continue;
  const { offline, sfx } = context(2.5);
  if (typeof sfx[name] !== 'function') continue;
  if (name === 'land' || name === 'footstep') sfx[name](0.7);
  else sfx[name]();
  const rendered = await offline.startRendering();
  let lastAudible = 0;
  for (let channel = 0; channel < rendered.numberOfChannels; channel++) {
    const samples = rendered.getChannelData(channel);
    for (let i = samples.length - 1; i >= lastAudible; i--) {
      if (Math.abs(samples[i]) > 0.0005) { lastAudible = Math.max(lastAudible, i); break; }
    }
  }
  const duration = Math.min(2.5, (lastAudible + Math.round(rate * 0.12)) / rate);
  await write(name, rendered, 0, duration);
  metadata.effectDurations[name] = Number(duration.toFixed(3));
  metadata.effects[name] = name + '.wav';
}
await fs.writeFile(path.join(output, 'manifest.json'), JSON.stringify(metadata, null, 2) + '\n');
console.log('Rendered', Object.keys(metadata.effects).length, 'original effects.');
