package spork.core;

import haxe.DynamicAccess;
import haxe.ds.StringMap;

@:build(spork.core.Macro.buildJsonLoader())
class JsonLoader {
	/**
	 * Creates a fatory method for creating new entities from template
	 * @param json template as Dynamic object, read from JSON file
	 * @return entity creation function
	 */
	public static function makeLoader(json: Dynamic): (assignments: (holder: PropertyHolder) -> Void) -> Entity {
		var jsonProps: DynamicAccess<Dynamic> = json.properties;
		var jsonComponents: DynamicAccess<Dynamic> = json.components;
		var props: Array<SharedProperty> = [];
		var components: Array<Component> = [];

		// load shared properties
		for (key in jsonProps.keys()) {
			var factory = JsonLoader.propFactories.get(key);
			if (factory == null) {
				throw('Unrecognized shared property $key');
			}

			props.push(factory(jsonProps.get(key)));
		}

		// load components here
		for (key in jsonComponents.keys()) {
			var factory = JsonLoader.componentFactories.get(key);
			if (factory == null) {
				throw('Unrecognize component $key');
			}

			components.push(factory(jsonComponents.get(key)));
		}

		// create resulting factory function
		// assignments is used to assign starting values(e.g. position, etc.) to properties
		var func = (assignments: (holder: PropertyHolder) -> Void) -> {
			// init entity
			var result = new Entity();

			// attach clones of properties to holder
			var holder = new PropertyHolder();
			for (prop in props) {
				prop.clone().attach(holder);
			}

			// clone components, give them properties and attach to entity
			for (comp in components) {
				var clone = comp.clone();
				clone.assignProps(holder);
				clone.attach(result);
			}

			return result;
		};

		return func;
	}
}
