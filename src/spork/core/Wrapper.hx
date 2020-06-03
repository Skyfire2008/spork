package spork.core;

/**
 * Provides wrapping for shared properties of basic types(Int, Float, etc.)
 */
class Wrapper<T> {
	public var value: T;

	public function new(value: T) {
		this.value = value;
	}
}
