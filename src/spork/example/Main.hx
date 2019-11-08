package spork.example;

import spork.core.ComponentPool;

import spork.example.components.UpdateComponent;

class Main {
	public static function main() {

		var updPool = new ComponentPool<UpdateComponent>();

		trace("Hello world!");
	}
}
