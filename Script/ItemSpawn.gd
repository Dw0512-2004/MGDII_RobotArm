extends Marker3D

@export var item_scene_1: PackedScene
@export var item_scene_2: PackedScene
@export var path_3d: Path3D              # 新增：绑定 U 型传送带的 Path3D
@export var conveyor_speed: float = 2.0  # 传送带移动速度

@onready var spawn_timer: Timer = $Timer
var active_followers: Array[PathFollow3D] = []

func _ready() -> void:
	spawn_timer.timeout.connect(_on_timer_timeout)

func _process(delta: float) -> void:
	for i in range(active_followers.size() - 1, -1, -1):
		var follower = active_followers[i]
		
		# 如果箱子已被机械爪抓走并销毁了轨道节点，清理列表记录
		if not is_instance_valid(follower):
			active_followers.remove_at(i)
			continue
			
		# 沿 U 型路径推进
		follower.progress += conveyor_speed * delta
		
		# 走到 U 型终点未被抓走则自动销毁
		if follower.progress_ratio >= 1.0:
			follower.queue_free()
			active_followers.remove_at(i)

func _on_timer_timeout() -> void:
	if item_scene_1 == null or item_scene_2 == null or path_3d == null:
		print("请检查 Inspector 中的 tscn 和 Path3D 是否已绑定！")
		return
		
	# 1. 创建轨道节点并加入 Path3D（会自动从路径起点出发）
	var follower = PathFollow3D.new()
	follower.loop = false
	follower.rotation_mode = PathFollow3D.ROTATION_Y
	path_3d.add_child(follower)
	
	# 2. 随机生成箱子并冻结重力
	var random_scene = [item_scene_1, item_scene_2].pick_random()
	var new_item: RigidBody3D = random_scene.instantiate()
	new_item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	new_item.freeze = true
	
	# 3. 挂载到轨道上，Y 轴抬高 0.35 防止嵌入传送带表面
	follower.add_child(new_item)
	new_item.position = Vector3(0, 0.35, 0)
	
	active_followers.append(follower)
