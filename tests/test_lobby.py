import asyncio
import json
import time
import unittest
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
from server.lobby import Lobby

class LobbyTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.lobby = Lobby()
        self.server = await serve(self.lobby.connection, '127.0.0.1', 0)
        self.url = f'ws://127.0.0.1:{self.server.sockets[0].getsockname()[1]}'
        self.clients = []

    async def asyncTearDown(self):
        for client in self.clients:
            await client.close()
        self.server.close()
        await self.server.wait_closed()

    async def client(self):
        client = await connect(self.url)
        self.clients.append(client)
        welcome = await self.receive(client, 'welcome')
        return client, welcome['id']

    async def send(self, client, kind, **fields):
        await client.send(json.dumps({'type': kind, **fields}))

    async def receive(self, client, kind):
        async with asyncio.timeout(3):
            while True:
                packet = json.loads(await client.recv())
                if packet['type'] == kind:
                    return packet

    async def pair(self):
        host, host_id = await self.client()
        await self.send(host, 'host', public=True)
        room = await self.receive(host, 'lobby')
        guest, guest_id = await self.client()
        await self.send(guest, 'join', code=room['code'])
        await self.receive(guest, 'lobby')
        return host, host_id, guest, guest_id, room['code']

    async def test_private_capacity_and_host_migration(self):
        host, host_id = await self.client()
        await self.send(host, 'host', public=False)
        info = await self.receive(host, 'lobby')
        self.assertEqual(len(info['code']), 5)
        for i in range(9):
            guest, _ = await self.client()
            await self.send(guest, 'join', code=info['code'])
            result = await self.receive(guest, 'lobby')
            self.assertEqual(len(result['players']), i + 2)
        extra, _ = await self.client()
        await self.send(extra, 'join', code=info['code'])
        self.assertIn('full', (await self.receive(extra, 'error'))['message'])
        await self.send(extra, 'list')
        self.assertEqual((await self.receive(extra, 'rooms'))['rooms'], [])
        await host.close()
        for _ in range(20):
            if self.lobby.rooms[info['code']].host != host_id:
                break
            await asyncio.sleep(0.01)
        self.assertNotEqual(self.lobby.rooms[info['code']].host, host_id)

    async def test_quick_play_late_join_damage_and_respawn(self):
        host, host_id, guest, guest_id, code = await self.pair()
        await self.send(guest, 'start')
        await self.receive(host, 'start')
        await self.receive(guest, 'start')
        late, _ = await self.client()
        await self.send(late, 'quick')
        self.assertTrue((await self.receive(late, 'start'))['late'])
        self.assertEqual(len(self.lobby.rooms[code].players), 3)
        victim = self.lobby.players[guest_id]
        victim.shield = 0
        await self.send(host, 'damage', target=guest_id, source='sniper', amount=999999)
        packet = await self.receive(guest, 'damage')
        self.assertEqual(packet['amount'], 225)
        self.assertEqual(packet['hp'], 0)
        kill = await self.receive(host, 'kill')
        self.assertEqual(kill['killer'], host_id)
        self.assertEqual(self.lobby.players[host_id].kills, 1)
        victim.died = time.monotonic() - 3
        await self.send(guest, 'respawn')
        self.assertEqual((await self.receive(guest, 'respawn'))['shield'], 2)
        self.assertEqual(victim.hp, 120)

    async def test_state_relay_and_invalid_coordinates(self):
        host, _, guest, _, _ = await self.pair()
        await self.send(host, 'start')
        await self.receive(guest, 'start')
        state = {'position': [1, 2, 3], 'rotation': [0, 0, 0], 'velocity': [0, 0, 0], 'grapple': [0, 10, 0], 'weapon': 0, 'grappling': True}
        await self.send(host, 'state', state=state)
        relay = await self.receive(guest, 'state')
        self.assertEqual(relay['state']['position'], [1, 2, 3])
        self.assertEqual(relay['state']['hp'], 120)
        await host.send('{broken json')
        self.assertEqual((await self.receive(host, 'error'))['message'], 'Invalid message.')
        state['position'] = [10000, 0, 0]
        await self.send(host, 'state', state=state)
        await asyncio.sleep(0.02)
        member = next(p for p in self.lobby.players.values() if p.socket.remote_address == host.local_address)
        self.assertEqual(member.state['position'], [1, 2, 3])

    async def test_twenty_kills_end_match(self):
        host, host_id, guest, guest_id, code = await self.pair()
        await self.send(host, 'start')
        await self.receive(host, 'start')
        await self.receive(guest, 'start')
        attacker, victim = self.lobby.players[host_id], self.lobby.players[guest_id]
        attacker.kills = 19
        victim.shield = 0
        await self.send(host, 'damage', target=guest_id, source='sniper', amount=150)
        result = await self.receive(host, 'result')
        self.assertEqual(result['players'][0]['kills'], 20)
        self.assertTrue(self.lobby.rooms[code].ended)

    async def test_finished_rooms_cannot_be_joined_or_listed(self):
        host, _, _, _, code = await self.pair()
        await self.lobby.finish(self.lobby.rooms[code])
        newcomer, _ = await self.client()
        await self.send(newcomer, 'join', code=code)
        self.assertIn('finished', (await self.receive(newcomer, 'error'))['message'])
        await self.send(host, 'list')
        self.assertEqual((await self.receive(host, 'rooms'))['rooms'], [])
        await self.send(newcomer, 'quick')
        self.assertNotEqual((await self.receive(newcomer, 'lobby'))['code'], code)

    async def test_grenade_shield_and_self_kill_scoring(self):
        host, host_id, guest, guest_id, code = await self.pair()
        await self.send(host, 'start')
        await self.receive(host, 'start')
        await self.receive(guest, 'start')
        attacker, victim = self.lobby.players[host_id], self.lobby.players[guest_id]
        attacker.state = {'position': [0, 0, 0]}
        victim.state = {'position': [0, 0, 0]}
        attacker.shield = 0
        attacker.hp = 10
        await self.send(host, 'blast', position=[0, 0, 0])
        self.assertEqual((await self.receive(host, 'damage'))['hp'], 0)
        kill = await self.receive(host, 'kill')
        self.assertEqual(kill['victim'], host_id)
        self.assertEqual(attacker.deaths, 1)
        self.assertEqual(attacker.kills, 0)
        self.assertEqual(victim.hp, 120, 'Spawn shield must also block grenades')
        self.assertFalse(self.lobby.rooms[code].ended)

if __name__ == '__main__':
    unittest.main()
