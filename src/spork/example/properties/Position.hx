package spork.example.properties;

import spork.core.SharedProperty;
import spork.example.geom.Point;

// TODO: and this is aa huge todo, find a way to setup property holder with properties of same structure without creating new classes for them
@name("position")
class Position implements SharedProperty extends Point {
	public function new(x: Float = 0, y: Float = 0) {
		super(x, y);
	}
}
