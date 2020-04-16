package spork.core;

/**
 * Component, defines new behaviour for entities
 */
@:autoBuild(spork.core.Macro.buildComponent())
interface Component {
	/**
	 * Clones this component
	 * @return clone
	 */
	public function clone(): Component;

	/**
	 * Assigns properties to this component from shared property holder
	 * @param holder shared property holder to gget properties from
	 */
	public function assignProps(holder: PropertyHolder): Void;

	/**
	 * Attaches this component to an entity
	 * @param ownew entity to attach to
	 */
	public function attach(owner: Entity): Void;
}
