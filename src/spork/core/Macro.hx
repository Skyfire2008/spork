package spork.core;

#if (macro && !display)
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.TypeTools;

class Macro {
	public static macro function buildComponent(): Array<Field> {
		var fields = Context.getBuildFields();

		return fields;
	}

	public static macro function buildPool(): ComplexType{
		var type = Context.getLocalType();
		trace(type);

		return null;
	}
}
#end
