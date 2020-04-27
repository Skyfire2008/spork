# Spork
Spork is a minimalistic component framework.

## Core parts:
* `Entity` class, stores components in arrays grouped by their callback method and also has callbacks, which call the callback method of all appropriate components(see further).
* `Component` interface. Interfaces extending `Component` are used to define callback methods, which will be added to the `Entity` class by macros. For example:
```haxe
interface UpdateComponent extends Component {
	@callback
	function update(time: Float): Void;

	//...
}
```
results in the following `Entity`:
```haxe
class Entity {
	public var updateComponents: Array<UpdateComponent>;

	public function update(time: Float): Void{
		for(c in updateComponents){
			c.update(time);
		}
	}
	//...
}
```
* `SharedProperty` interface. Its implementations designate data, that is shared between different components(I know, this is not that good, since, for example for such properties as `velocity` and `position`, which are both 2d vectors, user would have to create 2 separate classes, but I'm working on that).
* `PropertyHolder` class temporarily storing the shared properties read from the template, before they are assigned to components.
* `JsonLoader` class, allowing the user to create entities from JSON templates loaded at runtime. JSON files must have 2 top-level properties, `properties` and `components`, containing the shared properties and components respectively. Properties of every shared property and component are the same as attribute of their constructors. For example, if we wish to create a basic enemy entity, using the following shared properties and components:
```haxe
class Health implements SharedProperty{
	public function new(maxHp: Int){ /*...*/}
	//...
}

class CollisionBox implements SharedProperty{
	public function new(x: Float, y: Float, width: Float, height: Float){ /*...*/ }
	//...
}

interface UpdateComponent implements Component{
	@callback
	function onUpdate(time: Float);
}

class DrawComponent implements UpdateComponent{
	public function new(reference: String){ /*...*/ }
	//...
} 

interface HitPlayerComponent implements Component{
	@callback
	function onhitPlayer(player: Player);
}

class DamangePlayerOnHitComponent implements HitPlayerComponent{
	public function new(damageMult: Float){ /*...*/ }
}

interface DeathComponent implements Component{
	@callback
	function onDeath();
}

class DropHealthOnDeath extends DeathComponent{
	public function new(probability: Float){ /*...*/ }
	//...
}
```
we would use the following template:
```jsonc
{
	"properties": {
		"health": {"maxHp": 100},
		"collisionBox": {"x": -5, "y": -1, "width": 10, "height": 10},
	},
	"components": {
		"DrawComponent": {"reference": "basicEnemy.png"},
		"DropHealthOnDeath": {"probability": 0.1},
		"DamagePlayerOnHitComponent": {"damageMult": 0.25}
	}
}
```

## Setup:
Several intialization macros to setup spork are available:
* `setComponentsClassPath(paths: Array<String>)` - set the paths, used to get the components.
* `setPropClassPath(paths: Array<String>)` - same, but for shared properties.
* `setNamingLong(value: Bool)` - sets the default naming method for fields of `Entity` and `PropertyHolder`.

## Example project:
https://github.com/Skyfire2008/sporkExample