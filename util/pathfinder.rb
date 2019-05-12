require 'polaris'
require 'line_of_sight'
require_relative './snek_two_d_map'

#Monkey path grid map to allow access to grid
class TwoDGridMap
  attr_accessor :grid
end

class Pathfinder
  attr_reader :map, :pather

  def initialize(x_dimension, y_dimension)
    @map    = SnekTwoDGridMap.new x_dimension, y_dimension

    @pather = Polaris.new @map
  end

  def add_obstacle(x:, y:)
    @map.place TwoDGridLocation.new(x, y)
  end

  def find_shortest_path(from_point, to_point)
    path_from = TwoDGridLocation.new from_point.x, from_point.y
    path_to   = TwoDGridLocation.new to_point.x, to_point.y

    (@pather.guide(path_from, path_to, nil, 20000) || [])
  end

  def distance(from, to)
    @map.distance(from, to)
  end
end
