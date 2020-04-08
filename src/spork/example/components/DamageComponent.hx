package spork.example.components;

@component
interface DamageComponent {
	@callback
	function onDamage(dmg: Float, source: spork.example.Entity): Void;
}
