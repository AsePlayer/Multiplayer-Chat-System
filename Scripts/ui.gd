extends CanvasLayer

# UI elements that handle chat and user interactions
@onready var user_list = %UserList
@onready var chat_log = %ChatLog  # Ensure this path matches your scene
@onready var chat_input = %ChatInput
@onready var send_button = %Send
@onready var server = %Server  # Ensure this path matches your scene

var my_name = "Unknown Guest"
var scroll_bar: VScrollBar

# Initialize and connect UI elements
func _ready():
	send_button.pressed.connect(_on_send_pressed)
	scroll_bar = chat_log.get_v_scroll_bar()

# Appends a new message to the chat log (local client)
@rpc("call_local")
func send_message(user: String, message: String = ""):
	chat_log.text += "\n%s: %s" % [user, message]
	scroll_bar.value = scroll_bar.max_value
	print("%s: %s" % [user, message])

# Displays server messages, including DM messages if they contain "[DM]"
@rpc("call_local")
func send_server_message(message: String):
	if message.contains("[DM]"):
		chat_log.text += "\n%s" % message
	else:
		chat_log.text += "\nServer: %s" % message
	scroll_bar.value = scroll_bar.max_value
	print("Server: %s" % message)

# Handles send button press event and sends the chat message or command
func _on_send_pressed():
	var message: String = chat_input.text.strip_edges()
	if message != "":
		# Send the message to the server (via RPC)
		server.send_command.rpc_id(1, multiplayer.get_unique_id(), message)
		chat_input.text = ""  # Clear the input after sending

# Handles input events, especially sending messages via the Enter key
func _input(event):
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ENTER:
		_on_send_pressed()

# Updates the user list in the UI when it changes
@rpc("call_local")
func update_user_list(users):
	user_list.text = "Online Users:\n"
	for user in users:
		user_list.text += "%s\n" % users[user]
