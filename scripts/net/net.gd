extends Node
## Networking: ENet host/client, lobby roster, LAN discovery and room codes.
##
## Transport seam: _make_server_peer() / _make_client_peer() are the only places that create a
## MultiplayerPeer. To add an internet relay later, implement a relay transport there (e.g. a
## WebSocketMultiplayerPeer or WebRTCMultiplayerPeer talking to a small relay/signalling server)
## and select it with Settings "transport". Everything above (Game RPCs, lobby) is peer-agnostic.

signal players_changed
signal joined_ok
signal join_failed(reason: String)
signal host_left(reason: String)
signal discovered_changed
signal lobby_changed

const PORT := 47010
const DISCOVERY_PORT := 47011
const MAX_PLAYERS := 4
const MAGIC := "DISCCHAOS"
const CODE_ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # Crockford base32

var players := {}            # peer -> {name, look, ready, idx}
var lobby_level := 1
var in_session := false      # hosting or joined
var discovered := {}         # ip -> {name, port, players, level, code, seen}
var _beacon: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_t := 0.0
var _broadcast_addrs: Array = []
var _joining := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	_reset_solo()

func _reset_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {1: _my_info(0)}
	in_session = false

func _my_info(idx: int) -> Dictionary:
	return {"name": Profile.nickname, "look": Profile.net_look(), "ready": false, "idx": idx}

func player_index(peer: int) -> int:
	return int(players.get(peer, {}).get("idx", 0))

func is_online() -> bool:
	return in_session and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

# ------------------------------------------------------------------ transport seam
func _make_server_peer(port: int) -> MultiplayerPeer:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return null
	p.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	return p

func _make_client_peer(ip: String, port: int) -> MultiplayerPeer:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, port)
	if err != OK:
		return null
	p.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	return p

# ------------------------------------------------------------------ host / join / leave
func host(port := PORT) -> bool:
	leave(false)
	var p := _make_server_peer(port)
	if p == null:
		return false
	multiplayer.multiplayer_peer = p
	players = {1: _my_info(0)}
	players[1].ready = true
	in_session = true
	_start_beacon()
	players_changed.emit()
	return true

func join(ip: String, port := PORT) -> bool:
	leave(false)
	var p := _make_client_peer(ip, port)
	if p == null:
		join_failed.emit("Could not start connection")
		return false
	multiplayer.multiplayer_peer = p
	_joining = true
	in_session = true
	Settings.set_value("last_ip", ip)
	get_tree().create_timer(8.0).timeout.connect(func():
		if _joining:
			_joining = false
			leave(false)
			join_failed.emit("Couldn't reach the host. Same Wi-Fi / hotspot?"))
	return true

func leave(notify := true) -> void:
	_stop_beacon()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	_reset_solo()
	_joining = false
	if notify:
		players_changed.emit()

func _on_peer_connected(peer: int) -> void:
	pass # wait for rq_register

func _on_peer_disconnected(peer: int) -> void:
	players.erase(peer)
	Game.on_peer_left(peer)
	if multiplayer.is_server():
		ev_players.rpc(players)
	players_changed.emit()
	Game.toast("A player left")

func _on_connected() -> void:
	_joining = false
	rq_register.rpc_id(1, Profile.nickname, Profile.net_look(), Defs.CATALOG_VERSION)
	joined_ok.emit()

func _on_failed() -> void:
	_joining = false
	_reset_solo()
	join_failed.emit("Connection failed")

func _on_server_lost() -> void:
	_reset_solo()
	host_left.emit("The host left the game")

