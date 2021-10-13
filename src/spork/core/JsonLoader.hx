package spork.core;

import haxe.DynamicAccess;
import haxe.ds.StringMap;

typedef EntityFactoryMethod = (?assignments: (holder: PropertyHolder) -> Void) -> Entity;
typedef PropFunc = (PropertyHolder) -> Void;

@:build(spork.core.Macro.buildJsonLoader())
class JsonLoader {
	public static function loadTemplate(json: EntityDef, templateName: String): EntityTemplate {
		var jsonComponents = json.components;
		var jsonProps: DynamicAccess<Dynamic> = json.properties;
		var components: Array<Component> = [];
		var propFuncs: Array<PropFunc> = [];

		// load properties here
		for (name in jsonProps.keys()) {
			var factory = JsonLoader.propertyFactories.get(name);
			if (factory == null) {
				throw('Unrecognized shared property ${name}');
			}

			propFuncs.push(factory.bind(jsonProps.get(name)));
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

		return new EntityTemplate(templateName, components, propFuncs);
	}

	/**
	 * Creates a fatory method for creating new entities from template
	 * @param json template as Dynamic object, read from JSON file
	 * @param templateName name of template
	 * @return entity creation function
	 * @deprecated use entities instead
	 */
	public static function makeLoader(json: EntityDef, templateName: String): EntityFactoryMethod {
		// load json as template first
		var template = JsonLoader.loadTemplate(json, templateName);

		return template.make;
	}
}
