package spork.core;

import haxe.DynamicAccess;
import haxe.ds.StringMap;

@:build(spork.core.Macro.buildJsonLoader())
class JsonLoader {
	public static function makeLoader(json: Dynamic): () -> Entity {
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

		var func = () -> {
			var result = new Entity();

			var holder = new PropertyHolder();
			for (prop in props) {
				prop.clone().attach(holder);
			}

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
