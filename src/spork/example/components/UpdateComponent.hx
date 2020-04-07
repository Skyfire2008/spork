package spork.example.components;

import spork.core.Component;
import spork.core.Entity;
import spork.example.geom.Point;

@component
interface UpdateComponent {
	@callback
	function update(time: Float): Float;
}

class Move implements UpdateComponent {
	private var vel: Point;
	private var pos: Point;

	public function update(time: Float): Float {
		pos.add(Point.scale(vel, time));
		return time;
	}

	public function attach(owner: Entity) {}
}
