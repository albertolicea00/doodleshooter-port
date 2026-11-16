"""Native lobby relay and FFA authority. Bind locally unless explicitly configured."""
import asyncio
from dataclasses import dataclass, field
import json
import math
import os
import secrets
import time
from websockets.asyncio.server import serve

ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'  # pragma: allowlist secret (lobby code alphabet)
MAPS = ('district', 'mexico', 'castle', 'harbor', 'pyramid', 'station', 'forest', 'school', 'military')
DAMAGE = {'rifle': (19, 1.8), 'shotgun': (16, 1.6), 'sniper': (150, 1.5), 'katana': (55, 1), 'revolver': (48, 1.6), 'smg': (12, 1.6), 'grenade': (62, 1), 'deflect': (90, 1)}
INTERVAL = {'rifle': 1 / 11, 'shotgun': 0.78, 'sniper': 0.85, 'katana': 0.33, 'revolver': 0.3, 'smg': 1 / 15, 'grenade': 0.7, 'deflect': 0.19}

@dataclass(eq=False)
class Player:
    socket: object
    id: str = field(default_factory=lambda: secrets.token_hex(6))
    name: str = 'Doodler'
    room: object = None
    hp: float = 120
    kills: int = 0
    deaths: int = 0
    shield: float = 0
    died: float = 0
    hurt: float = 0
    activity: float = field(default_factory=time.monotonic)
    state: dict = field(default_factory=dict)
    fire_times: dict = field(default_factory=dict)
    broken: set = field(default_factory=set)

@dataclass
class Room:
    code: str
    host: str
    public: bool
    map: str = 'district'
    players: dict = field(default_factory=dict)
    started: bool = False
    clock: float = 0
    ended: bool = False
    broken: set = field(default_factory=set)

