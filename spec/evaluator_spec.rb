require_relative "../snake_evaluator"

describe SnakeEvaluator do
  let(:snake) { {"head" => {"x" => 1, "y" => 1}, "body" => []} }

  let(:game_state) { {
    "alive_snakes" => alive_snakes,
    "items" => []
    }
  }

  let(:alive_snakes) { [] }

  let(:map) { [
    ['.', '.', '.'],
    ['.', '.', '.'],
    ['.', '.', '.']
  ] }



  let(:evaluator) { SnakeEvaluator.new(snake, game_state, map) }
  subject { evaluator.get_intent }

  describe 'wall avoidance' do
    let(:map) { [
      ['#', '#', '#'],
      ['#', '.', '.'],
      ['#', '#', '#']
    ] }

    it 'should avoid the wall' do
      is_expected.to eq('E')
    end
  end

  describe 'other snake avoidance' do
    context 'when surrounded by heads' do
      let(:alive_snakes) { [
        {"head" => {"x" => 0, "y" => 1}, "body" => []},
        {"head" => {"x" => 2, "y" => 1}, "body" => []},
        {"head" => {"x" => 1, "y" => 0}, "body" => []}
      ] }

      it 'should avoid other snakes head' do
        is_expected.to eq('S')
      end
    end

    context 'when surrounded by tails' do
      let(:alive_snakes) { [
        {"head" => {"x" => 0, "y" => 1}, "body" => [{"x" => 2, "y" => 1}, {"x" => 1, "y" => 0}]},
      ] }

      it 'should avoid other snakes tail' do
        is_expected.to eq('S')
      end
    end
  end

  describe "preferencing free space" do
    let(:map) { [
      ['.', '#', '.', '.'],
      ['.', '.', '.', '.'],
      ['.', '#', '.', '.']
    ] }

    it 'should move into free space' do
      is_expected.to eq('E')
    end
  end

  describe "preferencing food" do
    let(:map) { [
      ['#', '#', '#'],
      ['.', '.', '.'],
      ['#', '#', '#']
    ] }

    it 'should move towards food' do

    end
  end
end