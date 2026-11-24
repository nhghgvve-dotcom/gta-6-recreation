"use strict";

const http = require("http");
const crypto = require("crypto");
const { WebSocketServer, WebSocket } = require("ws");

const PORT = Number(process.env.PORT || 10000);
const MAX_PLAYERS_PER_ROOM = 8;
const rooms = new Map();

const server = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ service: "Coastline Online", status: "ok" }));
    return;
  }
  res.writeHead(404);
  res.end("Not found");
});

const wss = new WebSocketServer({
  server,
  maxPayload: 2048,
  perMessageDeflate: false
});

function send(socket, data) {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(data));
  }
}

function leave(socket) {
  const roomCode = socket.roomCode;
  if (!roomCode) return;
  const room = rooms.get(roomCode);
  if (!room) return;
  room.delete(socket.id);
  for (const member of room.values()) {
    send(member.socket, { type: "player_left", id: socket.id });
  }
  if (room.size === 0) rooms.delete(roomCode);
  socket.roomCode = null;
}

wss.on("connection", (socket, request) => {
  const url = new URL(request.url, "http://localhost");
  const roomCode = String(url.searchParams.get("room") || "").toUpperCase();
  if (!/^[A-Z0-9]{4,8}$/.test(roomCode)) {
    send(socket, { type: "error", message: "Invalid room code." });
    socket.close(1008, "Invalid room code");
    return;
  }

  let room = rooms.get(roomCode);
  if (!room) {
    room = new Map();
    rooms.set(roomCode, room);
  }
  if (room.size >= MAX_PLAYERS_PER_ROOM) {
    send(socket, { type: "error", message: "That room is full (8 players max)." });
    socket.close(1008, "Room full");
    return;
  }

  const id = crypto.randomBytes(6).toString("hex");
  socket.id = id;
  socket.roomCode = roomCode;
  socket.lastStateAt = 0;
  socket.state = { id, position: [0, 0.7, 0], rotation: 0, driving: false };

  const existingPlayers = [];
  for (const member of room.values()) existingPlayers.push(member.state);
  room.set(id, { socket, state: socket.state });

  send(socket, { type: "welcome", id, players: existingPlayers });
  for (const member of room.values()) {
    if (member.socket !== socket) {
      send(member.socket, { type: "player_joined", ...socket.state });
    }
  }

  socket.on("message", (raw) => {
    const now = Date.now();
    if (now - socket.lastStateAt < 45) return;
    socket.lastStateAt = now;

    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (!message || message.type !== "state") return;
    const p = message.position;
    if (!Array.isArray(p) || p.length < 3) return;
    const values = p.slice(0, 3).map(Number);
    const rotation = Number(message.rotation);
    if (![...values, rotation].every(Number.isFinite)) return;
    if (values.some((v) => Math.abs(v) > 10000) || Math.abs(rotation) > 100000) return;

    const state = {
      type: "state",
      id,
      position: values,
      rotation,
      driving: Boolean(message.driving)
    };
    socket.state = state;
    const currentRoom = rooms.get(roomCode);
    if (!currentRoom) return;
    const record = currentRoom.get(id);
    if (record) record.state = state;
    for (const member of currentRoom.values()) {
      if (member.socket !== socket) send(member.socket, state);
    }
  });

  socket.on("close", () => leave(socket));
  socket.on("error", () => leave(socket));
});

server.listen(PORT, "0.0.0.0", () => {
  console.log("Coastline Online listening on port " + PORT);
});
