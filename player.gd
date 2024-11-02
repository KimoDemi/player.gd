extends CharacterBody3D


# Player Variables
var speed = 0.0
const WALK_SPEED = 5.0
const RUN_SPEED = 8.0
const CROUCH_SPEED = 3.0
const CROUCH_DEPTH = 0.5
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.25
const FREE_LOOK_TILT = 7

var slide_timer
const SLIDE_TIMER_MAX = 1.0
var slide_vector = Vector2.ZERO
const SLIDE_SPEED = 15.0

# States
var walking = false
var sprinting = false
var crouching = false
var sliding = false
var free_looking = false


# Headbob Variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

# Camera Tilt Variables
const CAMERA_TILT = 5.0

# FOV Variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5


const gravity = 9.8

# Player Nodes
@onready var head = $Neck/Head
@onready var neck = $Neck
@onready var camera = $Neck/Head/Camera3D
@onready var standing_collision_shape = $StandingCollisionShape
@onready var crouching_collision_shape = $CrouchingCollisionShape
@onready var crouch_ray_cast = $CrouchRayCast


func _ready():
	# Lock and Hide Cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event):
	# Looking Around
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		head.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _physics_process(delta):
	# Get Input
	var input_direction = Input.get_vector("left", "right", "forward", "backward")

	# Add the Gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta


	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false
	
	var grounded = is_on_floor()
	
	# Handle Crouch.
	if Input.is_action_pressed("crouch") or sliding:
		if grounded:
			speed = lerp(speed, CROUCH_SPEED, delta * 10.0)
			head.position.y = lerp(head.position.y, -CROUCH_DEPTH, delta * 10.0)
			standing_collision_shape.disabled = true
			crouching_collision_shape.disabled = false

		# Slide Logic
		if sprinting and input_direction != Vector2.ZERO:
			sliding = true
			slide_timer = SLIDE_TIMER_MAX
			slide_vector = input_direction
			free_looking = true
		
		walking = false
		sprinting = false
		crouching = true

	elif not crouch_ray_cast.is_colliding():
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * 10.0)

		# Handle Sprint.
		if Input.is_action_pressed("sprint"):
			speed = lerp(speed, RUN_SPEED, delta * 10.0)

			walking = false
			sprinting = true
			crouching = false
		else: 
			speed = lerp(speed, WALK_SPEED, delta * 10.0)

			walking = false
			sprinting = false
			crouching = false

	# Handle Free Looking.
	if Input.is_action_pressed("free_look") or sliding:
		free_looking = true
		if sliding:
			camera.rotation.z = lerp(camera.rotation.z, -deg_to_rad(7.0), delta * 10.0)
		else:
			camera.rotation.z = -deg_to_rad(neck.rotation.y * FREE_LOOK_TILT)
	else:
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * 10.0)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 10.0)

	# Handle Sliding
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			sliding = false
			free_looking = false

	# Handle Movement and Acceleration
	var direction = (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		speed = (slide_timer + 0.1) * SLIDE_SPEED
		speed = (slide_timer + 0.1) * SLIDE_SPEED
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	# Head Bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	if not sliding:
		camera.transform.origin = headbob(t_bob)

	# Camera Tilt
	if Input.is_action_pressed("left"):
		camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(CAMERA_TILT), delta * 10.0)
	elif Input.is_action_pressed("right"):
		camera.rotation.z = lerp(camera.rotation.z, -deg_to_rad(CAMERA_TILT), delta * 10.0)

	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, RUN_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()

func headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
