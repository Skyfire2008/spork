package spork.core;

@:build(spork.core.Macro.buildEntity())
class Entity {
	private static var currentId: Int = 0;
	public var id(default, null): Int;
	public var templateName(default, null): String;

	public function new(templateName: String) {
		id = Entity.currentId++;
		this.templateName = templateName;
	}
}
