extends Node

# Constants
const MAX_CLIENTS = 10
const PORT = 25566
const IP_ADDRESS = "127.0.0.1"

# References to UI elements
@onready var ui = %UI  # Ensure this path matches your scene

# Store player usernames by their ID
var player_usernames = {}

func _ready():
	# Check if the app is running as a dedicated server or client
	if OS.has_feature("dedicated_server"):
		create_server()
	else:
		create_client()

# Creates a server if the application is in server mode
func create_server():
	print("Starting dedicated server...")
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(PORT, MAX_CLIENTS)

	# Handle server creation errors
	if result != OK:
		print("ERROR: Failed to start server on port ", PORT, " with error code: ", result)
		return

	multiplayer.multiplayer_peer = peer
	print("Server started on port ", PORT)

	# Connect signals to handle new client connections and disconnections
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Creates a client and connects to the server
func create_client():
	print("Creating client...")
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(IP_ADDRESS, PORT)

	# Handle client creation errors
	if result != OK:
		print("Failed to create client. Error: ", result)
		return

	multiplayer.multiplayer_peer = peer
	print("Connecting to server...")

	# Connect signals for handling server connection events
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# Handles when a client connects to the server
func _on_peer_connected(id):
	print("Client with ID %d connected to the server." % id)
	set_username(id)  # Assign a default username
	# Send a welcome message to the new client
	send_private_message(id, "Server", "Connected to RyChat!\nChat or type /help for a list of commands.")
	# Broadcast user joined the server
	ui.send_server_message.rpc("%s joined the server." % get_username(id))  # Broadcast to everyone


	# Update and broadcast the user list to everyone
	ui.update_user_list.rpc(player_usernames)

# Handles when a client disconnects from the server
func _on_peer_disconnected(id):
	print("Client with ID %d disconnected from the server." % id)
	
	# Check if the user existed, and if so, notify others
	if player_usernames.has(id):
		ui.send_server_message.rpc("%s disconnected from the server." % get_username(id))
		player_usernames.erase(id)

	# Update and broadcast the updated user list
	ui.update_user_list.rpc(player_usernames)

# Handles successful client connection to the server
func _on_connected_to_server():
	print("Client connected to the server successfully.")

# Handles failed connection attempts by the client
func _on_connection_failed():
	print("Failed to connect to the server.")

# Command handler sent by clients (like /help, /list, /dm, /name)
@rpc("any_peer")
func send_command(id, message: String):
	# /help command: Display help instructions
	if message == "/help":
		send_private_message(id, "Server", "Here is a list of commands:\n/help - Show this help message\n/list - Show who's online\n/dm {username} - Send a direct message\n/name {username} - Change your name")

	# /list command: Display a list of online players
	elif message.contains("/list"):
		var names = ""
		for player in player_usernames:
			names += get_username(player) + "\n"
		send_private_message(id, "Server", "Here's a list of who's online:\n%s" % names)

	# /dm command: Send a private message to another player
	elif message.contains("/dm "):
		var parts = message.split(" ", true)
		var recipient_username = parts[1]
		var sent_message = message.replace("/dm %s " % recipient_username, "")
		var recipient_id = player_usernames.find_key(recipient_username)

		if recipient_id != null:
			send_private_message(recipient_id, get_username(id), sent_message)  # Send to the recipient
			send_private_message(id, "You -> %s" % recipient_username, sent_message)  # Also show it to the sender
		else:
			send_private_message(id, "Server", "Username doesn't exist!\nUse /list to see available names.")

	# /name command: Change the player's username
	elif message.contains("/name "):
		var new_name = message.split("/name ")[1]
		set_username(id, new_name)
		send_private_message(id, "Server", 'Name successfully changed to: "%s"' % get_username(id))

	# Regular message: Broadcast the chat message
	else:
		send_chat_message(id, message)

# Sends a private message to a specific client
func send_private_message(client_id, from_user, message):
	send_private_message_to_client.rpc_id(client_id, from_user, message)  # Send directly to the client
	print("[DM] %s -> %s: %s" % [from_user, get_username(client_id), message])

# Receives a private message on the client-side
@rpc("call_local")
func send_private_message_to_client(from_user, message):
	ui.send_message("[DM] " + from_user, message)

# Sends a chat message to all connected clients
@rpc("any_peer")
func send_chat_message(id, message):
	ui.send_message.rpc(get_username(id), message)

# Gets the username of a player by their ID
func get_username(sender_id):
	return player_usernames.get(sender_id, "Unknown")

# Sets a username for a player, or assigns a default one if not provided
func set_username(sender_id, username=""):
	if username == "":
		username = "Guest#%s" % str(randi_range(1, 255))
		while player_usernames.find_key(username):
			username = "Guest#%s" % str(randi_range(1, 255))

	player_usernames[sender_id] = username

	# Broadcast the updated user list
	ui.update_user_list.rpc(player_usernames)
