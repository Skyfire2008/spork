package spork.core;

@:autoBuild(spork.core.Macro.buildComponent())
class Component<T:Entity> {
	private var owner: T;

	public function attach(owner: T): Void {
		this.owner = owner;
	}
}
