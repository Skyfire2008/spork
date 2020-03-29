package spork.core;

import haxe.ds.StringMap;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.TypeTools;
import haxe.macro.ExprTools;

class Macro {
	#if macro
	private static var onAfterTypingAdded = false;
	private static var holderDefined = false;
	private static var holderFields: StringMap<ComplexType> = new StringMap<ComplexType>();

	public static function buildPropHolder(types: Array<ModuleType>): Void {
		trace(types);
		if (!holderDefined) {
			var clazz = macro class PropertyHolder {};
			clazz.pack = ["spork", "core"];
			for (iter in holderFields.keyValueIterator()) {
				clazz.fields.push({
					name: iter.key,
					access: [APublic],
					pos: Context.currentPos(),
					kind: FVar(iter.value, null)
				});
			}
			Context.defineType(clazz);
			holderDefined = true;
		}
	}
	#end

	public static macro function buildComponent(): Array<Field> {
		var fields = Context.getBuildFields();

		return fields;
	}

	public static macro function registerProperty(): Array<Field> {
		var fields = Context.getBuildFields();

		if (!Macro.onAfterTypingAdded) {
			Context.onAfterTyping(Macro.buildPropHolder);
			Macro.onAfterTypingAdded = true;
		}

		// get field name for property holder
		var clazz = Context.getLocalClass().get();
		var meta = clazz.meta.extract("name");
		var fieldName = "";
		if (meta.length != 0 && meta[0].params.length != 0) {
			fieldName = ExprTools.getValue(meta[0].params[0]);
		} else {
			clazz.pack.push(clazz.name);
			fieldName = makeVarName(clazz.pack);
		}
		holderFields.set(fieldName, TypeTools.toComplexType(Context.getLocalType()));

		return fields;
	}

	public static inline function makeVarName(pack: Array<String>): String {
		var nameBuf: StringBuf = new StringBuf();

		for (i in 0...pack.length) {
			var word = pack[i];
			if (i == 0) {
				nameBuf.add(word.substr(0, 1).toLowerCase());
			} else {
				nameBuf.add(word.substr(0, 1).toUpperCase());
			}
			nameBuf.addSub(word, 1);
		}

		return nameBuf.toString();
	}
}
