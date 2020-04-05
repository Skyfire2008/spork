package spork.core;

import haxe.ds.StringMap;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.TypeTools;
import haxe.macro.ExprTools;

import sys.io.File;
import sys.FileSystem;

import haxe.io.Path;

using Lambda;

class Macro {
	public static macro function buildPropHolder(): Array<Field> {
		var propTypes: Array<Type> = [];
		var fields = Context.getBuildFields();

		// get the class paths for properties from metadata

		trace(Context.getLocalClass().get().meta.get());
		var propsClassPaths = Context.getLocalClass().get().meta.extract("propertiesClassPath");
		if (propsClassPaths.length == 0) {
			Context.error("Property holder must have properties class paths (@propertiesClassPath)", Context.currentPos());
		} else {
			var propClass = TypeTools.getClass(Context.getType("spork.core.SharedProperty"));
			for (path in propsClassPaths) {
				propTypes = propTypes.concat(getSubClasses(propClass, getTypes(ExprTools.getValue(path.params[0]))));
			}
		}
		// getSubClasses(TypeTools.getClass(Context.getType("spork.core.Component")), getTypes("spork"));

		// add shared property fields
		var counter = 0;
		for (type in propTypes) {
			fields.push({
				name: 'var$counter',
				access: [APublic],
				pos: Context.currentPos(),
				kind: FVar(TypeTools.toComplexType(type), null)
			});
			counter++;
		}

		return fields;
	}

	public static macro function buildComponent(): Array<Field> {
		var fields = Context.getBuildFields();

		return fields;
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
	 * @return true, if it's a subclass, false otherwise
	 */
	private static function isSubClass(clazz: ClassType, superClass: ClassType): Bool {
		// check the superclass first
		if (clazz.superClass != null) {
			var actualSuperClass = clazz.superClass.t.get();
			if (actualSuperClass.name == superClass.name && actualSuperClass.pack.join(".") == superClass.pack.join(".")) {
				return true;
			}
			if (isSubClass(actualSuperClass, superClass)) {
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
				if (isSubClass(inter, superClass)) {
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
	private static function getSubClasses(superClass: ClassType, types: Array<Type>): Array<Type> {
		var result: Array<Type> = [];

		for (type in types) {
			switch (type) {
				case TInst(t, _):
					var clazz = t.get();
					if (isSubClass(clazz, superClass)) {
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
