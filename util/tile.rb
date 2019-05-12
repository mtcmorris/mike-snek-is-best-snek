class Tile
  attr_reader :x, :y

  attr_accessor :walkable_neighbours

  def initialize(x:, y:)
    @x = x
    @y = y
  end

  def self.from_location(from_location)
    new(x: from_location.x, y: from_location.y)
  end

  def direction(other)
    if y < other.y
      'S'
    elsif y > other.y
      'N'
    elsif x > other.x
      'W'
    else
      'E'
    end
  end

  def ==(other)
    @x == other.x && @y == other.y
  end
end