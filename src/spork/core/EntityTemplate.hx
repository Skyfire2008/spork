package spork.core;

import spork.core.JsonLoader.PropFunc;

using Lambda;

/**
 * Contains instructions to make entities, loaded from JSON files
 */
class EntityTemplate {
	public var name(default, null): String;
	public var components(default, null): Array<Component>;
	public var propFuncs(default, null): Array<(PropertyHolder) -> Void>;

	public function new(name: String, components: Array<Component>, propFuncs: Array<PropFunc>) {
		this.name = name;
		this.components = components;
		this.propFuncs = propFuncs;
	}

	/**
	 * Adds new components and property functions to an existing template
	 * @param name 			name of new template
	 * @param components 	array of new components
	 * @param propFuncs 	array of new property functions
	 * @return EntityTemplate
	 */
	public function augment(name: String, components: Array<Component>, propFuncs: Array<PropFunc>): EntityTemplate {
		var newComponents = this.components.concat(components);
		return new EntityTemplate(name, newComponents.map((c) -> {
			return c.clone();
		}), this.propFuncs.concat(propFuncs));
	}

	/**
	 * Create  a new entity from this template
	 * @param assignments 	functions assigning values to properties 
	 * @return Entity
	 */
	// TODO: poolable holder
	public function make(?assignments: (holder: PropertyHolder) -> Void): Entity {
		// init entity
		var result: Entity;
		Macro.getEntity(result, name);

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
