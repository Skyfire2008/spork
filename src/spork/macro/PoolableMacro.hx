package spork.macro;

import haxe.ds.StringMap;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import spork.core.Macro;

using Lambda;

class PoolableMacro {
	public static function buildPoolable(fields: Array<Field>): Array<Field> {
		var clazz = Context.getLocalClass().get();
		var clazzTypePath = spork.core.Macro.makeTypePath(clazz);

		// map field names to fields
		var fieldMap = new StringMap<Field>();
		for (field in fields) {
			fieldMap.set(field.name, field);
		}

		// check that the constructor can be used without arguments
		var constructor = fieldMap.get("new");
		var constructorOk = true;
		if (constructor != null) {
			var constructorArgs: Array<FunctionArg> = null;
			var constructorExpr: Expr = null;
			switch (constructor.kind) {
				case FFun(f):
					constructorArgs = f.args;
					constructorExpr = f.expr;
					// make sure that all constructor arguments are optional or have a default value
					for (arg in f.args) {
						if (!arg.opt && arg.value == null) {
							constructorOk = false;
							break;
						}
					}
				default: // do nothing
			}

			// add setParams if required
			if (fieldMap.get("setParams") == null && constructorArgs.length > 0 && constructorExpr != null) {
				fields.push({
					name: "setParams",
					meta: [{name: "genByMacro", pos: Context.currentPos()}],
					doc: "Calls the same expressions as the constructor \nGenerated by macro",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: constructorArgs,
						expr: constructorExpr
					})
				});
			}
		} else {
			constructorOk = false;
		}

		// if constructor cannot be used without arguments, check if defaultConstructor(...) exists
		if (!constructorOk) {
			if (fieldMap.get("defaultConstructor") == null) {
				Context.error('${clazz.name} needs to have a constructor not requiring arguments or a static method defaultConstructor()',
					Context.currentPos());
			}
		}
		// expression to create a new item
		var createItem = constructorOk ? macro new $clazzTypePath() : macro defaultConstructor();

		// get initial pool size
		var initialPoolSize: Array<Expr> = [macro 100];
		var metas = clazz.meta.extract("initialPoolSize");
		if (metas.length > 0) {
			initialPoolSize = metas[0].params;
		}

		// add pool if required
		if (fieldMap.get("pool") == null) {
			// all of this just for spork.util.DynamicArray<%clazz%>(%initialPoolSize%)
			var typeParam = TPath(clazzTypePath);
			var newExpr = ENew({
				pack: ["spork", "util"],
				name: "DynamicArray",
				params: [TPType(typeParam)]
			}, initialPoolSize);

			fields.push({
				name: "pool",
				doc: "Pool that stores instances of this object for reuse\nGenerated by macro",
				access: [APrivate, AStatic],
				pos: Context.currentPos(),
				kind: FVar(null, {
					expr: newExpr,
					pos: Context.currentPos()
				})
			});
		}

		// add initPool if required
		if (fieldMap.get("initPool") == null) {
			fields.push({
				name: "initPool",
				doc: "Fills up the object pool with instances \nGenerated by macro",
				access: [APublic, AStatic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [],
					expr: macro for (i in 0...$e{initialPoolSize[0]}) {
						pool.push($e{createItem});
					}
				})
			});
		}

		// generate returnItem if required
		if (fieldMap.get("returnItem") == null) {
			fields.push({
				name: "returnItem",
				doc: "Returns an item back into the pool \nGenerated by macro \n@param item item to be returned",
				access: [APublic, AStatic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [{name: "item", type: TPath(clazzTypePath)}],
					expr: macro pool.push(item),
				})
			});
		}

		// add getItem if required
		if (fieldMap.get("getItem") == null) {
			// put all expressions into an array
			var exprs: Array<Expr> = [];
			exprs.push(macro var item = pool.pop());

			// select the correct macro to create an item
			exprs.push(macro if (item == null) {
				item = $e{createItem};
			});
			exprs.push(macro return item);

			fields.push({
				name: "getItem",
				doc: "Retrieves an item from the object pool or creates one if necessary \nGenerated by macro \n@return item instance",
				access: [APublic, AStatic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [],
					expr: macro $b{exprs},
					ret: TPath(clazzTypePath)
				})
			});
		}

		return fields;
	}

	public static macro function build(): Array<Field> {
		return buildPoolable(Context.getBuildFields());
	}
}
