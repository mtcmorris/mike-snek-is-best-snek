require 'pry'
require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'

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
    @our_snake = our_snake.with_indifferent_access
    @current_position = @our_snake.fetch("head")
  end

  def get_intent
    # Let's ensure we don't die
    valid_moves = non_death_moves

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

  def non_death_moves
    possible_moves = ["N", "S", "E", "W"]

    # Don't crash into our body
    @unsafe_squares = Marshal.load(Marshal.dump(@map))

    @game_state.fetch(:alive_snakes).each do |other_snake|
      @unsafe_squares[other_snake.fetch(:head).fetch(:y)][other_snake.fetch(:head).fetch(:x)] = "#"

      other_snake.fetch(:body).each do |pos|
        @unsafe_squares[pos.fetch(:y)][pos.fetch(:x)] = "#"
      end
    end

    possible_moves.reject!{|possible_intent|
      next_pos = next_position(possible_intent)
      @unsafe_squares[next_pos.fetch(:y)][next_pos.fetch(:x)] == '#'
    }

    possible_moves


    # possible_moves.reject!{|possible_intent|
    #   @our_snake.fetch(:body).include?(next_position(possible_intent).with_indifferent_access)
    # }

    # # Walls
    # possible_moves.reject!{|possible_intent|
    #   next_pos = next_position(possible_intent)
    #   @map[next_pos.fetch(:y)][next_pos.fetch(:x)] == '#'
    # }

    # # Other snake avoidance
    # possible_moves.reject!{|possible_intent|
    #   next_pos = next_position(possible_intent)

    #   @game_state.fetch(:alive_snakes).detect{|other| other.fetch(:head) == next_pos || other.fetch(:body).include?(next_pos) }
    # }

    # possible_moves
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