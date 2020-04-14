package spork.example;

import spork.core.PropertyHolder;
import spork.core.JsonLoader;
import spork.core.Entity;
import spork.example.properties.*;

class Main {
	public static function main() {
		var hp = new Health(100);
		var vel = new Velocity(11, 22);

		var m = new spork.example.components.UpdateComponent.Move();

		var holder: PropertyHolder = new PropertyHolder();
		holder.health = hp;

		var ent = new Entity();
		trace(holder);
		vel.clone().attach(holder);
		trace(holder);

		for (key in JsonLoader.propFactories.keys()) {
			trace(key);
			trace(JsonLoader.propFactories.get(key)({hp: 123, x: 45, y: 67}));
		}
	}
}
