package spork.core;

import spork.core.JsonLoader.PropFunc;

class EntityTemplate {
	private var name: String;
	private var components: Array<Component>;
	private var propFuncs: Array<PropFunc>;

	public function new(name: String, components: Array<Component>, propFuncs: Array<PropFunc>) {
		this.name = name;
		this.components = components;
		this.propFuncs = propFuncs;
	}

	public function addComponent(component: Component) {
		components.push(component);
	}

	public function addPropFunc(propFunc: PropFunc) {
		propFuncs.push(propFunc);
	}

	public function augment(name: String, components: Array<Component>, propFuncs: Array<PropFunc>): EntityTemplate {
		return new EntityTemplate(name, this.components.concat(components), this.propFuncs.concat(propFuncs));
	}

	public function make(?assignments: (holder: PropertyHolder) -> Void): Entity {
		// init entity
		var result = new Entity(name);

		// init holder
		var holder = new PropertyHolder();

		// assign properties to holder
		for (func in propFuncs) {
			func(holder);
		}

		// clone components and create properties
		var clones: Array<Component> = [];
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
