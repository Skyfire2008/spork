package spork.core;

import spork.core.PropertyHolder;

/**
 * Represents a property shared between several components
 */
@:autoBuild(spork.core.Macro.buildProperty())
interface SharedProperty {
	// function clone(): SharedProperty;
	// function attach(owner: PropertyHolder): Void;
}
