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

@noField
class RegenHealth extends Health {
	public var regen: Float;

	public function new(hp: Int, regen: Float) {
		super(hp);
	}

	public override function clone(): SharedProperty {
		return new RegenHealth(this.hp, regen);
	}

	public override function attach(owner: PropertyHolder) {
		owner.health = this;
	}
}
