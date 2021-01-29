package spork.core;

/**
 * Provides wrapping for shared properties of basic types(Int, Float, etc.)
 */
class Wrapper<T> implements SharedProperty {
	public var value: T;

	public function new(value: T) {
		this.value = value;
	}

	public static function fromJson<T>(value: T): Wrapper<T> {
		return new Wrapper<T>(value);
	}
}
