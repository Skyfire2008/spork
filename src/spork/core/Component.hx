package spork.core;

@:autoBuild(spork.core.Macro.buildComponent())
class Component {
	private var owner: Entity;

	public function clone(): Component {
		throw "not implemented";
	}

	public function assignProps(holder: PropertyHolder) {
		throw "not implemented";
	}

	public function attach(owner: Entity): Void {
		this.owner = owner;
	}
}
