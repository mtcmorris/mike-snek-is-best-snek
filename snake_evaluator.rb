# :wave: This was a hack project built very quickly at Railscamp as a client for https://github.com/ferocia/snek
# :heart: for @cmaitchison for a big chunk of code/ideas

require 'pry'
require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'
require_relative './util/tile'
require_relative './util/lee_path_finder'

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

  def get_intent
    # The main - game strategy
    move = intent_from_snake_strategy


    # This is all just error checking to see that if our main strategy is sensible
    new_y, new_x = case move
    when 'N' then [current_tile.y - 1, current_tile.x]
    when 'S' then [current_tile.y + 1, current_tile.x]
    when 'E' then [current_tile.y, current_tile.x + 1]
    when 'W' then [current_tile.y, current_tile.x - 1]
    else [0, 0] # Dead on invalid move
    end

    new_position = Tile.new(x: new_x, y: new_y)
    @pathfinder.matrix[current_tile.y][current_tile.x] = 0

    new_longest = @pathfinder.find_longest_path(new_position)

    if new_longest.nil? || (new_longest.length < 30 && new_longest.length < (longest_path.length / 2))
      puts "Taking defensive measures - got given path #{move} from strat but bailing as path length is #{new_longest.length} (vs #{longest_path.length})"
      return current_tile.direction(Tile.from_location(longest_path.first))
    else
      move
    end
  end

  def intent_from_snake_strategy
    setup_pathfinder!

    # Objective 1: - seek close food - food is close if there isn't other snakes nearby
    if wants_food?
      path = @pathfinder.find_shortest_path(current_tile, food_destination)

      if path.length > 0
        puts "Eating by path - #{path.length} steps"
        return current_tile.direction(Tile.from_location(path.first))
      end
    end

    # Objective 2: - Attack.  If there's a snake nearby is there an opportunity for us to reduce its longest path
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

    if longest_path.empty?
      return "N" # We're dead
    elsif should_conserve?
      # Objective 3: - If space constrained, conserve as much space as possible
      # In this strat we need a pathfinder where our head is unpathable
      conserve_pathfinder = LeePathFinder.new unsafe_matrix(@our_snake, @other_snakes, head_unpathable: true)

      begin
        reverse_path = conserve_pathfinder.find_longest_path(longest_path.last)
        reverse_longest_tile = reverse_path.last
        if reverse_longest_tile == current_tile
          reverse_longest_tile = reverse_path[-2]
        end
        path = @pathfinder.find_shortest_path(current_tile, reverse_longest_tile)
        puts "Conserving space"
      rescue
        return "N" #We're dead anyway
      end

      if path && path.first
        return current_tile.direction(Tile.from_location(path.first))
      end
    else
      # Objective 4: Move into open space
      puts "Free space -  longer path: #{longest_path.length}"
      return current_tile.direction(Tile.from_location(longest_path.first))
    end

    return "N"
  end


  def setup_pathfinder!
    @pathfinder = LeePathFinder.new unsafe_matrix(@our_snake, @other_snakes, head_unpathable: false)
  end

  # Returns a pathfinder within the context of an enemy - eg head logic/matrix etc are different depending on the enemy
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
    @other_snakes.map{|other| @pathfinder.distance(other.fetch(:head).to_point, current_tile) }.min <= 6
  end

  def nearest_enemy
    @other_snakes.min{|a,b| @pathfinder.distance(a.fetch(:head).to_point, current_tile) <=> @pathfinder.distance(b.fetch(:head).to_point, current_tile) }
  end

  def wants_food?
    is_small? && food_destination
  end

  def is_small?
    @our_snake.fetch(:body).length < 120
  end

  def should_conserve?
    if is_small? && longest_path.length < 20
      true
    elsif !is_small?
      true
    end
  end

  def longest_path
    @longest_path ||= @pathfinder.find_longest_path(current_tile)
  end

  def unsafe_matrix(me, them, head_unpathable: false)
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
    if head_unpathable
      matrix[me.fetch(:head).fetch(:y)][me.fetch(:head).fetch(:x)] = 0
    end

    matrix
  end

  private

  def debug!
    puts "Map: #{print_map @map}\n"
    puts "Unsafe sq: #{print_map @unsafe_squares}\n"
    puts "Game state: #{@game_state.inspect}\n"
  end

  def print_map(array)
    array.map{|arr| arr.join }.join("\n")
  end
end