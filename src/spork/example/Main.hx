package spork.example;

import spork.example.properties.*;

class Main {
	public static function main() {
		var hp = new Health(100);
		var vel = new Velocity(11, 22);

		var holder: spork.core.PropertyHolder;

		trace("Hello world!");
	}
}
