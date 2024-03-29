require_relative "../snake_evaluator"

describe SnakeEvaluator do
  let(:snake) { {"head" => {"x" => 1, "y" => 1}, "body" => []} }

  let(:game_state) { {
    "alive_snakes" => alive_snakes,
    "items" => items
    }
  }

  let(:alive_snakes) { [] }
  let(:items) { [] }

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

  describe "offense" do
    let(:map) { [
      ['.', '.', '.'],
      ['.', '.', '.'],
      ['.', '#', '.'],
      ['.', '#', '.'],
      ['.', '#', '.']
    ] }
    let(:snake) { {"head" => {"x" => 1, "y" => 1}, "body" => []} }

    let(:alive_snakes) { [
      {"head" => {"x" => 2, "y" => 3}, "body" => []}
    ] }

    it 'should take opportunities to screw over other snakes' do
      is_expected.to eq('E')
    end
  end

  describe "avoiding dead ends" do
    let(:map) { [
      ['.', '.', '.'],
      ['.', '.', '.'],
      ['.', '#', '.'],
      ['.', '#', '.']
    ] }

    let(:snake) { {"head" => {"x" => 2, "y" => 2}, "body" => []} }

    let(:items) { [{"position" => {"y" => 3, "x" => 2} }] }

    it "should move away" do
      is_expected.to eq('N')
    end
  end

  describe "preferencing food" do
    let(:map) { [
      ['#', '#', '#'],
      ['.', '.', '.'],
      ['.', '#', '.'],
      ['.', '#', '.'],
      ['.', '#', '.']
    ] }

    let(:snake) { {"head" => {"x" => 0, "y" => 3}, "body" => []} }

    let(:items) { [{"position" => {"y" => 4, "x" => 2} }] }

    it 'should move towards food' do
      is_expected.to eq('N')
    end

    context 'when there is multiple food items' do
      let(:map) { [
        ['.', '.', '.'],
        ['.', ',', '.'],
        ['.', '.', '.'],
        ['.', '.', '.']
      ] }

      let(:items) { [{"position" => {"x" => 0, "y" => 0} },{"position" => {"x" => 1, "y" => 3} }] }

      it 'should go for the closest one' do
        is_expected.to eq('E')
      end
    end

    context 'when an enemy is closer to food than your snake' do
      let(:map) { [
        ['.', '.', '.', '.', '.'],
        ['.', ',', '.', '.', '.'],
        ['.', '.', '.', '.', '.'],
        ['.', '.', '.', '.', '.'],
        ['.', '.', '.', '.', '.']
      ] }

      let(:snake) { {"head" => {"x" => 0, "y" => 4}, "body" => []} }

      let(:alive_snakes) { [
        {"head" => {"x" => 4, "y" => 2}, "body" => []}
      ] }

      let(:items) { [{"position" => {"x" => 0, "y" => 0} },{"position" => {"x" => 2, "y" => 3} }] }

      it 'should go for the one it can get one' do
        is_expected.to eq('N')
      end
    end
  end
end