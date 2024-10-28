package spork.util;

import haxe.ds.StringMap;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import spork.core.Macro;

using Lambda;

@:autoBuild(spork.util.Poolable.Macro.build())
interface Poolable {
	/**
	 * Macro adds the following properties:
	 * private static var pool: DynamicArray<T>
	 * public static function getItem(): T
	 * public function set(...)
	 * public static function returnItem()
	 */
}

#if macro
class Macro {
	public static function buildPoolable(fields: Array<Field>): Array<Field> {
		var clazz = Context.getLocalClass().get();
		// map field names to fields
		var fieldMap = new StringMap<Field>();
		for (field in fields) {
			fieldMap.set(field.name, field);
		}

		trace(fieldMap.get("pool"));

		// add pool if required
		if (fieldMap.get("pool") == null) {
			var fucker = TPath(spork.core.Macro.makeTypePath(clazz));
			var newExpr = ENew({pack: ["spork", "util"], name: "DynamicArray", params: [TPType(fucker)]}, []);

			fields.push({
				name: "pool",
				access: [APrivate, AStatic],
				pos: Context.currentPos(),
				kind: FVar(null, {expr: newExpr, pos: Context.currentPos()})
			});

			trace(fields);
		}

		// add getItem if required
		if (fieldMap.get("getItem") == null) {}

		return fields;
	}

	public static macro function build(): Array<Field> {
		return buildPoolable(Context.getBuildFields());
	}
}
#end
