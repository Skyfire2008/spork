package spork.example.components;

@name
interface DamageComponent extends spork.core.Component {
	@callback
	function onDamage(dmg: Float, source: spork.core.Entity): Void;
}
