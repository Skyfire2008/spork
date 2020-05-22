package spork.core;

@:build(spork.core.Macro.buildEntity())
class Entity {
	private static var currentId: Int = 0;
	public var id(default, null): Int;

	public function new() {
		id = Entity.currentId++;
	}
}
