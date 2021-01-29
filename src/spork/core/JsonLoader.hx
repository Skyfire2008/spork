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
		var jsonProps: DynamicAccess<Dynamic> = json.properties;
		var components: Array<Component> = [];
		var propertyFuncs: Array<(PropertyHolder) -> Void> = [];

		// load properties here
		for (name in jsonProps.keys()) {
			var factory = JsonLoader.propertyFactories.get(name);
			if (factory == null) {
				throw('Unrecognized shared property ${name}');
			}

			propertyFuncs.push(factory.bind(jsonProps.get(name)));
		}

		// load components here
		for (compoJson in jsonComponents) {
			var factory = JsonLoader.componentFactories.get(compoJson.name);
			if (factory == null) {
				throw('Unrecognized component ${compoJson.name}');
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

			// assign properties to holder
			for (func in propertyFuncs) {
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
