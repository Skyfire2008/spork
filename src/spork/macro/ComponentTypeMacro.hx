package spork.macro;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

import spork.core.Macro;

class ComponentTypeMacro {
	public static macro function build(): Array<Field> {
		var componentTypes = Macro.getComponentTypes();
		var fields = Context.getBuildFields();

		for (type in componentTypes) {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();

					// skip interfaces
					if (!clazz.isInterface) {
						var name = Macro.getFieldNameFromClass(clazz);
						fields.push({
							name: name,
							kind: FVar(null, macro $v{name}),
							pos: Context.currentPos()
						});
					}
				default:
			}
		}

		return fields;
	}
}
