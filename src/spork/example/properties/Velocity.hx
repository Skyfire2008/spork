package spork.example.properties;

import spork.core.SharedProperty;
import spork.example.geom.Point;

@name()
class Velocity implements SharedProperty extends Point {
	public function new(x: Float = 0, y: Float = 0) {
		super(x, y);
	}
}
