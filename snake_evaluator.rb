require 'pry'
require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'
require_relative './util/pathfinder'
require_relative './util/tile'
require_relative './util/path_2'

class Hash
  def to_point
    if keys.sort == ["x", "y"] || keys.sort == [:x, :y]
      Tile.new(x: self['x'] || self[:x], y: self['y'] || self[:y])
    else
      raise("No x,y on hash #{inspect}")
    end
  end
end

class SnakeEvaluator
  def initialize(our_snake, game_state, map)
    # Game state is an hash with the following structure
    # {
    #   alive_snakes: [{snake}],
    #   leaderboard: []
    # }
    # Each snake is made up of the following:
    # {
    #   id: id,
    #   name: name,
    #   head: {x: <int>, y: <int>,
    #   color: <string>,
    #   length: <int>,
    #   body: [{x: <int>, y: <int>}, etc.]
    # }
    @game_state = game_state.with_indifferent_access
    # Map is a 2D array of chars.  # represents a wall and '.' is a blank tile.
    # The map is fetched once - it does not include snake positions - that's in game state.
    # The map uses [y][x] for coords so @map[0][0] would represent the top left most tile
    @map = map
    @map_y_max = @map.length
    @map_x_max = @map[0].length
    @our_snake = our_snake.with_indifferent_access
    @current_position = @our_snake.fetch("head")
    @items = @game_state.fetch(:items)
  end

  def setup_pathfinder!
    matrix = @unsafe_squares.map{|row|
      row.map{|tile|
        if tile == "#"
          0
        else
          1
        end
      }
    }

    # First step - make all the nodes
    @pathfinder = LeePathFinder.new(matrix)

    # # Next step connect them
    # @two_d_array.each_with_index do |row, yPosition|
    #   row.each_with_index do |tile, xPosition|
    #     if @two_d_array[yPosition][xPosition]
    #       neighbours = [
    #         [yPosition - 1, xPosition],
    #         [yPosition + 1, xPosition],
    #         [yPosition, xPosition - 1],
    #         [yPosition, xPosition + 1]
    #       ]

    #       neighbours.reject!{|y, x| y < 0 || x < 0 || y >= @map_y_max || x >= @map_x_max }

    #       @two_d_array[yPosition][xPosition].walkable_neighbours = neighbours.map{|y,x| @two_d_array[y][x] }.compact
    #     end
    #   end
    # end
  end

  def current_tile
    @current_position.to_point
  end

  def food_present?
    @items.any?
  end

  def food_destination
    if @items.any?
      @items.min{|a, b|
        @pathfinder.distance(current_tile, a.fetch(:position).to_point) <=> @pathfinder.distance(current_tile, b.fetch(:position).to_point)
      }.fetch(:position).to_point
    end
  end

  def get_intent
    calculate_unsafe_map!

    setup_pathfinder!

    if food_present?
      path = @pathfinder.find_shortest_path(current_tile, food_destination)

      if path.length > 0
        puts "Moving by path - #{path.length} steps"
        return current_tile.direction(Tile.from_location(path.first))
      end
    end

    longest_path = @pathfinder.find_longest_path(current_tile)

    puts "Moving on a longer path: #{longest_path.length}"
    return current_tile.direction(Tile.from_location(longest_path.first))
  end

  def calculate_unsafe_map!
    # Don't crash into our body
    @unsafe_squares = Marshal.load(Marshal.dump(@map))

    @game_state.fetch(:alive_snakes).each do |other_snake|
      head_x = other_snake.fetch(:head).fetch(:x)
      head_y = other_snake.fetch(:head).fetch(:y)

      # Discount positions other snake may move to to prevent collisions
      if head_x != @current_position.fetch(:x) || head_y != @current_position.fetch(:y)
        possible_head_positions = [
          [head_y, head_x],
          [head_y, head_x + 1],
          [head_y, head_x - 1],
          [head_y + 1, head_x],
          [head_y - 1, head_x]
        ].reject{|y, x|
          y < 0 || y >= @map_y_max || x < 0 || x >= @map_x_max
        }

        possible_head_positions.each do |y, x|
          @unsafe_squares[y][x] = "#"
        end
      end

      # Ignore the tail of the snake - it'll be gone by the time we move
      other_snake.fetch(:body).slice(0..(other_snake.fetch(:body).length - 1)).each do |pos|
        @unsafe_squares[pos.fetch(:y)][pos.fetch(:x)] = "#"
      end
    end

    # Genererate a tile for us
    @unsafe_squares[@current_position.fetch(:y)][@current_position.fetch(:x)] = '.'

    @unsafe_squares
  end

  private

  def debug!
    # puts "ARRRGG - nothing.\n\nGame state:#{@game_state.inspect}\n\nPosition:#{@current_position}\n\nValid moves: #{valid_moves.inspect}\n\nUnsafe sq:#{@unsafe_squares}"

    puts "Map: #{print_map @map}\n"
    puts "Unsafe sq: #{print_map @unsafe_squares}\n"
    puts "Game state: #{@game_state.inspect}\n"
  end

  def print_map(array)
    array.map{|arr| arr.join }.join("\n")
  end



  def next_position(possible_intent, position = nil)
    position ||= @current_position
    case possible_intent
    when 'N' then {"y" => position.fetch(:y) - 1, "x" => position.fetch(:x)}
    when 'S' then {"y" => position.fetch(:y) + 1, "x" => position.fetch(:x)}
    when 'E' then {"y" => position.fetch(:y),     "x" => position.fetch(:x) + 1}
    when 'W' then {"y" => position.fetch(:y),     "x" => position.fetch(:x) - 1}
    end.with_indifferent_access
  end
end