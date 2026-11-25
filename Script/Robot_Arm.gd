extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@export var grab_area: Area3D
@export var hold_point: Node3D    #position item hold
@export var stop_menu: Control
@export var score_label: Label

#rotation
var rotation_speed: float = 0.005
var active_touch_index: int = -1
var initial_rotation_y: float = 0.0   # 记录开局时朝向正前方的角度
var angle_offset: float = 0.0         # 相对正前方的左右偏移量

var max_swing_angle: float = deg_to_rad(75.0)

#settings
var is_animating: bool = false
var body_in_range: RigidBody3D = null #sensors
var held_object: RigidBody3D = null   #item holding
var score: int = 0 #initial score record

func _ready() -> void:
	initial_rotation_y = rotation.y
	anim_player.animation_finished.connect(_on_animation_finished)
	update_score_ui()

func _process(delta: float) -> void:
	# 使用 lerp 线性插值，避免跨越 180° 边界时从背后绕远路
	var target_y: float = initial_rotation_y + angle_offset
	rotation.y = lerp(rotation.y, target_y, 5.0 * delta)
	
	# 只要手里抓着箱子，每帧同步到抓取点
	if held_object != null:
		held_object.global_position = hold_point.global_position
		held_object.global_rotation = hold_point.global_rotation

#gesture swipe position
func _on_swipe_zone_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_index == -1:
			active_touch_index = event.index
		elif not event.pressed and event.index == active_touch_index:
			active_touch_index = -1

	elif event is InputEventScreenDrag:
		if event.index == active_touch_index:
			angle_offset -= event.relative.x * rotation_speed
			angle_offset = clamp(angle_offset, -max_swing_angle, max_swing_angle)

#detection
func _on_grab_area_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and body != held_object:
		body_in_range = body
		print("detect interactive item: ", body.name)

func _on_grab_area_body_exited(body: Node3D) -> void:
	if body == body_in_range:
		body_in_range = null
		print("box leave area")

#button with animation
func _on_touch_screen_button_pressed() -> void:
	if not is_animating:
		is_animating = true
		anim_player.play("Grab_Down")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Grab_Down":
		is_animating = false

#animation triggered
func trigger_grab_check() -> void:
	if held_object == null:
		var overlapping_bodies = grab_area.get_overlapping_bodies()
		var target_item: RigidBody3D = null

		for body in overlapping_bodies:
			if body is RigidBody3D and body != held_object:
				target_item = body
				break

		if target_item != null:
			grab_item(target_item)
			print("success grab")
		else:
			print("no box")
	else:
		release_item()
		print("released")

#core mechanics
func grab_item(item: RigidBody3D) -> void:
	held_object = item
	
	var parent_node = held_object.get_parent()
	if parent_node is PathFollow3D:
		held_object.reparent(get_tree().current_scene, true)
		parent_node.queue_free()

	held_object.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	held_object.freeze = true

	# close collision, prevent box collision fight with crawler collision
	held_object.collision_layer = 0
	held_object.collision_mask = 0

	# fix the point when grab
	held_object.global_position = hold_point.global_position
	held_object.global_rotation = hold_point.global_rotation

	print("grabbed: ", held_object.name)

func release_item() -> void:
	if held_object == null:
		return

	#clear velocity, make sure box drop when released
	held_object.linear_velocity = Vector3.ZERO
	held_object.angular_velocity = Vector3.ZERO

	#physics and collision recover
	held_object.collision_layer = 1
	held_object.collision_mask = 3
	held_object.freeze = false

	print("dropped!")
	held_object = null

#collector
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and body != held_object:
		if body.is_in_group("Blue"):
			add_score(1)
			show_floating_text("score +1", Color.GREEN, body.global_position)
			body.queue_free()
		elif body.is_in_group("Red"):
			show_floating_text("wrong！", Color.RED, body.global_position)
			body.queue_free()

func _on_area_3d_body_red_entered(body: Node3D) -> void:
	if body is RigidBody3D and body != held_object:
		if body.is_in_group("Red"):
			add_score(1)
			show_floating_text("score +1", Color.GREEN, body.global_position)
			body.queue_free()
		elif body.is_in_group("Blue"):
			show_floating_text("wrong！", Color.RED, body.global_position)
			body.queue_free()

#word floating
func show_floating_text(msg: String, text_color: Color, spawn_pos: Vector3) -> void:
	var label = Label3D.new()
	label.text = msg
	label.modulate = text_color
	label.font_size = 72
	label.outline_size = 16

	#word always facing camera
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true

	get_tree().current_scene.add_child(label)
	label.global_position = spawn_pos + Vector3(0, 0.5, 0)

	#floating up animation
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)

	#destroy when finished
	tween.chain().tween_callback(label.queue_free)
	
func _on_pause_button_pressed() -> void:
	get_tree().paused = true     #freeze game
	stop_menu.visible = true     #show pause menu

func _on_resume_button_pressed() -> void:
	stop_menu.visible = false    #hide pause menu
	get_tree().paused = false    #resume game

func _on_restart_button_pressed() -> void:
	#restart game
	get_tree().paused = false
	get_tree().reload_current_scene()

#score
func add_score(points: int) -> void:
	score += points
	update_score_ui()

func update_score_ui() -> void:
	if score_label != null:
		score_label.text = "Score: " + str(score)
