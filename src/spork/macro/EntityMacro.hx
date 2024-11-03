package spork.macro;

import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import haxe.macro.Context;

import spork.core.Macro;

class EntityMacro {
	public static macro function build(): Array<Field> {
		var fields = Context.getBuildFields();
		var componentTypes = Macro.getComponentTypes();

		for (type in componentTypes) {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();
					trace(clazz.name);

					// only process interfaces
					if (clazz.isInterface) {
						var fieldName = "";
						var entry = clazz.meta.extract("name");
						var params = entry.length > 0 ? entry[0].params : [];

						// get name for component array
						if (params.length > 0) {
							fieldName = ExprTools.getValue(params[0]);
						} else {
							fieldName = (clazz.name.charAt(0)).toLowerCase() + clazz.name.substring(1);
						}

						var field: Field = null;
						var isSingular: Bool = false;
						if (clazz.meta.has("singular")) {
							isSingular = true;
							// if singular, add a field of given component type
							field = {
								name: fieldName,
								access: [APublic],
								pos: Context.currentPos(),
								kind: FieldType.FVar(TypeTools.toComplexType(type))
							};
						} else {
							// otherwise add component array field
							fieldName = fieldName + "s";
							field = {
								name: fieldName,
								access: [APublic],
								pos: Context.currentPos(),
								kind: FieldType.FVar(TPath({name: "Array", pack: [], params: [TPType(TypeTools.toComplexType(type))]}), macro [])
							};
						}

						fields.push(field);

						// add callback method
						for (classField in clazz.fields.get()) {
							if (classField.meta.has("callback")) {
								fields.push(Macro.makeEntityCallback(classField, fieldName, isSingular));
							}
						}
					}
				default:
			}
		}

		return fields;
	}
}
