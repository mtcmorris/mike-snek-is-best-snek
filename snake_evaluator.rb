require 'pry'
require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'
require_relative './util/pathfinder'
require_relative './util/tile'

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
    # First step - make all the nodes
    @pathfinder = Pathfinder.new(@map_x_max, @map_y_max)
    @unsafe_squares.each_with_index do |row, yPosition|
      row.each_with_index do |tile, xPosition|
        if tile == "#"
          @pathfinder.add_obstacle(x: xPosition, y: yPosition)
        end
      end
    end

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
        return current_tile.direction(Tile.from_location(path.first.location))
      end
    end

    possible_paths = 20.times.map{
      x, y = [rand(@map_x_max), rand(@map_y_max)]
      if @unsafe_squares[y][x] != '#'
        Tile.new(x: x, y: y)
      end
    }.compact.uniq.map{|possible_destination|
      path = @pathfinder.find_shortest_path(current_tile, possible_destination)

      if path.length > 20
        puts "Bailed quickly with a longer path - found one of #{path.length} to x: #{path.first.location.x}, y: #{path.first.location.y}"
        return current_tile.direction(Tile.from_location(path.first.location))
      end
      path
    }

    possible_paths.sort!{|a,b| b.length <=> a.length }

    if possible_paths.first && !possible_paths.first.empty?
      path = possible_paths.first
      puts "Moving by longer path - found one of #{path.length} to x: #{path.first.location.x}, y: #{path.first.location.y}"
      return current_tile.direction(Tile.from_location(path.first.location))
    end
    # Let's ensure we don't die
    valid_moves = non_death_moves

    puts "Moving by free space"

    rank = movement_rank(valid_moves).sort{|a, b| b[:score] <=> a[:score] }

    if rank.any?
      rank.first[:intent]
    else
      debug!
      valid_moves.sample || ['N', 'S', 'E', 'W'].sample
    end
  end

  def movement_rank(intents)
    intents.map{|intent|
      {intent: intent, score: score_for_intent(intent)}
    }
  end

  def score_for_intent(intent)
    position = next_position(intent)

    coords_to_eval = [
      {"y" => position["y"] - 1, "x" => position["x"]},
      {"y" => position["y"] + 1, "x" => position["x"]},
      {"y" => position["y"],     "x" => position["x"] - 1},
      {"y" => position["y"],     "x" => position["x"] + 1}
    ]

    coords_to_eval.reject!{|coord| coord["y"] < 0 || coord["x"] < 0 || coord["y"] >= @unsafe_squares.length || coord["x"] >= @unsafe_squares[0].length }

    safe_positions = coords_to_eval.select{|coord|
      @unsafe_squares[coord["y"]][coord["x"]] != "#"
    }.count
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
        ]

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


  def non_death_moves
    possible_moves = ['N', 'S', 'E', 'W']

    possible_moves.reject!{|possible_intent|
      @our_snake.fetch(:body).include?(next_position(possible_intent).with_indifferent_access)
    }

    # Walls
    possible_moves.reject!{|possible_intent|
      next_pos = next_position(possible_intent)
      @map[next_pos.fetch(:y)][next_pos.fetch(:x)] == '#'
    }

    # Other snake avoidance
    possible_moves.reject!{|possible_intent|
      next_pos = next_position(possible_intent)

      @game_state.fetch(:alive_snakes).detect{|other| other.fetch(:head) == next_pos || other.fetch(:body).include?(next_pos) }
    }

    possible_moves
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