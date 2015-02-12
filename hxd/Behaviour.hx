package hxd;

class Behaviour {
	public var 		obj(default, null):h3d.scene.Object;
	
	public var 		beforeChildren = false;
	
	public function new(o: h3d.scene.Object) 				{ obj = o;  o.addBehaviour(this); }
	
	public function destroy() 								{ obj.removeBehaviour(this); obj = null; }
	public function update() 								{ }

	public function clone(c) : hxd.Behaviour {
		throw "Please implement me";
		return null;
	}
}