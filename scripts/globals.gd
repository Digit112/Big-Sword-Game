extends Node

func get_normalized_input_vec(up, right, down, left) -> Vector2:
	var vec = Vector2(
		Input.get_axis(left, right),
		Input.get_axis(up, down)
	)
	
	if vec != Vector2.ZERO:
		if vec.length() > 1:
			vec = vec.normalized()
	
	return vec
