package spork.core;

@:autoBuild(spork.core.Macro.buildComponent())
interface Component {
	public function clone(): Component;

	public function assignProps(holder: PropertyHolder): Void;

	public function attach(owner: Entity): Void;
}