@rpc("any_peer", "call_remote", "reliable")
func rq_register(pname: String, look: Dictionary, version: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server():
		return
	if version != Defs.CATALOG_VERSION:
		ev_kick.rpc_id(peer, "Version mismatch: update both phones to the same Disc Chaos build")
		return
	if players.size() >= MAX_PLAYERS:
		ev_kick.rpc_id(peer, "Game is full (4 players)")
		return
	var used := {}
	for p in players.values():
		used[int(p.idx)] = true
	var idx := 0
	while used.has(idx):
		idx += 1
	look["name"] = pname.left(18)
	players[peer] = {"name": pname.left(18), "look": look, "ready": false, "idx": idx}
	ev_players.rpc(players)
	ev_lobby.rpc_id(peer, lobby_level)
	players_changed.emit()
	Game.toast("%s joined" % pname.left(18))
	# late join: bring them into the running level, then full state sync
	if Game.running and Game.st:
		Game._spawn_remote(peer)
		Game.ev_load_level.rpc_id(peer, Game.level_def.id, Game.level_seed, Settings.get_value("warehouse_items"))

@rpc("authority", "call_remote", "reliable")
func ev_kick(reason: String) -> void:
	leave(false)
	host_left.emit(reason)

@rpc("authority", "call_local", "reliable")
func ev_players(p: Dictionary) -> void:
	var before := players.keys()
	players = p
	players_changed.emit()
	if Game.running:
		for peer in players:
			if peer != Game.me():
				Game._spawn_remote(peer)
				if Game.remotes.has(peer):
					Game.remotes[peer].apply_look(players[peer].look)

@rpc("authority", "call_local", "reliable")
func ev_lobby(level_id: int) -> void:
	lobby_level = level_id
	lobby_changed.emit()

func set_lobby_level(level_id: int) -> void:
	if multiplayer.is_server():
		ev_lobby.rpc(level_id)

func set_ready(r: bool) -> void:
	if multiplayer.is_server():
		_srv_ready(1, r)
	else:
		rq_ready.rpc_id(1, r)

@rpc("any_peer", "call_remote", "reliable")
func rq_ready(r: bool) -> void:
	_srv_ready(multiplayer.get_remote_sender_id(), r)

func _srv_ready(peer: int, r: bool) -> void:
	if players.has(peer):
		players[peer].ready = r
		ev_players.rpc(players)

func push_look() -> void:
	var l := Profile.net_look()
	if multiplayer.is_server():
		_srv_look(1, l)
	else:
		rq_look.rpc_id(1, l)

@rpc("any_peer", "call_remote", "reliable")
func rq_look(look: Dictionary) -> void:
	_srv_look(multiplayer.get_remote_sender_id(), look)

func _srv_look(peer: int, look: Dictionary) -> void:
	if players.has(peer):
		players[peer].look = look
		players[peer].name = String(look.get("name", players[peer].name)).left(18)
		ev_players.rpc(players)

func all_ready() -> bool:
	for p in players.values():
		if not p.ready:
			return false
	return true

# ------------------------------------------------------------------ room codes
static func local_ipv4() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.find(":") >= 0 or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
		if best == "":
			best = a
	return best

static func encode_code(ip: String, port := PORT) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var v := 0
	for p in parts:
		v = (v << 8) | (int(p) & 255)
	v = (v << 16) | (port & 0xFFFF)
	var s := ""
	for i in 10:
		s = CODE_ALPHABET[v & 31] + s
		v >>= 5
	return s.substr(0, 5) + "-" + s.substr(5)

static func decode_code(code: String) -> Dictionary:
	var c := code.to_upper().replace("-", "").replace(" ", "").replace("O", "0").replace("I", "1").replace("L", "1")
	if c.length() != 10:
		return {}
	var v := 0
	for ch in c:
		var d := CODE_ALPHABET.find(ch)
		if d < 0:
			return {}
		v = (v << 5) | d
	var port := v & 0xFFFF
	v >>= 16
	var ip := "%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]
	return {"ip": ip, "port": port}

func room_code() -> String:
	return encode_code(local_ipv4(), PORT)

# ------------------------------------------------------------------ LAN discovery (UDP broadcast)
func _start_beacon() -> void:
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_broadcast_addrs = ["255.255.255.255"]
	for a in IP.get_local_addresses():
		var p := a.split(".")
		if p.size() == 4 and not a.begins_with("127."):
			_broadcast_addrs.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	_beacon_t = 0.0

func _stop_beacon() -> void:
	if _beacon:
		_beacon.close()
	_beacon = null

func start_listening() -> void:
	stop_listening()
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(DISCOVERY_PORT, "*")
	if err != OK:
		_listener = null
	discovered.clear()

func stop_listening() -> void:
	if _listener:
		_listener.close()
	_listener = null

func _process(delta: float) -> void:
	if _beacon:
		_beacon_t -= delta
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			var msg := JSON.stringify({"g": MAGIC, "v": Defs.CATALOG_VERSION, "name": Profile.nickname, "port": PORT,
				"players": players.size(), "level": lobby_level if not Game.running else Game.level_def.get("id", 1),
				"code": room_code(), "running": Game.running}).to_utf8_buffer()
			for addr in _broadcast_addrs:
				_beacon.set_dest_address(addr, DISCOVERY_PORT)
				_beacon.put_packet(msg)
	if _listener:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var pkt := _listener.get_packet()
			var ip := _listener.get_packet_ip()
			var d = JSON.parse_string(pkt.get_string_from_utf8())
			if typeof(d) == TYPE_DICTIONARY and d.get("g") == MAGIC:
				d["seen"] = Time.get_ticks_msec()
				d["ip"] = ip
				discovered[ip] = d
				changed = true
		var now := Time.get_ticks_msec()
		for ip in discovered.keys():
			if now - int(discovered[ip].seen) > 4000:
				discovered.erase(ip)
				changed = true
		if changed:
			discovered_changed.emit()
