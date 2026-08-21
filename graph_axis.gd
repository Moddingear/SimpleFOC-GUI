extends RefCounted


#Helper class to make graduations for a graph axis
class_name graphAxis

#Return the size of a graduation
func get_minmax_unit(graph_rect:Rect2, minmax:Vector2)->float:
	#var minlog = floorf(log(abs(minmax.x))/log(10))
	#var maxlog = floorf(log(abs(minmax.y))/log(10))
	var delta = minmax.y-minmax.x
	var deltalog = floorf(log(abs(delta))/log(10))
	var baselog = deltalog#maxf(minlog, maxlog)
	var maxgraduations = absf(floor(graph_rect.size.y/ThemeDB.fallback_font.get_height()))/2
	var unit = pow(10, baselog-1)
	while delta/unit > maxgraduations:
		if delta/unit/10 > maxgraduations:
			unit *= 10
		else:
			unit *= 2
	return unit

#Return the min and max snapped to graduations
func minmax_unit_snap(minmax:Vector2, unit:float)->Vector2:
	var min_snapped = snappedf(minmax.x, unit)
	if min_snapped > minmax.x: min_snapped-=unit
	var max_snapped = snappedf(minmax.y, unit)
	if max_snapped < minmax.y: max_snapped+=unit
	return Vector2(min_snapped, max_snapped)

func draw_axis(minpos:Vector2, maxpos: Vector2, unit:float, notch_width:float, minmax:Vector2, draw_on:Control) ->void:
	var delta = minmax.y - minmax.x
	var num_units : int = roundi(delta/unit)
	if num_units > 1000:
		return
	for i in range(num_units):
		var alpha : float = float(i) / num_units
		var pos :Vector2 = lerp(minpos, maxpos, alpha)
		var value : float = snappedf(lerpf(minmax.x, minmax.y, alpha), unit)
		var text : String = " "+str(value)
		var width = notch_width * (2 if snappedf(value, unit*10) == value else 1)
		var font = ThemeDB.fallback_font
		draw_on.draw_line(pos + Vector2.LEFT * width, pos+Vector2.RIGHT * width, Color.WHITE)
		draw_on.draw_string(font, pos + Vector2.RIGHT * width + Vector2.DOWN * font.get_height() /4, text, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_on.draw_line(minpos, maxpos, Color.WHITE)
