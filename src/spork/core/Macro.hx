package spork.core;

import haxe.CallStack;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.TypeTools;
import haxe.macro.ExprTools;

import sys.thread.Thread;
import sys.FileSystem;

import haxe.io.Path;

using Lambda;

class Macro {
	public static var componentsClassPaths(default, null): Array<String> = [];
	private static var componentTypes: Array<Type> = null;
	private static var isNamingLong: Bool = false;
	public static var holderClassName(default, null): String;
	public static var objectPoolsEnabled(default, null) = false;

	public static macro function useObjectPools(): Void {
		objectPoolsEnabled = true;
	}

	public static macro function setPropertyHolder(className: String): Void {
		holderClassName = className;
	}

	public static macro function setNamingLong(value: Bool): Void {
		isNamingLong = value;
	}

	public static macro function setComponentsClassPath(paths: Array<String>): Void {
		componentsClassPaths = paths;
	}

	public static macro function populateComponentTypeArray(): Void {
		Context.onAfterInitMacros(() -> {
			getComponentTypes();
		});
	}

	/**
	 * Provides an expression fetching an entity, either new or from the entity object pool based on settings
	 * @param entVar 		entity variable
	 * @param templateName 	template name
	 * @return Expr
	 */
	public static macro function getEntity(entVar: Expr, templateName: ExprOf<String>): Expr {
		if (objectPoolsEnabled) {
			var exprs: Array<Expr> = [];
			exprs.push(macro $e{entVar} = Entity.getItem());
			exprs.push(macro $e{entVar}.setParams($e{templateName}));
			return macro $b{exprs};
		} else {
			return macro ${entVar} = new Entity($e{templateName});
		}
	}

	#if macro
	public static function makeFromJsonMethod(constructor: Field, clazz: ClassType): Field {
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
				args: [{name: "json", type: macro : Dynamic}],
				ret: TPath(classPath),
				expr: funcExpr
			})
		};
	}

	public static inline function makeCloneMethod(constructor: Field, clazz: ClassType): Field {
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

	public static inline function makeTypePath(clazz: BaseType): TypePath {
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
	public static function getComponentTypes(): Array<Type> {
		if (componentTypes == null) {
			var componentClass = TypeTools.getClass(Context.getType("spork.core.Component"));

			var result: Array<Type> = [];
			for (path in componentsClassPaths) {
				for (type in getSubClasses(componentClass, getTypes(path), true)) {
					result.push(type);
				}
			}

			componentTypes = result;
		}
		return componentTypes;
	}

	/**
	 * Creates a callback method for entity, calling callbacks of all appropriate components
	 * @param callbackField
	 * @param arrayName
	 * @return Field
	 */
	public static function makeEntityCallback(callbackField: ClassField, fieldName: String, isSingular: Bool): Field {
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
	public static inline function getFieldNameFromClass(clazz: ClassType): String {
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
	 * Check if given class type extends or implements another one
	 * @param clazz class type to check
	 * @param superClass super class
	 * @param recursive check recursively
	 * @return true, if it's a subclass, false otherwise
	 */
	public static function isSubClass(clazz: ClassType, superClass: ClassType, recursive: Bool): Bool {
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
	 * @param superClass superclass class type
	 * @param types array of types to check
	 * @return Array<Type>
	 */
	private static function getSubClasses(superClass: ClassType, types: Array<Type>, recursive: Bool): Array<Type> {
		var result: Array<Type> = [];

		for (type in types) {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get(); // <<< here, tries to construct component types
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
