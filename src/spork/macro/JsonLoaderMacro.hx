package spork.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;

import spork.core.Macro;

using Lambda;

class JsonLoaderMacro {
	public static macro function build(): Array<Field> {
		var componentTypes = Macro.getComponentTypes();
		var fields = Context.getBuildFields();
		var propMapDecl: Array<Expr> = [];
		var componentMapDecl: Array<Expr> = [];
		var propMapDecl: Array<Expr> = [];

		var makeComponentFactory = (type: Type) -> {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();

					// skip interfaces
					if (clazz.isInterface) {
						return null;
					}

					var typePath = Macro.makeTypePath(clazz);
					// make a mapping from field name to factory method, calling type's "fromJson(...)"
					return macro $v{Macro.getFieldNameFromClass(clazz)} => (json: Dynamic) -> {
						// generate ident expression from typepath, taking modules into account
						return $p{typePath.pack.concat(typePath.sub != null ? [typePath.name, typePath.sub] : [typePath.name])}.fromJson(json);
					};

				default:
			}
			return null;
		}

		// for every component type create a factory
		for (type in componentTypes) {
			var current = makeComponentFactory(type);
			if (current != null) {
				componentMapDecl.push(current);
			}
		}

		// if components available, generate expr, otherwise just create a new StringMap
		var composExpr: Expr = null;
		if (componentMapDecl.length > 0) {
			composExpr = {
				pos: Context.currentPos(),
				expr: EArrayDecl(componentMapDecl)
			};
		} else {
			composExpr = macro new haxe.ds.StringMap<(Dynamic) -> spork.core.Component>();
		}

		// add componentFactories field
		fields.push({
			name: "componentFactories",
			access: [APublic, AStatic],
			pos: Context.currentPos(),
			kind: FVar(macro : haxe.ds.StringMap<(Dynamic) -> spork.core.Component>, composExpr)
		});

		// creates a mapping propName => function that gets it from json
		var makePropFactory = (field: ClassField) -> {
			var type = field.type;
			var propName = field.name;

			// check if field has a "fromJson" metadata, in which case just create a function with a call to method inside it
			var meta = field.meta.extract("fromJson");
			if (meta.length > 0 && meta[0].params.length > 0) {
				var funcName: String = ExprTools.getValue(meta[0].params[0]);
				var path = funcName.split("."); // split full method name at "." so that it could be used by $p{...}
				trace(propName);
				return macro $v{propName} => (json: Dynamic, holder: spork.core.PropertyHolder) -> {
					holder.$propName = $p{path}(json);
				};
			}

			// otherwise, check if field's type has a fromJson(...) method
			var fromJsonField = Macro.findField(type, "fromJson", true);
			if (fromJsonField == null) {
				Context.error('${field.name} needs a static method fromJson(...) or a metadata @fromJson(...) to read it from json', field.pos);
			} else {
				// get the base type
				var baseType: BaseType;
				switch (type) { // INFO: what about other types?
					case TInst(t, _):
						baseType = t.get();
					case TType(t, _):
						baseType = t.get();
					case TAbstract(t, _):
						baseType = t.get();
					default:
						Context.error('Cannot call fromJson for type ${TypeTools.toString(type)}', field.pos);
				}

				var typePath = Macro.makeTypePath(baseType);
				// make a mapping from field name to factory method, calling type's "fromJson(...)"
				return macro $v{propName} => (json: Dynamic, holder: spork.core.PropertyHolder) -> {
					// holder.{propName} = {typePath}.fromJson(json)
					holder.$propName = $p{typePath.pack.concat(typePath.sub != null ? [typePath.name, typePath.sub] : [typePath.name])}.fromJson(json);
				};
			}

			return null;
		};

		// add propFactories map
		var holderClassFields = TypeTools.getClass(Context.getType(Macro.holderClassName)).fields.get();
		for (field in holderClassFields) {
			var current = makePropFactory(field);
			if (current != null) {
				propMapDecl.push(current);
			}
		}

		var propsExpr: Expr = null;
		if (propMapDecl.length > 0) {
			propsExpr = {
				pos: Context.currentPos(),
				expr: EArrayDecl(propMapDecl)
			};
		} else {
			// if no components available, just create a new StringMap
			propsExpr = macro new haxe.ds.StringMap<(Dynamic, spork.core.PropertyHolder) -> Void>();
		}

		fields.push({
			name: "propertyFactories",
			access: [APublic, AStatic],
			pos: Context.currentPos(),
			kind: FVar(macro : haxe.ds.StringMap<(Dynamic, spork.core.PropertyHolder) -> Void>, propsExpr)
		});

		return fields;
	}
}
