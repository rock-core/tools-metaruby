# Metamodelling in the Ruby type system

* https://gitorious.org/rock-toolchain/metaruby

MetaRuby is a library that allows to (ab)use the Ruby type system to create
reflexive programs: create a specialized modelling API (a.k.a. "a DSL") at the
class/module level and then get access to this model information from the
objects.

This page will describe the various functionality that metaruby provides to help
modelling in Ruby.

This page will reuse one of the most overused example of modelling: a car and
colors.

## Models

Using MetaRuby, models can either be represented by Ruby classes or by Ruby
modules. You use the first one when you want to model something from which an
object can be created, in our example: a car. You use the second for things that
cannot be instanciated, but can be used as attributes of another object, in our
example: a color.

Another point of terminology: _metamodel_. The metamodel is the
model-of-the-model, i.e. it is the bits and pieces that allow to describe a
model (the model itself describing an object). As you will see, metamodels in
MetaRuby are all described in modules.

## Models as classes

The metamodel of models that are represented by classes must include
{MetaRuby::ModelAsClass} and are then used to extend said class

~~~
module Models
  module Car
    include MetaRuby::ModelAsClass
  end
end
class Car
  extend Models::Car
end
~~~

Then, creating a new Car model is done by subclassing the Car class:

~~~
class Peugeot < Car
  # Call methods from the modelling DSL defined by Models::Car
end
~~~

