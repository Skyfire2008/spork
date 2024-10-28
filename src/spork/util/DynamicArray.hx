package spork.util;

// use vector for all targets except for hashlink, cause hashlink's vector uses a dynamic array for some reason
#if hl
import hl.NativeArray;
#else
typedef NativeArray<T> = haxe.ds.Vector<T>;
#end

@:forward(push, pop, iterator, length, size, grow, clear)
abstract DynamicArray<T>(DynamicArrayData<T>) from DynamicArrayData<T> to DynamicArrayData<T> {
	public inline function new(length: Int) {
		this = new DynamicArrayData<T>(length);
	}

	@:op([])
	private inline function get(i: Int) {
		return this.getValue(i);
	}

	@:op([])
	private inline function set(i: Int, value: T) {
		return this.setValue(i, value);
	}
}

class DADIterator<T> {
	private var array: DynamicArrayData<T>;
	private var pos: Int;

	public function new(array: DynamicArrayData<T>) {
		this.array = array;
	}

	public inline function hasNext(): Bool {
		return pos < array.length;
	}

	public inline function next(): T {
		return array.getValue(pos++);
	}
}

@:generic
class DynamicArrayData<T> {
	private var array: NativeArray<T>;

	/**
	 * Currently occupied cells
	 */
	public var length(default, null): Int;

	/**
	 * Total length
	 */
	public var size(get, null): Int;

	public function new(length: Int) {
		this.array = new NativeArray<T>(length);
		this.length = 0;
	}

	/**
	 * Doubles the total length of array
	 */
	public function grow() {
		var newArray = new NativeArray<T>(array.length * 2);
		#if hl
		newArray.blit(0, array, 0, array.length);
		#else
		NativeArray.blit(array, 0, newArray, 0, array.length);
		#end
		this.array = newArray;
	}

	/**
	 * Sets occupied cells length to 0, thus marking them as empty
	 */
	public function clear() {
		this.length = 0;
	}

	/**
	 * Adds a new item to the back of the array, growing it if needed
	 * @param value item to add
	 */
	public function push(value: T) {
		if (length >= array.length) {
			grow();
		}

		array[length] = value;
		length++;
	}

	/**
	 * Removes last item from the array and returns it
	 * @return last item
	 */
	public function pop(): Null<T> {
		if (length > 0) {
			length--;
			return array[length];
		} else {
			return null;
		}
	}

	// TODO: make it inline(right now Vec2's returned by it are wrong), same with push and setValue
	public inline function getValue(i: Int): T {
		return array[i];
	}

	public inline function setValue(i: Int, value: T): T {
		array[i] = value;
		return value;
	}

	public function iterator() {
		return new DADIterator(this);
	}

	private inline function get_size(): Int {
		return array.length;
	}
}
