package spork.core;

class EntityTemplate {
	private var name:String;
	private var components:Array<Component>;
	private var propFuncs:Array<(PropertyHolder) -> Void>;

	public function new(name:String, components:Array<Component>, propFuncs:Array<(PropertyHolder) -> Void>) {
		this.name = name;
		this.components = components;
		this.propFuncs = propFuncs;
	}

	public function addComponent(component:Component) {
		components.push(component);
	}

	public function addPropFunc(propFunc:(PropertyHolder) -> Void) {
		propFuncs.push(propFunc);
	}

	public function make(?assignments:(holder:PropertyHolder) -> Void):Entity {
		// init entity
		var result = new Entity(name);

		// init holder
		var holder = new PropertyHolder();

		// assign properties to holder
		for (func in propFuncs) {
			func(holder);
		}

		// clone components and create properties
		var clones:Array<Component> = [];
		for (comp in components) {
			var clone = comp.clone();
			clone.createProps(holder);
			clones.push(clone);
		}

		// assign values to properties
		if (assignments != null) {
			assignments(holder);
		}

		// assign properties to clones and attach them to entity
		for (clone in clones) {
			clone.assignProps(holder);
			clone.attach(result);
		}

		return result;
	}
}
