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
	ui.send_server_message.rpc("%s Joined the server." % get_username(id))
	send_private_message(id, "Server", "Welcome to the server, %s!\nYou can chat or type /help for a list of commands." % get_username(id))

# Server: handle when a client disconnects
func _on_peer_disconnected(id):
	print("Client with ID %d disconnected from the server." % id)
	if player_usernames.has(id):
		ui.send_server_message.rpc("%s disconnected from the server." % get_username(id))
		player_usernames.erase(id)

# Client: handle when the client successfully connects to the server
func _on_connected_to_server():
	print("Client connected to the server successfully.")

# Client: handle when connection to the server fails
func _on_connection_failed():
	print("Failed to connect to the server.")

# Server: Handle command requests from clients
@rpc("any_peer")
func send_command(id, message:String):
	if message == "/help":
		# Send a private message back to the client with help info
		send_private_message(id, "Server", "Here is a list of commands:\n/help - Show this help message\n/list - Show who's online\n/dm {username} - Send a user a direct message\n/name {username} - Change your name")
	elif message.contains("/list"):
		# Send a private message back to the client with list of online users
		var names:String
		for player in player_usernames:
			names += ((get_username(player)) + "\n")
		send_private_message(id, "Server", "Here's a list of who's online right now:\n%s" % names)
	elif message.contains("/dm "):
		# Get the id of the player that is being DM'd and send private message
		var msg = message.split("/dm ")
		var recipient_username = message.split(" ")[1]
		var sent_message = message.split(recipient_username)[1]
		
		var recipient_id = player_usernames.find_key(recipient_username)
		# See if user exists.
		if recipient_id != null:
			send_private_message(player_usernames.find_key(recipient_username), get_username(id), sent_message)
		else: # User doesn't exist. DM error to client
			send_private_message(id, "Server", "Username doesn't exist!\nTry using /list for a list of available names.")
	elif message.contains("/name "):
		var name = message.split("/name ")
		set_username(id, name[1])
		send_private_message(id, "Server", "Name successfuly changed to: %s" % get_username(id))
	else:
		# Broadcast the message as usual
		send_chat_message(id, message)


# Server: Send a message directly to a specific client (private)
func send_private_message(client_id, from_user, message):
	# Only send to the specific client
	send_private_message_to_client.rpc_id(client_id, from_user, message)
	print("[DM] %s -> %s:%s" % [from_user, get_username(client_id), message])

# Client: Receive the private message from the server
@rpc("call_local")
func send_private_message_to_client(from_user, message):
	ui.send_message("[DM] " + from_user, message)

# Server: Send a chat message to all clients
@rpc("any_peer")
func send_chat_message(id, message):
	ui.send_message.rpc(get_username(id), message)

func get_username(sender_id):
	return player_usernames.get(sender_id, "Unknown")

func set_username(sender_id, username=""):
	if username == "":
		username = "Guest#%s" % str(randi_range(1, 255))
	player_usernames[sender_id] = username
