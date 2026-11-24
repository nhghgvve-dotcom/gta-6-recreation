# Coastline Online relay

This small WebSocket relay lets Coastline clients on Windows, Android and Meta Quest share a room over the internet.

## Deploy

1. Open the Render Blueprint deployment page: https://render.com/deploy
2. Connect the `nhghgvve-dotcom/gta-6-recreation` GitHub repository.
3. Render reads the root `render.yaml`. Choose the free web-service plan and deploy.
4. After deployment, copy the service's HTTPS address, for example `https://coastline-online-game.onrender.com`.
5. In Coastline's Multiplayer panel, use the matching secure WebSocket address: `wss://coastline-online-game.onrender.com`.

The free Render service is suitable for testing, not guaranteed production uptime. It can sleep when idle; the first connection after sleeping may take about a minute. No payment details should be needed for the free plan; do not select a paid plan.

## Room protocol

Clients connect to `wss://HOST/?room=ROOMCODE`. Room codes are 4–8 uppercase letters/numbers. Rooms support up to 8 simultaneous players. The server relays player position and rotation updates; gameplay simulation remains local to each client in this first multiplayer pass.
