package spork.core;

import haxe.DynamicAccess;
import haxe.ds.StringMap;

typedef EntityFactoryMethod = (assignments: (holder: PropertyHolder) -> Void) -> Entity;

@:build(spork.core.Macro.buildJsonLoader())
class JsonLoader {
	/**
	 * Creates a fatory method for creating new entities from template
	 * @param json template as Dynamic object, read from JSON file
	 * @return entity creation function
	 */
	public static function makeLoader(json: EntityDef): EntityFactoryMethod {
		var jsonComponents = json.components;
		var components: Array<Component> = [];

		// load components here
		for (compoJson in jsonComponents) {
			var factory = JsonLoader.componentFactories.get(compoJson.name);
			if (factory == null) {
				throw('Unrecognize component ${compoJson.name}');
			}

			var component = factory(compoJson.params);
			components.push(component);
		}

		// create resulting factory function
		// assignments is used to assign starting values(e.g. position, etc.) to properties
		var func = (assignments: (holder: PropertyHolder) -> Void) -> {
			// init entity
			var result = new Entity();

			// init holder
			var holder = new PropertyHolder();

			// clone components and create properties
			var clones: Array<Component> = [];
			for (comp in components) {
				var clone = comp.clone();
				clone.createProps(holder);
				clones.push(clone);
			}

			// assign values to properties
			assignments(holder);

			// assign properties to clones and attach them to entity
			for (clone in clones) {
				clone.assignProps(holder);
				clone.attach(result);
			}

			return result;
		};

		return func;
	}
}