This creates a _named model_, i.e. a model that can be accessed by name. Another
way is to create an anonymous model by calling {MetaRuby::ModelAsClass#new_submodel new_submodel}:

~~~
model = Car.new_submodel do
  # Call methods from the modelling DSL defined by Models::Car
end
~~~

Note that this mechanism naturally extends to submodels-of-submodels, e.g.

~~~
class P806 < Peugeot
  # Call methods from the modelling DSL defined by Models::Car
end
~~~

## Models as modules

The metamodel of models that are represented by modules must include
{MetaRuby::ModelAsModule} and are then used to extend said module

~~~
module Models
  module Color
    include MetaRuby::ModelAsModule
  end
end
module Color
  extend Models::Color
end
~~~

Then, creating a new Color model is done by calling {MetaRuby::ModelAsModule#new_submodel new_submodel} on Color

~~~
red = Color.new_submodel
~~~

A common pattern is to define a method on the Module class, that creates new
models and assigns them to constants. MetaRuby provides a helper method for this
purpose, that we strongly recommend you use:

~~~
class Module
  def color(name, &block)
    MetaRuby::ModelAsModule.create_ang_register_submodel(self, name, Color, &block)
  end
end
~~~

Which can then be used with:

~~~
module MyNamespace
  color 'Red' do
    # Call methods from the color modelling DSL defined by Models::Color
  end
end
~~~

The new Red color model can then be accessed with MyNamespace::Red

A model hierarchy can be built by telling MetaRuby that a given model _provides_
another one, for instance:

~~~
color 'Yellow' do
  provides Red
  provides Green
end
~~~

And, finally, a class-based model can provide a module-based one:
   
~~~
class Peugeot < Car
  # All peugeots are yellow
  provides Yellow
end
~~~

# Attributes

One important part of the whole modelling is to list _attributes_ of the things
that are getting modelled. The important bit being the definition of what should
happen when creating a new submodel for an existing model. Even though we will
use the class-as-model representation in all the following examples, the exact
same mechanisms are available in the model-as-module. The only difference is
that a class-as-model is a submodel of all its parent classes while a
class-as-module is a submodel of all the other modules it provides.

# Zero-or-one attributes

These are attributes that hold at most one value (and possibly none). The
typical example is the predicate (boolean attribute)

~~~
module Models::Car
  include MetaRuby::ModelAsClass
 
  # Attribute inherited along the hierarchy of models
  inherited_single_value_attribute("number_of_doors")
end
~~~
~~~
class SportsCar < Car
  # Make the default number of doors of all sports car 2
  number_of_doors 2
end
class ASportsCar < SportsCar
  # Actually, this one has a trunk
  number_of_doors 3
end
class AnotherSportsCar < SportsCar
end
~~~
~~~
Car.number_of_doors => nil
SportsCar.number_of_doors => 2
ASportsCar.number_of_doors => 3
AnotherSportsCar.number_of_doors => 2 # Inherited from SportsCar
~~~

## Set attributes
These are attributes that hold a set of values. When taking into account the
hierarchy of models, the set for a model X is the union of all the sets of X and
all its parents:

~~~
module Models::Car
  include MetaRuby::ModelAsClass
  # Attribute inherited along the hierarchy of models
  inherited_attribute("material", "materials")
end
~~~
~~~
class Car
  extend Models::Car
  materials << 'iron' # all cars contain iron
end
class Peugeot < Car
  materials << 'plastic' # additionally, all peugeot cars contain plastic
end
~~~
~~~
Car.each_material.to_a => ['iron']
Peugeot.each_material.to_a => ['iron', 'plastic']
Car.all_materials => ['iron']
Peugeot.all_materials => ['iron', 'plastic']
Car.self_materials => ['iron']
Peugeot.self_materials => ['plastic']
~~~

## Named attributes
In certain situations, elements of the sets that we represented in the previous
section can actually have names (where the names are actually part of the
modelling). 

~~~
module Models::Car
  include MetaRuby::ModelAsClass
  # Attribute inherited along the hierarchy of models
  inherited_attribute("door_color", "door_colors")
  def number_of_doors
    all_door_colors.to_a.size
  end
end
~~~

~~~
class Car
  extend Models::Car
  door_colors['driver'] = Color # There is a driver door, but we don't know
                                # the color
  door_colors['other'] = Color # There is another door, but we don't know
                                # the color
end
class Peugeot < Car
  # All peugeot have a red driver door and a green trunk door
  door_colors['driver'] = Red
  door_colors['trunk'] = Green
end
~~~

~~~
Car.self_door_colors => {'driver' => Color, 'other' => Color }
Car.all_door_colors => {'driver' => Color, 'other' => Color }
Peugeot.self_door_colors => {'driver' => Red, 'trunk' => Green }
Peugeot.self_door_colors => {'driver' => Red, 'other' => Color, 'trunk' => Green }
~~~

## Value promotion
In some cases, one need to modify the values inherited from the parent models
before they can become proper attributes of the child model, commonly because
the objects stored in the attributes refer to the model they are part of. For
instance, let's assume we have a Door object defined thus:

~~~
Door = Struct :car_model, :color
~~~

and

~~~
Car.doors['driver'] = Door.new(Car, Color)
Car.doors['other'] = Door.new(Car, Color)
~~~

Now,

~~~
Peugeot.find_door('driver').car_model => Car
~~~

In most cases, we would like to have this last value be Peugeot. This can be
done by defining a promotion method on the metamodel _before_ the inherited
attribute is defined:

~~~
module Models::Car
  # Called to promote a door model from its immediate supermodel to this
  # model
  def promote_door(door_name, door)
    # You have to create a new door object !
    door = door.dup
    door.car_model = self
    door
  end

  # Define the attribute *after* the promotion method
  inherited_attribute("door", "doors")
end
~~~

# Model Registration
The last bit that MetaRuby takes care of is to register all models that have
been defined, allowing to browse them by type. For instance, all models based on
the Car model can be enumerated with:

~~~
Car.each_submodel
~~~

Because this mechanism keeps a reference on all model objects, it is necessary
to clear the registered submodels dealing with e.g. tests that create submodels
on the fly. This is done by calling {MetaRuby::Registration#clear_submodels
clear_submodels} in the tests teardown:

~~~
Car.clear_submodels
~~~

This will only clear anonymous models. Models that are created either by
subclassing a model class or by using
{MetaRuby::ModelAsModule#create_ang_register_submodel
create_ang_register_submodel} are marked as
{MetaRuby::Registration#permanent_model? permanent models} and therefore
protected from removal by #clear_submodel

# Adding options to the submodel creation process

If you need to customize the submodel creation process, for instance by
providing options to the subprocess, do so by overloading #setup_submodel. Do
NOT overload #new_submodel unless you really know what you are doing, and pass
the options as an option hash
