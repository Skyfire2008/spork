package spork.core;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Printer;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.TypeTools;
import haxe.macro.ExprTools;
import haxe.ds.StringMap;

import sys.FileSystem;

import haxe.io.Path;

using Lambda;

class Macro {
	private static var componentsClassPaths: Array<String> = [];
	private static var componentTypes: Array<Type> = null;
	private static var isNamingLong: Bool = false;
	private static var holderClassName: String;

	public static macro function setPropertyHolder(className: String): Void {
		holderClassName = className;
	}

	public static macro function setNamingLong(value: Bool): Void {
		isNamingLong = value;
	}

	public static macro function setComponentsClassPath(paths: Array<String>): Void {
		componentsClassPaths = paths;
	}

	public static macro function buildJsonLoader(): Array<Field> {
		var componentTypes = getComponentTypes();
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

					var typePath = makeTypePath(clazz);
					// make a mapping from field name to factory method, calling type's "fromJson(...)"
					return macro $v{getFieldNameFromClass(clazz)} => (json: Dynamic) -> {
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
			kind: FVar(macro:haxe.ds.StringMap<(Dynamic) -> spork.core.Component>, composExpr)
		});

		// add propFactories map
		var makePropFactory = (type: Type, propName: String) -> {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();

					// skip interfaces
					if (clazz.isInterface) {
						return null;
					}

					var typePath = makeTypePath(clazz);
					// make a mapping from field name to factory method, calling type's "fromJson(...)"
					return macro $v{propName} => (json: Dynamic, holder: spork.core.PropertyHolder) -> {
						// holder.{propName} = {typePath}.fromJson(json)
						holder.$propName = $p{typePath.pack.concat(typePath.sub != null ? [typePath.name, typePath.sub] : [typePath.name])}.fromJson(json);
					};
				case TAbstract(t, _):
					var abztract = t.get();

					var typePath = makeTypePath(abztract);
					// make a mapping from field name to factory method, calling type's "fromJson(...)"
					return macro $v{propName} => (json: Dynamic, holder: spork.core.PropertyHolder) -> {
						// holder.{propName} = {typePath}.fromJson(json)
						holder.$propName = $p{typePath.pack.concat(typePath.sub != null ? [typePath.name, typePath.sub] : [typePath.name])}.fromJson(json);
					};
				default:
			}
			return null;
		};

		var holderClassFields = TypeTools.getClass(Context.getType(holderClassName)).fields.get();
		for (field in holderClassFields) {
			var current = makePropFactory(field.type, field.name);
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
			kind: FVar(macro:haxe.ds.StringMap<(Dynamic, spork.core.PropertyHolder) -> Void>, propsExpr)
		});

		return fields;
	}

	public static macro function buildPropHolder(): Array<Field> {
		var fields = Context.getBuildFields();

		var classFields = TypeTools.getClass(Context.getType(holderClassName)).fields.get();
		for (field in classFields) {
			@:privateAccess
			fields.push(TypeTools.toField(field));
		}

		return fields;
	}

	public static macro function buildProperty(): Array<Field> {
		var clazz = Context.getLocalClass().get();
		var fields = Context.getBuildFields();

		// skip interfaces
		if (!clazz.isInterface) {
			// add "fromJson" if it's missing
			if (!fields.exists((item) -> {
				return item.name == "fromJson";
			})) {
				fields.push(makeFromJsonMethod(fields.find((item) -> {
					return item.name == "new";
				}), clazz));
			}
		}

		return fields;
	}

	public static macro function buildComponent(): Array<Field> {
		var fields = Context.getBuildFields();
		var clazz = Context.getLocalClass().get();

		// skip interfaces
		if (!clazz.isInterface) {
			// put all fields into a map
			var fieldNameMap: StringMap<Field> = new StringMap<Field>();
			for (field in fields) {
				fieldNameMap.set(field.name, field);
			}

			// if "clone" method doesn't exist, create it
			if (!fieldNameMap.exists("clone")) {
				fields.push(makeCloneMethod(fieldNameMap.get("new"), clazz));
			}

			// if "owner" doesn't exist, create it
			if (!fieldNameMap.exists("owner")) {
				fields.push({
					name: "owner",
					access: [APrivate],
					pos: Context.currentPos(),
					kind: FVar(macro:spork.core.Entity, macro null)
				});
			}

			// if "assignProps" doesn't exist, create it
			if (!fieldNameMap.exists("assignProps")) {
				// go through fields of component to find ones with @property
				var assignExprs: Array<Expr> = [];

				for (field in fields) {
					var propMeta = field.meta.find((e) -> {
						return e.name == "property";
					});
					if (propMeta != null) {
						var propName = field.name;
						var holderPropName: String;

						if (propMeta.params != null && propMeta.params.length > 0) {
							holderPropName = ExprTools.getValue(propMeta.params[0]);
						} else {
							holderPropName = field.name;
						}

						assignExprs.push(macro this.$propName = holder.$holderPropName);
					}
				}

				fields.push({
					name: "assignProps",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: "holder", type: macro:spork.core.PropertyHolder}],
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
						args: [{name: "holder", type: macro:spork.core.PropertyHolder}],
						ret: macro:Void,
						expr: macro {}
					})
				});
			}

			// if "fromJson" doesn't exist, create it
			if (!fieldNameMap.exists("fromJson")) {
				fields.push(makeFromJsonMethod(fieldNameMap.get("new"), clazz));
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
					if (isSubClass(interfaze, componentClass, false)) {
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
						args: [{name: "owner", type: macro:spork.core.Entity}],
						ret: macro:Void,
						expr: macro $b{exprs}
					})
				});
			}
		}

		return fields;
	}

	public static macro function buildEntity(): Array<Field> {
		var fields = Context.getBuildFields();
		var compoTypes: Array<Type> = [];

		for (path in componentsClassPaths) {
			compoTypes = getComponentTypes();
		}
		for (type in compoTypes) {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();
					trace(clazz.name);

					// only process interfaces
					if (clazz.isInterface) {
						var fieldName = "";
						var entry = clazz.meta.extract("name");
						var params = entry.length > 0 ? entry[0].params : [];

						// get name for component array
						if (params.length > 0) {
							fieldName = ExprTools.getValue(params[0]);
						} else {
							fieldName = (clazz.name.charAt(0)).toLowerCase() + clazz.name.substring(1);
						}

						var field: Field = null;
						var isSingular: Bool = false;
						if (clazz.meta.has("singular")) {
							isSingular = true;
							// if singular, add a field of given component type
							field = {
								name: fieldName,
								access: [APublic],
								pos: Context.currentPos(),
								kind: FieldType.FVar(TypeTools.toComplexType(type))
							};
						} else {
							// otherwise add component array field
							fieldName = fieldName + "s";
							field = {
								name: fieldName,
								access: [APublic],
								pos: Context.currentPos(),
								kind: FieldType.FVar(TPath({name: "Array", pack: [], params: [TPType(TypeTools.toComplexType(type))]}), macro [])
							};
						}

						fields.push(field);

						// add callback method
						for (classField in clazz.fields.get()) {
							if (classField.meta.has("callback")) {
								fields.push(makeEntityCallback(classField, fieldName, isSingular));
							}
						}
					}
				default:
			}
		}

		return fields;
	}

	#if macro
	private static function makeFromJsonMethod(constructor: Field, clazz: ClassType): Field {
		// check that constructor exists
		if (constructor == null) {
			Context.error('Class ${clazz.name} has no constructor, cannot create static method "fromJson"', Context.currentPos());
		}

		// create arguments for the call (json.arg1, ... json.argn)
		var callArgs: Array<Expr> = [];
		switch (constructor.kind) {
			case FFun(f):
				for (arg in f.args) {
					var name = arg.name;
					callArgs.push(macro json.$name);
				}
			default:
		}

		// create constructor call
		var classPath = makeTypePath(clazz);
		var funcExpr = macro return new $classPath($a{callArgs});

		// create method field
		return {
			name: "fromJson",
			access: [APublic, AStatic],
			pos: Context.currentPos(),
			kind: FFun({
				args: [{name: "json", type: macro:Dynamic}],
				ret: TPath(classPath),
				expr: funcExpr
			})
		};
	}

	private static inline function makeCloneMethod(constructor: Field, clazz: ClassType): Field {
		// check that constructor exists
		if (constructor == null) {
			Context.error('Class ${clazz.name} has no constructor, cannot create method "clone"', Context.currentPos());
		}

		// get call arguments of the constructor
		var callArgs: Array<Expr> = [];
		switch (constructor.kind) {
			case FFun(f):
				for (arg in f.args) {
					callArgs.push(macro $i{arg.name});
				}
			default:
		}

		// create clone function expression
		var classPath = makeTypePath(clazz);
		var funcExpr = macro return new $classPath($a{callArgs});

		// create clone method field
		return {
			name: "clone",
			access: [APublic],
			pos: Context.currentPos(),
			kind: FFun({
				args: [],
				ret: TPath(classPath),
				expr: funcExpr
			})
		};
	}

	private static inline function makeTypePath(clazz: BaseType): TypePath {
		var result: TypePath = {name: clazz.name, pack: clazz.pack};
		var module = clazz.module.substring(clazz.module.lastIndexOf(".") + 1);
		if (clazz.name != module) { // for sub-types, typepath name is set to module name, and sub is set to actual type name
			result.name = module;
			result.sub = clazz.name;
		}

		return result;
	}

	/**
	 * Retrieves the array of types implementing Component
	 */
	private static inline function getComponentTypes(): Array<Type> {
		if (componentTypes == null) {
			var componentClass = TypeTools.getClass(Context.getType("spork.core.Component"));
			componentTypes = [];

			for (path in componentsClassPaths) {
				componentTypes = componentTypes.concat(getSubClasses(componentClass, getTypes(path), true));
			}
		}

		return componentTypes;
	}

	/**
	 * Creates a callback method for entity, calling callbacks of all appropriate components
	 * @param callbackField
	 * @param arrayName
	 * @return Field
	 */
	private static function makeEntityCallback(callbackField: ClassField, fieldName: String, isSingular: Bool): Field {
		var methodName = callbackField.name;
		var argDefs;
		var retType: Type;

		// extract the return type and call arguments from class field
		switch (callbackField.type) {
			case TFun(args, ret):
				argDefs = args;
				retType = ret;
			default:
		}

		// create array of expression for callback call arguments and function arguments for field
		var callArgs: Array<Expr> = [];
		var fieldArgs: Array<FunctionArg> = [];
		for (argDef in argDefs) {
			callArgs.push(macro $i{argDef.name});
			fieldArgs.push({
				name: argDef.name,
				type: TypeTools.toComplexType(argDef.t),
				opt: argDef.opt,
			});
		}

		// create function expression using reification
		var callback: Expr = null;
		if (isSingular) {
			callback = macro return $p{[fieldName, methodName]}($a{callArgs});
		} else {
			callback = macro for (c in $i{fieldName}) {
				c.$methodName($a{callArgs});
			};
		}

		// define the field
		var field: Field = {
			name: methodName,
			access: [APublic],
			pos: Context.currentPos(),
			kind: FFun({
				ret: TypeTools.toComplexType(retType),
				expr: callback,
				args: fieldArgs
			})
		}

		return field;
	}

	/**
	 * Generats name for a field containg an instance of given class
	 * @param clazz
	 * @return String
	 */
	private static inline function getFieldNameFromClass(clazz: ClassType): String {
		var meta = clazz.meta.extract("name");
		var fieldName: String;

		// first, try to get the name from metadata
		if (meta.length > 0 && meta[0].params.length > 0) {
			fieldName = ExprTools.getValue(meta[0].params[0]);
		} else {
			// otherwise, get it from classpath
			var pack: Array<String> = [];
			if (!isNamingLong) {
				pack = [clazz.name];
			} else {
				pack = clazz.pack.concat([clazz.name]);
			}

			var nameBuf: StringBuf = new StringBuf();

			// generate the name according to the format: package1.package2.Class -> package1Package2Class
			for (i in 0...pack.length) {
				var word = pack[i];
				if (i == 0) {
					nameBuf.add(word.substr(0, 1).toLowerCase());
				} else {
					nameBuf.add(word.substr(0, 1).toUpperCase());
				}
				nameBuf.addSub(word, 1);
			}

			fieldName = nameBuf.toString();
		}

		return fieldName;
	}

	/**
	 * Check if given class type etends or implements another one
	 * @param clazz class type to check
	 * @param superClass super class
	 * @param recursive check recursively
	 * @return true, if it's a subclass, false otherwise
	 */
	private static function isSubClass(clazz: ClassType, superClass: ClassType, recursive: Bool): Bool {
		// check the superclass first
		if (clazz.superClass != null) {
			var actualSuperClass = clazz.superClass.t.get();
			if (actualSuperClass.name == superClass.name && actualSuperClass.pack.join(".") == superClass.pack.join(".")) {
				return true;
			}
			if (recursive && isSubClass(actualSuperClass, superClass, recursive)) {
				return true;
			}
		}

		// then check the interfaces
		if (superClass.isInterface) {
			for (foo in clazz.interfaces) {
				var inter = foo.t.get();
				if (inter.name == superClass.name && inter.pack.join(".") == superClass.pack.join(".")) {
					return true;
				}
				if (recursive && isSubClass(inter, superClass, recursive)) {
					return true;
				}
			}
		}

		return false;
	}

	/**
	 * Gets subclasses of a given superclass from an array of types
	 * @param superClass cuperclass class type
	 * @param types array of types to check
	 * @return Array<Type>
	 */
	private static function getSubClasses(superClass: ClassType, types: Array<Type>, recursive: Bool): Array<Type> {
		var result: Array<Type> = [];

		for (type in types) {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();
					if (isSubClass(clazz, superClass, recursive)) {
						result.push(type);
					}
				default:
			}
		}

		return result;
	}

	/**
	 * Gets types from class path recursively
	 * @param filePath current file path
	 * @param classPath current class path
	 * @param result current array of types
	 * @return array of types
	 */
	private static function getTypesRec(filePath: String, classPath: String, result: Array<Type>): Array<Type> {
		FileSystem.readDirectory(filePath).iter((file) -> {
			var currentPath = Path.join([filePath, file]);
			// if current path is a directory, apply getTypesRec to it recursively
			if (FileSystem.isDirectory(currentPath)) {
				getTypesRec(currentPath, classPath + '.$file', result);
				// otherwise if it's a module, get its types and add them to result
			} else if (file.lastIndexOf(".hx") == file.length - 3) {
				Context.getModule(classPath + "." + file.substring(0, file.length - 3)).iter((type) -> {
					result.push(type);
				});
			}
		});

		return result;
	}

	/**
	 * Gets types from the provided class path
	 * @param classPath class path as string
	 * @return array of types
	 */
	public static function getTypes(classPath: String): Array<Type> {
		var filePath = classPath.split(".");

		for (path in Context.getClassPath()) {
			var currentPath = Path.join([path].concat(filePath));
			if (FileSystem.isDirectory(currentPath)) {
				return getTypesRec(currentPath, classPath, []);
			}
		}

		trace('No path contains package $classPath');
		return null;
	}
	#end
}
