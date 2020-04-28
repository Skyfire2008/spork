package spork.example.properties;

import spork.core.SharedProperty;

interface Dummy extends SharedProperty {
	public var value(get, set): Float;
}
