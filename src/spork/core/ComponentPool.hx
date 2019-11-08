package spork.core;

#if !macro
@:genericBuild(spork.core.Macro.buildPool())
#end
class ComponentPool<T: Component>{

	private var pool: List<T>;
	private var currentInst: T = null;

	private function new(){
		this.pool = new List<T>();
	}

	public function returnInst(inst: T){
		pool.add(inst);
	}

}
