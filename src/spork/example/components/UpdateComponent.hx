package spork.example.components;

import spork.core.Component;

import spork.example.geom.Point;

interface UpdateComponent extends Component{
	function update(time: Float): Float;
}

class Move implements UpdateComponent{

	private var vel: Point;
	private var pos: Point;

	public function update(time: Float){
		pos.add(Point.scale(vel, time));
	}

}
