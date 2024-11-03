package spork.macro;

import haxe.macro.Context;
import haxe.macro.Expr;

import spork.core.Macro;

using Lambda;

class SharedPropertyMacro {
	public static macro function build(): Array<Field> {
		var clazz = Context.getLocalClass().get();
		var fields = Context.getBuildFields();

		// skip interfaces
		if (!clazz.isInterface) {
			// add "fromJson" if it's missing
			if (!fields.exists((item) -> {
				return item.name == "fromJson";
			})) {
				fields.push(Macro.makeFromJsonMethod(fields.find((item) -> {
					return item.name == "new";
				}), clazz));
			}
		}

		return fields;
	}
}
