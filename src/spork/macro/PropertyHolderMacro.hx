package spork.macro;

import haxe.macro.Context;
import haxe.macro.TypeTools;
import haxe.macro.Expr;

import spork.core.Macro;

class PropertyHolderMacro {
	public static macro function build(): Array<Field> {
		var fields = Context.getBuildFields();

		if (Macro.holderClassName == null) {
			Context.error("No property holder class specified", Context.currentPos());
		}
		var classFields = TypeTools.getClass(Context.getType(Macro.holderClassName)).fields.get();
		for (field in classFields) {
			@:privateAccess
			fields.push(TypeTools.toField(field));
		}

		return fields;
	}
}
