package spork.util;

/**
 * Macro adds the following properties:
 * 
 * private static var pool: DynamicArray<T>
 * 
 * public static function getItem(): T
 * 
 * public static function returnItem(item: T): Void
 * 
 * public static function initPool():Void
 * 
 * public function setParams(...): Void
 * 
 * Add a metadata @initialPoolSize to set the initial pool size
 * 
 * Constructor must have no arguments or only optional arguments or class must have a method:
 * private static function defaultConstructor(): T
 */
@:autoBuild(spork.macro.PoolableMacro.build())
interface Poolable {}
