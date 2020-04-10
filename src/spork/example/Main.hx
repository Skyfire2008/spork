package spork.example;

import spork.core.SharedProperty;
import spork.core.PropertyHolder;
import spork.example.Entity;
import spork.example.properties.*;

class DummyVelocity extends Velocity {
	public function new(x: Float, y: Float) {
		super(x, y);
	}
}

interface DummyProperty extends SharedProperty {
	public function foobar(): Bool;
}

class Main {
	public static function main() {
		var hp = new Health(100);
		var vel = new Velocity(11, 22);

		var holder: PropertyHolder = new PropertyHolder();
		holder.health = hp;
		holder.sporkExamplePropertiesVelocity = vel;

		var ent = new Entity();
		trace("Hello world!");
	}
}
