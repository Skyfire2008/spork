package spork.core;

@:autoBuild(spork.core.Macro.buildComponent())
interface Component {
	public function attach(owner: Entity): Void;
}
