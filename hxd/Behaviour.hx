package hxd;

class Behaviour {
	var 	obj:h3d.scene.Object;
	public function new(o: h3d.scene.Object) { obj = o;  o.addBehaviour(this); }
	public function dispose() { obj.removeBehaviour(this); obj = null; }
	public function update() { }

	public function clone(c) : hxd.Behaviour {
		throw "Please implement me";
		return null;
	}
}