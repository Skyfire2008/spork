package spork.util;

/**
 * Macro adds the following properties:
 * 
 * public static var instance: T;
 * public static function setInstance(instance: T) 
 *
 */
@:autoBuild(spork.macro.SingletonMacro.build())
interface Singleton {}
