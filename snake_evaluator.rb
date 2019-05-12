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
    @map = map.map{|row|
      row.map{|tile|
        if tile == "#"
          0
        else
          1
        end
      }
    }
    @map_y_max = @map.length
    @map_x_max = @map[0].length
    @our_snake = our_snake.with_indifferent_access

    @other_snakes = @game_state.fetch(:alive_snakes).select{|s| s != @our_snake }
    @current_position = @our_snake.fetch("head")
    @items = @game_state.fetch(:items).map{|item| item.fetch(:position).to_point }
  end

  def setup_pathfinder!
    # First step - make all the nodes
    @pathfinder = LeePathFinder.new unsafe_matrix(@our_snake, @other_snakes)

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

  def enemy_pathfinder(enemy)
    them_for_enemy = @other_snakes - [@our_snake] - [enemy]
    LeePathFinder.new unsafe_matrix(enemy, them_for_enemy)
  end

  def current_tile
    @current_position.to_point
  end

  def food_present?
    @items.any?
  end

  def food_destination
    @food_destination ||= begin
      @items.select{|item|
        is_closest_snake?(item)
      }.sort{|a,b|
        @pathfinder.distance(current_tile, a) <=> @pathfinder.distance(current_tile, b)
      }.first
    end
  end

  def is_closest_snake?(item_position)
    return true if @other_snakes.empty?
    closest = @other_snakes.map{|other| @pathfinder.distance(other.fetch(:head).to_point, item_position) }.min

    closest > @pathfinder.distance(current_tile, item_position)
  end

  def enemies_near?
    return false if @other_snakes.empty?
    @other_snakes.map{|other| @pathfinder.distance(other.fetch(:head).to_point, current_tile) }.min <= 4
  end

  def nearest_enemy
    @other_snakes.min{|a,b| @pathfinder.distance(a.fetch(:head).to_point, current_tile) <=> @pathfinder.distance(b.fetch(:head).to_point, current_tile) }
  end

  def get_intent
    setup_pathfinder!

    if food_destination
      path = @pathfinder.find_shortest_path(current_tile, food_destination)

      if path.length > 0
        puts "Eating by path - #{path.length} steps"
        return current_tile.direction(Tile.from_location(path.first))
      end
    end

    if enemies_near?
      nearest = nearest_enemy
      enemy_position = nearest_enemy.fetch(:head).to_point
      nearest_pathfinder = enemy_pathfinder(nearest)
      nearest_path = nearest_pathfinder.find_longest_path(enemy_position)
      target_node = nearest_path.detect{|node|
        @pathfinder.distance(node, current_tile) < @pathfinder.distance(node, enemy_position)
      }
      if target_node
        path = @pathfinder.find_shortest_path(current_tile, target_node)

        if path.length > 0
          puts "Attacking - #{path.length} steps"
          return current_tile.direction(Tile.from_location(path.first))
        end
      end
    end

    longest_path = @pathfinder.find_longest_path(current_tile)

    if longest_path.empty?
      return "N" # We're dead
    elsif longest_path.length < 20
      # Conserve space strat
      reverse_longest_tile = @pathfinder.find_longest_path(longest_path.last).first
      path = @pathfinder.find_shortest_path(current_tile, reverse_longest_tile)
      puts "Conserving space"
      current_tile.direction(Tile.from_location(path.first))
    else
      puts "Free space -  longer path: #{longest_path.length}"
      return current_tile.direction(Tile.from_location(longest_path.first))
    end
  end

  def unsafe_matrix(me, them)
    # Don't crash into our body
    matrix = Marshal.load(Marshal.dump(@map))

    them.each do |other_snake|
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
          matrix[y][x] = 0
        end
      end

      # Ignore the tail of the snake - it'll be gone by the time we move
      other_snake.fetch(:body).slice(0..(other_snake.fetch(:body).length - 1)).each do |pos|
        matrix[pos.fetch(:y)][pos.fetch(:x)] = 0
      end
    end

    me.fetch(:body).slice(0..(me.fetch(:body).length - 1)).each do |pos|
      matrix[pos.fetch(:y)][pos.fetch(:x)] = 0
    end

    # Genererate a tile for us
    matrix[me.fetch(:head).fetch(:y)][me.fetch(:head).fetch(:x)] = 1

    matrix
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