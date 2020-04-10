package spork.example.properties;

import spork.core.PropertyHolder;
import spork.core.SharedProperty;

@name("health")
class Health implements SharedProperty {
	public var hp: Int;
	public var maxHp: Int;

	public function new(hp: Int) {
		this.hp = hp;
		this.maxHp = hp;
	}

	public function clone(): SharedProperty {
		return new Health(this.hp);
	}

	public function attach(owner: PropertyHolder) {
		owner.health = this;
	}
}
