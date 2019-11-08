package spork.example.geom;

//copied from TDS
class Point{
	public var x: Float;
	public var y: Float;

	public var length(get, set): Float;
	public var length2(get, null): Float;

	public var angle(get, set): Float;

	public static inline function distance(a: Point, b: Point): Float{
		return difference(a, b).length;
	}

	public static inline function fromPolar(rot: Float, length: Float): Point{
		return new Point(Math.sin(rot) * length, -Math.cos(rot) * length);
	}

	public static inline function translate(a: Point, b: Point): Point{
		return new Point(a.x+b.x, a.y+b.y);
	}

	public static function difference(a: Point, b: Point): Point{
		return new Point(a.x - b.x, a.y - b.y);
	}

	public static inline function scale(a: Point, m: Float): Point{
		return new Point(a.x*m, a.y*m);
	}

	public static inline function rotate(a: Point, angle: Float): Point{
		var cos=Math.cos(angle);
		var sin=Math.sin(angle);

		return new Point(a.x*cos-a.y*sin, a.x*sin+a.y*cos);
	}

	public static function dot(a: Point, b: Point): Float{
		return a.x * b.x + a.y * b.y;
	}

	public function new(x: Float=0, y: Float=0){
		this.x=x;
		this.y=y;
	}

	public function copy(): Point{
		return new Point(x, y);
	}

	public function add(other: Point){
		this.x+=other.x;
		this.y+=other.y;
	}

	public function sub(other: Point){
		x -= other.x;
		y -= other.y;
	}

	public function mult(m: Float){
		this.x*=m;
		this.y*=m;
	}

	public function normalize(){
		var len = length;
		if(len>0){
			mult(1 / length);
		}
	}

	public function turn(angle: Float){
		var cos=Math.cos(angle);
		var sin=Math.sin(angle);

		var newX=x*cos-y*sin;
		y=x*sin+y*cos;
		x=newX;
	}

	public function toString(): String{
		return "("+x+"; "+y+")";
	}

	//GETTERS AND SETTERS:

	private inline function get_length(): Float{
		return Math.sqrt(x*x+y*y);
	}

	private inline function get_length2(): Float{
		return x * x + y * y;
	}

	private inline function set_length(length: Float): Float{
		if(x==0 && y==0){
			x=length;
		}else{
			var oldLength=this.length;
			x*=length/oldLength;
			y*=length/oldLength;
		}

		return length;
	}

	private inline function get_angle(): Float{
		return Math.atan2(y, x) + Math.PI / 2;
	}

	private inline function set_angle(a: Float): Float{
		turn(a - get_angle());
		return a;
	}
}
