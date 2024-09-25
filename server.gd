extends Node

const MAX_CLIENTS = 4
const PORT = 25566
const IP_ADDRESS = "127.0.0.1"

@onready var ui = %UI  # Ensure this path matches your scene

var player_usernames = {}

func _ready():
	if OS.has_feature("dedicated_server"):
		create_server()
	else:
		create_client()

# Create the server
func create_server():
	print("Starting dedicated server...")
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(PORT, MAX_CLIENTS)

	if result != OK:
		print("ERROR: Failed to start server on port ", PORT, " with error code: ", result)
		return

	multiplayer.multiplayer_peer = peer
	print("Server started on port ", PORT)

	# Handle new clients connecting
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Create the client
func create_client():
	print("Creating client...")
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(IP_ADDRESS, PORT)
	
	if result != OK:
		print("Failed to create client. Error: ", result)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Connecting to server...")
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# Server: handle when a client connects
func _on_peer_connected(id):
	print("Client with ID %d connected to the server." % id)
	set_username(id)
	ui.send_server_message.rpc("Welcome to the server, %s!" % get_username(id))


# Server: handle when a client disconnects
func _on_peer_disconnected(id):
	print("Client with ID %d disconnected from the server." % id)
	if player_usernames.has(id):
		ui.send_server_message.rpc("%s disconnected from the server." % get_username(id))
		player_usernames.erase(id)


# Client: handle when the client successfully connects to the server
func _on_connected_to_server():
	# Send welcome message to all clients
	print("Client connected to the server successfully.")


# Client: handle when connection to the server fails
func _on_connection_failed():
	print("Failed to connect to the server.")


@rpc("any_peer")
func send_chat_message(id, message):
	ui.send_message.rpc(get_username(id), message)
	pass
	

func get_username(sender_id):
	return player_usernames[sender_id]


func set_username(sender_id, username=""):
	if username == "": username = "Guest#%s" % str(randi_range(1,255))
	player_usernames[sender_id] = username
