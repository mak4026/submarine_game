require('test/unit')
require_relative('../lib/player.rb')
require 'json'

class T_Player < Test::Unit::TestCase

  def test_player_ship_new
    assert_raise do
      PlayerShip.new("a", [0,0])
    end
    w = PlayerShip.new("w", [1,1])
    assert_equal("w", w.type)
    assert_equal(3, w.hp)
    assert_equal([1,1], w.position)
  end

  def test_player_ship_moved
    w = PlayerShip.new("w", [1,1])
    w.moved([1,2])
    assert_equal(w.position, [1,2])
  end

  def test_player_ship_damaged
    w = PlayerShip.new("w", [1,1])
    w.damaged(1)
    assert_equal(w.hp, 2)
  end

  def test_player_ship_reachable?
    w = PlayerShip.new("w", [0,0])
    assert_equal(true, w.reachable?([0,4]))
    assert_equal(true, w.reachable?([4,0]))
    assert_equal(false, w.reachable?([1,1]))
  end

  def test_ship_attackable?
    w = PlayerShip.new("w", [2,2])
    assert_equal(true, w.attackable?([2, 3]))
    assert_equal(true, w.attackable?([3, 1]))
    assert_equal(true, w.attackable?([3, 3]))
    assert_equal(false, w.attackable?([2, 0]))
  end
  
  def test_player_new
    p = Player.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal([0,0], p.ships["w"].position)
    assert_equal([0,1], p.ships["c"].position)
    assert_equal([1,0], p.ships["s"].position)
  end

  def test_player_initial_condition
    p = Player.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal({"w" => [0,0], "c" => [0,1], "s" => [1,0]}.to_json, p.initial_condition)
  end

  def test_player_update
    p = Player.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    json = {
        "condition" =>{
            "me" => {
                "w" => {
                    "hp" => 2,
                    "position" => [0, 0]
                },
                "c" => {
                    "hp" => 2,
                    "position" => [0, 4]
                },
                "s" => {
                    "hp" => 1,
                    "position" => [1, 0]
                }
            }
        }
    }.to_json
    p.update(json)
    assert_equal(2, p.ships["w"].hp)
    assert_equal([0, 4], p.ships["c"].position)
  end

  def test_player_move
    p = Player.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal({"move" => {"ship" => "w", "to" => [0, 2]}}, p.move("w", [0,2]))
    assert_equal([0,2], p.ships["w"].position)
  end

  def test_player_attack
    p = Player.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal({"attack" => {"to" => [1, 1]}}, p.attack([1,1]))
  end

  def test_player_attacked
    p = Player.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_nil(p.attacked([5,5]))
    p.attacked([0, 0])
    assert_equal(2, p.ships["w"].hp)
    p.attacked([1, 0])
    assert_equal(false, p.ships.has_key?("s"))
  end

  def test_player_overlap
    p = Player.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_nil(p.overlap([1,1]))
    assert_equal(p.ships["w"], p.overlap([0,0]))
  end

  def test_player_in_field?
    assert_equal(true, Player.in_field?([0,0]))
    assert_equal(false, Player.in_field?([5,5]))
    assert_equal(false, Player.in_field?([-1,0]))
  end
end