class Lobby:
    def __init__(self):
        self.rooms = {}
        self.players = {}

    async def send(self, player, kind, **data):
        try:
            await player.socket.send(json.dumps({'type': kind, **data}, separators=(',', ':')))
        except Exception:
            pass

    async def broadcast(self, room, kind, exclude=None, **data):
        await asyncio.gather(*(self.send(p, kind, **data) for p in list(room.players.values()) if p.id != exclude))

    def roster(self, room):
        return [{'id': p.id, 'name': p.name, 'hp': p.hp, 'kills': p.kills, 'deaths': p.deaths} for p in room.players.values()]

    async def info(self, room):
        await self.broadcast(room, 'lobby', code=room.code, host=room.host, public=room.public, map=room.map, started=room.started, players=self.roster(room))

    async def leave(self, player):
        room = player.room
        if not room:
            return
        room.players.pop(player.id, None)
        player.room = None
        if not room.players:
            self.rooms.pop(room.code, None)
            return
        if room.host == player.id:
            room.host = next(iter(room.players))
        await self.broadcast(room, 'left', id=player.id)
        await self.info(room)

    async def join(self, player, room):
        if room.ended:
            return await self.send(player, 'error', message='That match has finished. Join another lobby.')
        if len(room.players) >= 10:
            return await self.send(player, 'error', message='That lobby is full (10 players).')
        await self.leave(player)
        room.players[player.id] = player
        player.room = room
        player.hp, player.kills, player.deaths = 120, 0, 0
        player.activity = time.monotonic()
        player.state = {}
        await self.info(room)
        if room.started:
            player.shield = time.monotonic() + 2
            await self.send(player, 'start', map=room.map, late=True, spawn=len(room.players) - 1, broken=sorted(room.broken))

    async def handle(self, player, message):
        kind = message.get('type')
        now = time.monotonic()
        if kind == 'name':
            player.name = ''.join(c for c in str(message.get('name', 'Doodler')) if c.isprintable())[:24] or 'Doodler'
            return
        if kind == 'list':
            return await self.send(player, 'rooms', rooms=[{'code': r.code, 'map': r.map, 'players': len(r.players), 'started': r.started, 'host': r.players[r.host].name} for r in self.rooms.values() if r.public and not r.ended])
        if kind in ('host', 'quick'):
            if kind == 'quick':
                rooms = sorted((r for r in self.rooms.values() if r.public and len(r.players) < 10 and not r.ended), key=lambda r: -len(r.players))
                if rooms:
                    return await self.join(player, rooms[0])
            code = ''.join(secrets.choice(ALPHABET) for _ in range(5))
            while code in self.rooms:
                code = ''.join(secrets.choice(ALPHABET) for _ in range(5))
            room = Room(code, player.id, bool(message.get('public', kind == 'quick')), message.get('map') if message.get('map') in MAPS else 'district')
            self.rooms[code] = room
            return await self.join(player, room)
        if kind == 'join':
            room = self.rooms.get(str(message.get('code', '')).strip().upper())
            if room:
                return await self.join(player, room)
            return await self.send(player, 'error', message='Lobby not found. Check its five-character code.')
        if kind == 'leave':
            await self.leave(player)
            return await self.send(player, 'left_room')
        room = player.room
        if not room:
            return
        if kind == 'map' and player.id == room.host and not room.started:
            room.map = message.get('map') if message.get('map') in MAPS else 'district'
            return await self.info(room)
        if kind == 'start' and not room.started:
            room.started, room.ended, room.clock = True, False, 0
            for index, member in enumerate(room.players.values()):
                member.hp, member.kills, member.deaths, member.shield = 120, 0, 0, now + 2
                await self.send(member, 'start', map=room.map, spawn=index, late=False, broken=[])
            return
        if not room.started or room.ended:
            return
        if kind == 'activity':
            player.activity = now
        elif kind == 'state':
            state = message.get('state', {})
            if not isinstance(state, dict):
                return
            for field_name in ('position', 'rotation', 'velocity', 'grapple'):
                value = state.get(field_name, [0, 0, 0])
                if not isinstance(value, list) or len(value) != 3 or not all(isinstance(x, (int, float)) and math.isfinite(x) and abs(x) < 1000 for x in value):
                    return
            if any(not isinstance(state.get(k, False), bool) for k in ('grappling', 'aiming', 'sprinting')) or not isinstance(state.get('weapon', 0), int) or state.get('weapon', 0) not in range(6):
                return
            player.state = {k: state.get(k) for k in ('position', 'rotation', 'velocity', 'grapple', 'grappling', 'aiming', 'sprinting', 'weapon')}
            player.state.update(id=player.id, hp=player.hp, alive=player.hp > 0)
            await self.broadcast(room, 'state', exclude=player.id, state=player.state)
        elif kind == 'damage':
            victim = room.players.get(str(message.get('target')))
            source = str(message.get('source'))
            if not victim or victim == player or victim.hp <= 0 or player.hp <= 0 or victim.shield > now or source not in DAMAGE:
                return
            if now - player.fire_times.get(source, 0) < INTERVAL[source] * 0.85:
                return
            player.fire_times[source] = now
            requested = message.get('amount', 0)
            if not isinstance(requested, (int, float)) or not math.isfinite(requested):
                return
            base, head = DAMAGE[source]
            maximum = base * head * (10 if source == 'shotgun' else 1)
            amount = min(max(0, requested), maximum)
            victim.hp = max(0, victim.hp - amount)
            victim.hurt = now
            await self.send(victim, 'damage', amount=amount, hp=victim.hp, by=player.id, source=source)
            if victim.hp <= 0:
                victim.died = now
                victim.deaths += 1
                player.kills += 1
                await self.broadcast(room, 'kill', victim=victim.id, killer=player.id, source=source, players=self.roster(room))
                if player.kills >= 20:
                    await self.finish(room)
        elif kind == 'respawn' and player.hp <= 0 and now - player.died >= 2.5:
            player.hp, player.shield = 120, now + 2
            await self.send(player, 'respawn', shield=2, spawn=secrets.randbelow(16))
        elif kind == 'shot' and player.hp > 0:
            end = message.get('end', [0, 0, 0])
            weapon = message.get('weapon', 0)
            if not isinstance(end, list) or len(end) != 3 or not all(isinstance(x, (int, float)) and math.isfinite(x) and abs(x) < 1000 for x in end) or not isinstance(weapon, int) or weapon not in range(6):
                return
            await self.broadcast(room, 'shot', exclude=player.id, id=player.id, weapon=weapon, end=end)
        elif kind == 'grenade' and player.hp > 0:
            position, velocity = message.get('position'), message.get('velocity')
            valid = lambda value, limit: isinstance(value, list) and len(value) == 3 and all(isinstance(x, (int, float)) and math.isfinite(x) and abs(x) < limit for x in value)
            if not valid(position, 1000) or not valid(velocity, 100):
                return
            await self.broadcast(room, 'grenade', exclude=player.id, id=player.id, position=position, velocity=velocity)
        elif kind == 'blast' and player.hp > 0:
            position = message.get('position')
            if not isinstance(position, list) or len(position) != 3 or not all(isinstance(x, (int, float)) and math.isfinite(x) and abs(x) < 1000 for x in position):
                return
            if now - player.fire_times.get('grenade', 0) < INTERVAL['grenade'] * 0.85:
                return
            own_position = player.state.get('position')
            if not own_position or math.dist(position, own_position) > 75:
                return
            player.fire_times['grenade'] = now
            for victim in list(room.players.values()):
                target = victim.state.get('position')
                if not target or victim.hp <= 0 or victim.shield > now:
                    continue
                distance = math.dist(position, target)
                if distance >= 6.4:
                    continue
                amount = min(62, max(0, 62 * (1 - distance / 6.4)))
                victim.hp = max(0, victim.hp - amount)
                victim.hurt = now
                await self.send(victim, 'damage', amount=amount, hp=victim.hp, by=player.id, source='grenade')
                if victim.hp <= 0:
                    victim.died = now
                    victim.deaths += 1
                    if victim != player:
                        player.kills += 1
                    await self.broadcast(room, 'kill', victim=victim.id, killer=player.id, source='grenade', players=self.roster(room))
                    if player.kills >= 20:
                        await self.finish(room)
                        break
        elif kind == 'broken':
            prop = message.get('id')
            if isinstance(prop, int) and 0 <= prop < 128:
                room.broken.add(prop)
                await self.broadcast(room, 'broken', exclude=player.id, id=prop)

    async def finish(self, room):
        room.ended = True
        await self.broadcast(room, 'result', players=sorted(self.roster(room), key=lambda p: (-p['kills'], p['deaths'])))

    async def tick(self):
        previous = time.monotonic()
        last_status = previous
        while True:
            await asyncio.sleep(0.1)
            now = time.monotonic()
            delta, previous = now - previous, now
            for room in list(self.rooms.values()):
                if not room.started or room.ended:
                    continue
                if len(room.players) >= 2:
                    room.clock += delta
                for member in list(room.players.values()):
                    if now - member.activity > 150:
                        await self.send(member, 'idle', message='Removed after 150 seconds without input.', code=room.code)
                        await self.leave(member)
                        continue
                    if 0 < member.hp < 120 and now - member.hurt > 4.5 and not member.state.get('sprinting'):
                        member.hp = min(120, member.hp + 11 * delta)
                if room.clock >= 600:
                    await self.finish(room)
                elif now - last_status >= 1:
                    await self.broadcast(room, 'clock', remaining=max(0, math.ceil(600 - room.clock)), players=self.roster(room))
            if now - last_status >= 1:
                last_status = now

    async def connection(self, socket):
        player = Player(socket)
        self.players[player.id] = player
        await self.send(player, 'welcome', id=player.id)
        try:
            async for raw in socket:
                try:
                    message = json.loads(raw)
                    if isinstance(message, dict):
                        await self.handle(player, message)
                except (ValueError, TypeError, KeyError):
                    await self.send(player, 'error', message='Invalid message.')
        finally:
            await self.leave(player)
            self.players.pop(player.id, None)

async def main():
    lobby = Lobby()
    async with serve(lobby.connection, os.environ.get('DOODLE_BIND', '127.0.0.1'), int(os.environ.get('DOODLE_PORT', '8911')), max_size=16384, ping_interval=20, ping_timeout=20):
        print('Doodle native lobby listening on port ' + os.environ.get('DOODLE_PORT', '8911'), flush=True)
        await lobby.tick()

if __name__ == '__main__':
    asyncio.run(main())
