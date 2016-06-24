# coding: utf-8
require 'json'

class Ship
  MAX_HPS = {"w" => 3, "c" => 2, "s" => 1}
  attr :type, :position, :hp

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

class Client
  FIELD_SIZE = 5
  attr_reader :ships
  
  def initialize(positions)
    @ships = {}
    positions.each do |type, position|
      if overlap(position)
        raise ArgumentError, "given overlapping positions"
      end
      @ships[type] = Ship.new(type, position)
    end
  end

  def move(type, to)
    ship = @ships[type]
    
    if ship.nil? || !Client.in_field?(to) || !ship.reachable?(to) || !overlap(to).nil?
      return false
    end

    distance = [to[0] - ship.position[0], to[1] - ship.position[1]]
    ship.moved(to)
    {"ship" => type, "distance" => distance}
  end

  def attacked(to)
    if !Client.in_field?(to)
      return false
    end
    
    info = {"position" => to}
    ship = overlap(to)
    near = near(to)

    if !ship.nil?
      ship.damaged(1)
      info["hit"] = ship.type

      if ship.hp == 0
        @ships.delete(ship.type)
      end
    end
    
    info["near"] = near.map{|s| s.type}

    info
  end

  def condition(me)
    cond = {}
    @ships.values.each do |ship|
      cond[ship.type] = {"hp" => ship.hp}
      if me
        cond[ship.type]["position"] = ship.position
      end  
    end
    cond
  end

  def attackable?(to)
    Client.in_field?(to) && @ships.values.any?{|ship| ship.attackable?(to)}
  end

  private
    
  def overlap(position)
    @ships.values.each do |ship|
      if ship.position == position
        return ship
      end
    end
    nil
  end

  def near(to)
    near = []
    @ships.values.each do |ship|
      if ship.position != to && (ship.position[0] - to[0]).abs <= 1 &&(ship.position[1] - to[1]).abs <= 1
        near.push(ship)
      end
    end
    near
  end

  def self.in_field?(position)
    position[0] < FIELD_SIZE && position[1] < FIELD_SIZE &&
      position[0] >= 0 && position[1] >= 0
  end
end 

class Server
  attr :clients

  def initialize(json1, json2)
    @clients = Array.new(2)
    @clients[0] = Client.new(JSON.parse(json1))
    @clients[1] = Client.new(JSON.parse(json2))
  end

  def initial_condition(c)
    [condition(c).to_json, condition(1-c).to_json]
  end

  def action(c, json)
    info = Array.new(2){{}}
    active = @clients[c]
    passive = @clients[1-c]
    act = JSON.parse(json)

    if act.has_key?("attack")
      to = act["attack"]["to"]
      
      if !active.attackable?(to)
        result = false
      else
        result = passive.attacked(to)
      end
      
      info[c]["result"] = {"attacked" => result}
      info[1-c]["result"] = {"attacked" => result}

      if passive.ships.empty?
        info[c]["outcome"] = true
        info[1-c]["outcome"] = false
      end
      
    elsif act.has_key?("move")
      result = active.move(act["move"]["ship"], act["move"]["to"])
      info[1-c]["result"] = {"moved" => result}
    end

    if !result
      info[c]["outcome"] = false
      info[1-c]["outcome"] = true
    end

    info[c] = info[c].merge(condition(c))
    info[1-c] = info[1-c].merge(condition(1-c))

    [info[c].to_json, info[1-c].to_json]
  end

  private

  def condition(c)
    {
      "condition" => {
        "me" => @clients[c].condition(true),
        "enemy" => @clients[1-c].condition(false)
      }
    }
  end
end
