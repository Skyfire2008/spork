package spork.core;

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

enum NamingType {
	Short;
	Long;
}

class Macro {
	private static var propClassPaths: Array<String> = [];
	private static var componentsClassPaths: Array<String> = [];
	private static var propTypes: Array<Type> = null;
	private static var componentTypes: Array<Type> = null;
	private static var namingType: NamingType = Short;

	public static macro function setNamingType(type: NamingType): Void {
		namingType = type;
	}

	public static macro function setComponentsClassPath(paths: Array<String>): Void {
		componentsClassPaths = paths;
	}

	public static macro function setPropClassPath(paths: Array<String>): Void {
		propClassPaths = paths;
	}

	public static macro function buildJsonLoader(): Array<Field> {
		var propTypes = getPropTypes();
		var componentTypes = getComponentTypes();
		var fields = Context.getBuildFields();
		var propMapDecl: Array<Expr> = [];
		var componentMapDecl: Array<Expr> = [];

		var makeMapping = (type: Type) -> {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();

					// skip interfaces
					if (clazz.isInterface) {
						return null;
					}

					// get array of call arguments for property constructor
					var callArgs: Array<Expr> = [];
					var constructor = clazz.constructor.get();
					switch (constructor.type) {
						case TFun(args, _):
							trace(args);
							for (arg in args) {
								var name = arg.name;
								callArgs.push(macro json.$name);
							}
						case TLazy(f): // in case the typing is not completed
							switch (f()) {
								case TFun(args, _):
									for (arg in args) {
										var name = arg.name;
										callArgs.push(macro json.$name);
									}
								default:
							}
						default:
					}

					// create part of map declaration
					var typePath = makeTypePath(clazz);
					return macro $v{getFieldNameFromClass(clazz)} => (json: Dynamic) -> {
						return new $typePath($a{callArgs});
					};

				default:
			}
			return null;
		}

		// for every property type...
		for (type in propTypes) {
			var current = makeMapping(type);
			if (current != null) {
				propMapDecl.push(current);
			}
		}

		// add propFactories map
		fields.push({
			name: "propFactories",
			access: [APublic, AStatic],
			pos: Context.currentPos(),
			kind: FVar(macro:haxe.ds.StringMap < (Dynamic) -> spork.core.SharedProperty >, {pos: Context.currentPos(), expr: EArrayDecl(propMapDecl)})
		});

		// for every component type...
		for (type in componentTypes) {
			var current = makeMapping(type);
			if (current != null) {
				componentMapDecl.push(current);
			}
		}

		// add componentFactories map
		fields.push({
			name: "componentFactories",
			access: [APublic, AStatic],
			pos: Context.currentPos(),
			kind: FVar(macro:haxe.ds.StringMap < (Dynamic) -> spork.core.Component >, {pos: Context.currentPos(), expr: EArrayDecl(componentMapDecl)})
		});

		return fields;
	}

	public static macro function buildPropHolder(): Array<Field> {
		var propTypes: Array<Type> = getPropTypes();
		var fields = Context.getBuildFields();

		// add shared property fields
		for (type in propTypes) {
			// get field name
			var name: String = "";
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();

					if (clazz.isInterface) {
						continue;
					}

					name = getFieldNameFromClass(clazz);
				default:
			}

			fields.push({
				name: name,
				access: [APublic],
				pos: Context.currentPos(),
				kind: FVar(TypeTools.toComplexType(type), null)
			});
		}

		// add

		return fields;
	}

	// TODO: skip interfaces
	public static macro function buildProperty(): Array<Field> {
		var fields = Context.getBuildFields();
		var clazz = Context.getLocalClass().get();

		// put the property fields into map
		var fieldNameMap: StringMap<Field> = new StringMap<Field>();
		for (field in fields) {
			fieldNameMap.set(field.name, field);
		}

		// create clone method
		if (!fieldNameMap.exists("clone")) {
			fields.push(makeCloneMethod(fieldNameMap.get("new"), clazz));
		}

		// create attach method
		if (!fieldNameMap.exists("attach")) {
			// get name of the field containing this property in property holder
			var clazz = Context.getLocalClass().get();
			var fieldName = getFieldNameFromClass(clazz);

			var funcExpr = macro(owner.$fieldName = this);

			fields.push({
				name: "attach",
				access: [APublic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [{name: "owner", type: macro:spork.core.PropertyHolder}],
					ret: null,
					expr: funcExpr
				})
			});
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

			// if "assignProps" doesn't exist, create it
			if (!fieldNameMap.exists("assignProps")) {
				fields.push({
					name: "assignProps",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: "holder", type: macro:spork.core.PropertyHolder}],
						ret: null,
						expr: null
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

					// only process interfaces
					if (clazz.isInterface) {
						var arrayName = "";
						var params = clazz.meta.extract("name")[0].params;

						// get name for component array
						if (params.length > 0) {
							arrayName = ExprTools.getValue(params[0]);
						} else {
							arrayName = (clazz.name.charAt(0)).toLowerCase() + clazz.name.substring(1) + "s";
						}

						// add component array field
						var field: Field = {
							name: arrayName,
							access: [APublic],
							pos: Context.currentPos(),
							kind: FieldType.FVar(TPath({name: "Array", pack: [], params: [TPType(TypeTools.toComplexType(type))]}), null)
						};

						fields.push(field);

						// add callback method
						for (classField in clazz.fields.get()) {
							if (classField.meta.has("callback")) {
								fields.push(makeEntityCallback(classField, arrayName));
								break;
							}
						}
					}
				default:
			}
		}

		return fields;
	}

	#if macro
	private static inline function makeCloneMethod(constructor: Field, clazz: ClassType): Field {
		// check that constructor exists
		if (constructor == null) {
			Context.error('Shared property ${clazz.name} has no constructor, cannot create method "clone"', Context.currentPos());
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

	private static inline function makeTypePath(clazz: ClassType): TypePath {
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
	 * Retrieves the array of types implementing SharedProperty
	 */
	private static inline function getPropTypes(): Array<Type> {
		if (propTypes == null) {
			var propClass = TypeTools.getClass(Context.getType("spork.core.SharedProperty"));
			propTypes = [];

			for (path in propClassPaths) {
				propTypes = propTypes.concat(getSubClasses(propClass, getTypes(path), true));
			}
		}

		return propTypes;
	}

	/**
	 * Creates a callback method for entity, calling callbacks of all appropriate
	 * @param callbackField
	 * @param arrayName
	 * @return Field
	 */
	private static function makeEntityCallback(callbackField: ClassField, arrayName: String): Field {
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
		var callback = macro for (c in $i{arrayName}) {
			c.$methodName($a{callArgs});
		};

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
			if (namingType == Short) {
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
