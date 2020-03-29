package spork.example.properties;

import spork.core.SharedProperty;

@name()
class Velocity implements SharedProperty {
	public var x: Float;
	public var y: Float;

	public function new(x: Float = 0, y: Float = 0) {
		this.x = x;
		this.y = y;
	}
}
