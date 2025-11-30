extends Node

## Guarantees the returned vector will have length no greater than 1.
func get_normalized_input_vec(up, right, down, left) -> Vector2:
	var vec = Vector2(
		Input.get_axis(left, right),
		Input.get_axis(up, down)
	)
	
	if vec.length() > 1:
		vec = vec.normalized()
	
	return vec

func lateralize(vec : Vector3) -> Vector2:
	return Vector2(vec.x, vec.z)
