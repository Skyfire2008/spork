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

class Macro {
	private static var propClassPaths: Array<String> = [];

	public static macro function setPropClassPath(paths: Array<String>): Void {
		propClassPaths = paths;
	}

	// TODO: check if shared property is not an interface
	public static macro function buildPropHolder(): Array<Field> {
		var propTypes: Array<Type> = [];
		var fields = Context.getBuildFields();

		// get the class paths for properties from metadata

		var propClass = TypeTools.getClass(Context.getType("spork.core.SharedProperty"));
		for (path in propClassPaths) {
			propTypes = propTypes.concat(getSubClasses(propClass, getTypes(path), true));
		}

		// add shared property fields
		for (type in propTypes) {
			// get field name
			var name: String = "";
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();
					var meta = clazz.meta.extract("name");
					// if @name($fieldName) metadata defined, use it
					if (meta.length > 0 && meta[0].params.length > 0) {
						name = ExprTools.getValue(meta[0].params[0]);
					} else {
						// otherwise, generate the name from class package and name
						name = makeVarName(clazz.pack.concat([clazz.name]));
					}
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
		var className = Context.getLocalClass().get().name;

		// put the property fields into map
		var fieldNameMap: StringMap<Field> = new StringMap<Field>();
		for (field in fields) {
			fieldNameMap.set(field.name, field);
		}

		// create clone method
		if (!fieldNameMap.exists("clone")) {
			var constructor = fieldNameMap.get("new");

			if (constructor == null) {
				Context.error('Shared property $className has no constructor, cannot create method "clone"', Context.currentPos());
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
			var classPath: TypePath = {
				name: className,
				pack: []
			};
			var funcExpr = macro return new $classPath($a{callArgs});

			// create clone method field
			fields.push({
				name: "clone",
				access: [APublic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [],
					ret: TPath(classPath),
					expr: funcExpr
				})
			});
		}

		// create attach method
		if (!fieldNameMap.exists("attach")) {
			// get name of the field containing this property in property holder
			var meta = Context.getLocalClass().get().meta.extract("name");
			var fieldName: String;

			if (meta.length > 0 && meta[0].params.length > 0) {
				fieldName = ExprTools.getValue(meta[0].params[0]);
			} else {
				var clazz = Context.getLocalClass().get();
				fieldName = makeVarName(clazz.pack.concat([clazz.name]));
			}

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

		return fields;
	}

	public static macro function buildEntity(): Array<Field> {
		var fields = Context.getBuildFields();
		var compoTypes: Array<Type> = [];

		var composClassPath = Context.getLocalClass().get().meta.extract("componentsClassPath");
		if (composClassPath.length == 0) {
			Context.error("No components class path metadata(@componentsClassPath) provided for entity", Context.currentPos());
		}

		for (path in composClassPath) {
			compoTypes = compoTypes.concat(getTypes(ExprTools.getValue(path.params[0])));
		}
		for (type in compoTypes) {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();

					// get all callback components
					if (clazz.isInterface && clazz.meta.has("component")) {
						var arrayName = "";
						var params = clazz.meta.extract("component")[0].params;

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
	 * Gets a field name for property from package, according to the following format:
	 * org.example.Module.Type -> orgExampleModuleType
	 * @param pack package array
	 * @return String
	 */
	private static inline function makeVarName(pack: Array<String>): String {
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
}
