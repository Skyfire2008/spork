package spork.core;

import haxe.macro.Expr;
import haxe.macro.Context;

class Macro {
	public static macro function buildComponent(): Array<Field> {
		var fields = Context.getBuildFields();

		return fields;
	}

	public static macro function buildPool(): Array<Field>{
		var fields = Context.getBuildFields();

		return fields;
	}
}
