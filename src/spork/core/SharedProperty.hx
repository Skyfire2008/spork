package spork.core;

import spork.core.PropertyHolder;

/**
 * Represents a property shared between several components
 */
@:autoBuild(spork.core.Macro.buildProperty())
interface SharedProperty {
	/**
	 * Clones this shared property
	 * @return clone
	 */
	function clone(): SharedProperty;

	/**
	 * Attaches this shared property to shared property holder
	 * @param owner property holder to attach to
	 */
	function attach(owner: PropertyHolder): Void;
}
