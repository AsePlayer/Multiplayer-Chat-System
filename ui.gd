extends CanvasLayer

@onready var chat_log = %ChatLog  # Ensure this path matches your scene
@onready var chat_input = %ChatInput
@onready var send_button = %Send

@onready var server = %Server  # Ensure this path matches your scene
var my_name = "Unknown Guest"
var scroll_bar:VScrollBar

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	scroll_bar = chat_log.get_v_scroll_bar()


@rpc("call_local")
func send_message(user: String, message: String = ""):
	chat_log.text += "\n%s: %s" % [user, message]  # Use 'user' instead of 'my_name' to show correct sender.
	scroll_bar.value = scroll_bar.max_value
	print("%s: %s" % [user, message])


@rpc("call_local")
func send_server_message(message):
	chat_log.text += "\nServer: %s" % message  # Use 'user' instead of 'my_name' to show correct sender.
	scroll_bar.value = scroll_bar.max_value
	print("Server: %s" % message)


# Send button handler: sends the chat message to the server
func _on_send_pressed():
	var message:String = chat_input.text.strip_edges()
	if message != "":
		# Send the message to the server
		# server.print_message.rpc(my_name, message)
		
		server.send_chat_message.rpc_id(1, multiplayer.get_unique_id(), message)
		chat_input.text = ""


func _input(event):
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ENTER:
		_on_send_pressed()
		pass
