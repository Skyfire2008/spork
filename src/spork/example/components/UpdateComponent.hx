package spork.example.components;

import spork.core.Component;
import spork.core.Entity;
import spork.core.PropertyHolder;
import spork.example.geom.Point;

@name
interface UpdateComponent extends Component {
	@callback
	function update(time: Float): Void;
}

class Move implements UpdateComponent {
	private var vel: Point;
	private var pos: Point;

	public function new() {}

	public function update(time: Float): Void {
		pos.add(Point.scale(vel, time));
	}

	public function assignProps(holder: PropertyHolder) {
		this.pos = holder.position;
		this.vel = holder.velocity;
	}

	public function attach(owner: Entity) {
		owner.updateComponents.push(this);
	}

	public function clone(): Component {
		return new Move();
	}
}
