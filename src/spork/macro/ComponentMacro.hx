package spork.macro;

import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.ds.StringMap;

import spork.core.Macro;

using Lambda;

class ComponentMacro {
	public static macro function build(): Array<Field> {
		var fields = Context.getBuildFields();
		var clazz = Context.getLocalClass().get();

		// skip interfaces
		if (!clazz.isInterface) {
			// put all fields into a map
			var fieldNameMap: StringMap<Field> = new StringMap<Field>();
			for (field in fields) {
				fieldNameMap.set(field.name, field);
			}

			// check if it's poolable
			var isPoolable = false;
			var poolableT = ComplexTypeTools.toType(macro : spork.util.Poolable);
			for (foo in clazz.interfaces) {
				var t = TInst(foo.t, foo.params);
				if (TypeTools.unify(t, poolableT)) {
					isPoolable = true;
					break;
				}
			}

			// if "componentType" doesn't exist, create it
			if (!fieldNameMap.exists("componentType")) {
				var componentTypeValue = Macro.getFieldNameFromClass(clazz);
				fields.push({
					name: "componentType",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FProp("default", "never", macro : spork.core.ComponentType, macro spork.core.ComponentType.$componentTypeValue)
				});
			}

			// if "clone" method doesn't exist, create it
			if (!fieldNameMap.exists("clone")) {
				if (!isPoolable) {
					fields.push(Macro.makeCloneMethod(fieldNameMap.get("new"), clazz));
				} else { // if object is poolable, clone() must fetch an instance from the pool and set its parameters first

					// check if setParams(...) is generated by poolable macro or has no arguments
					var canClone = false;
					var setParams = fieldNameMap.get("setParams");
					if (setParams != null) {
						var meta = setParams.meta.find(entry -> entry.name == "genByMacro");
						if (meta != null) {
							canClone = true;
						} else {
							switch (setParams.kind) {
								case FFun(f):
									if (f.args == null || f.args.length == 0) {
										canClone = true;
									}
								default:
							}
						}
					}

					// create the clone(...) method
					if (canClone) {
						var funcExprs: Array<Expr> = [];
						funcExprs.push(macro var item = getItem()); // fetch item from pool

						// get setParams(...) arguments
						var callArgs: Array<Expr> = [];
						switch (setParams.kind) {
							case FFun(f):
								for (arg in f.args) {
									callArgs.push(macro $i{arg.name});
								}
							default:
						}
						funcExprs.push(macro item.setParams($a{callArgs})); // set item params
						funcExprs.push(macro return item); // return item

						// create field itself
						var classPath = Macro.makeTypePath(clazz);
						fields.push({
							name: "clone",
							access: [APublic],
							pos: Context.currentPos(),
							kind: FFun({
								args: [],
								ret: TPath(classPath),
								expr: macro $b{funcExprs}
							})
						});
					} else {
						Context.warning('Cannot generate method clone(...) for class ${clazz.name}: setParams has unusual arguments', Context.currentPos());
					}
				}
			}

			// if "owner" doesn't exist, create it
			if (!fieldNameMap.exists("owner")) {
				fields.push({
					name: "owner",
					access: [APrivate],
					pos: Context.currentPos(),
					kind: FVar(macro : spork.core.Entity, macro null)
				});
			}

			// if "assignProps" doesn't exist, create it
			if (!fieldNameMap.exists("assignProps")) {
				var assignExprs: Array<Expr> = [];

				// go through fields of component to find ones with @prop
				for (field in fields) {
					// skip if field has no metadata
					if (field.meta != null) {
						var propMeta = field.meta.find((e) -> {
							return e.name == "prop";
						});

						// if has @prop...
						if (propMeta != null) {
							var propName = field.name;
							var holderPropName: String;

							// try to get the value of metadata, that's the name of property on holder, otherwise name is the same as field name
							if (propMeta.params != null && propMeta.params.length > 0) {
								holderPropName = ExprTools.getValue(propMeta.params[0]);
							} else {
								holderPropName = field.name;
							}

							assignExprs.push(macro this.$propName = holder.$holderPropName);
						}
					}
				}

				fields.push({
					name: "assignProps",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: "holder", type: macro : spork.core.PropertyHolder}],
						ret: null,
						expr: macro $b{assignExprs}
					})
				});
			}

			// if "createProps" doesn't exist, create it
			if (!fieldNameMap.exists("createProps")) {
				fields.push({
					name: "createProps",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: "holder", type: macro : spork.core.PropertyHolder}],
						ret: macro : Void,
						expr: macro {}
					})
				});
			}

			// if "fromJson" doesn't exist, create it
			if (!fieldNameMap.exists("fromJson")) {
				fields.push(Macro.makeFromJsonMethod(fieldNameMap.get("new"), clazz));
			}

			// if "attach" doesn't exist, create it
			if (!fieldNameMap.exists("attach")) {
				var exprs: Array<Expr> = [];
				// add owner assignment
				exprs.push(macro this.owner = owner);

				// for every interface implemented by this component...
				var componentClass = TypeTools.getClass(Context.getType("spork.core.Component"));
				for (foobar in clazz.interfaces) {
					var interfaze = foobar.t.get();
					// only process interfaces extending Component
					if (Macro.isSubClass(interfaze, componentClass, false)) {
						// get name for component array
						var entry = interfaze.meta.extract("name");
						var params = entry.length > 0 ? entry[0].params : [];
						var componentFieldName: String;

						if (params.length > 0) {
							componentFieldName = ExprTools.getValue(params[0]);
						} else {
							componentFieldName = (interfaze.name.charAt(0)).toLowerCase() + interfaze.name.substring(1);
						}

						// if component is singular, assign this as its value
						if (interfaze.meta.has("singular")) {
							exprs.push(macro owner.$componentFieldName = this);
						} else {
							// otherwise, push the component into the array
							componentFieldName += "s";
							exprs.push(macro owner.$componentFieldName.push(this));
						}
					}
				}

				fields.push({
					name: "attach",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: "owner", type: macro : spork.core.Entity}],
						ret: macro : Void,
						expr: macro $b{exprs}
					})
				});
			}
		}

		return fields;
	}
}
