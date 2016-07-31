require 'json'

class PlayerShip
  MAX_HPS = {"w" => 3, "c" => 2, "s" => 1}
  attr :type
  attr_accessor :position, :hp

  def initialize(type, position)
    if !MAX_HPS.has_key?(type)
      raise ArgumentError, "invalid type supecified"
    end

    @type = type
    @position = position
    @hp = MAX_HPS[type]
  end

  def moved(to)
    @position = to
  end

  def damaged(d)
    @hp -= d
  end

  def reachable?(to)
    @position[0] == to[0] || @position[1] == to[1]
  end

  def attackable?(to)
    (to[0] - @position[0]).abs <= 1 && (to[1] - @position[1]).abs <= 1
  end
end

class Player
  FIELD_SIZE = 5
  attr :ships

  def initialize(positions)
    @ships = {}
    positions.each do |type, position|
      @ships[type] = PlayerShip.new(type, position)
    end
  end

  def initial_condition
    cond = {}
    @ships.values.each do |ship|
      cond[ship.type] = ship.position
    end
    cond.to_json
  end

  def action
  end

  def update(json)
    cond = JSON.parse(json)["condition"]["me"]
    @ships.keys.each do |type|
      if !cond.has_key?(type)
        @ships.delete(type)
      else
        @ships[type].hp = cond[type]["hp"]
        @ships[type].position = cond[type]["position"]
      end
    end
  end

  def move(type, to)
    ship = @ships[type]
    ship.moved(to)
    {
        "move" => {
            "ship" => type,
            "to" => to
        }
    }
  end

  def attack(to)
    {
        "attack" => {
            "to" => to
        }
    }
  end

  def attacked(to)
    ship = overlap(to)

    if !ship.nil?
      ship.damaged(1)

      if ship.hp == 0
        @ships.delete(ship.type)
      end
    end
  end

  def attackable?(to)
    Player.in_field?(to) && @ships.values.any?{|ship| ship.attackable?(to)}
  end

  def self.in_field?(position)
    position[0] < FIELD_SIZE && position[1] < FIELD_SIZE &&
        position[0] >= 0 && position[1] >= 0
  end

  def overlap(position)
    @ships.values.each do |ship|
      if ship.position == position
        return ship
      end
    end
    nil
  end
end
