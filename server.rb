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
  attr :ships
  
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
      if overlap(position)
        raise ArgumentError, "given overlapping positions"
      end
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

  private
    
  def overlap(position)
    @ships.values.each do |ship|
      if ship.position == position
        return ship
      end
    end
    nil
  end

  def self.in_field?(position)
    position[0] < FIELD_SIZE && position[1] < FIELD_SIZE &&
      position[0] >= 0 && position[1] >= 0
  end
end

class RandomPlayer < Player
  attr :field
  FIELD_SIZE
  
  def initialize
    @field = []
    for i in 0...FIELD_SIZE
      for j in 0...FIELD_SIZE
        @field.push([i,j])
      end
    end

    ps = @field.sample(3)
    positions = {"w" => ps[0], "c" => ps[1], "s" => ps[2]}
    super(positions)
  end

  def action
    info = {}
    act = ["move", "attack"].sample

    if act == "move"
      ship = @ships.values.sample
      to = @field.sample
      while !ship.reachable?(to) || !overlap(to).nil?
        to = @field.sample
      end

      move(ship.type, to).to_json
    elsif act == "attack"
      to = @field.sample
      while !attackable?(to)
        to = @field.sample
      end

      attack(to).to_json
    end
  end
end

def one_action(active, passive, c, server)
  act = active.action
  results = server.action(c, act)
  report_result(results, c)
  active.update(results[0])
  passive.update(results[1])

  !JSON.parse(results[0]).has_key?("outcome")
end

def report_result(results, c)
  result1 = JSON.parse(results[0])
  result2 = JSON.parse(results[1])

  if result2["result"].has_key?("moved")
    if result2["result"]["moved"]
      puts "player" + (c+1).to_s +  " moved " + result2["result"]["moved"]["ship"] + " by " + result2["result"]["moved"]["distance"].to_s
    else
      puts "player " + (c+1).to_s + " faild to move"
    end
  else
    
    if result2["result"]["attacked"]
      puts "player" + (c+1).to_s +  " attacked " + result2["result"]["attacked"]["position"].to_s

      if result2["result"]["attacked"].has_key?("hit")
        puts "hit " + result2["result"]["attacked"]["hit"]
      end
      if result2["result"]["attacked"].has_key?("near")
        puts "near " + result2["result"]["attacked"]["near"].to_s
      end
    else
      puts "player" + (c+1).to_s + " faild to attack"
    end
  end

  if c == 0
    puts "player" + (c+1).to_s +  ": " + result1["condition"]["me"].to_s
    puts "player" + (2-c).to_s +  ": "  + result2["condition"]["me"].to_s
  else
    puts "player" + (2-c).to_s +  ": "  + result2["condition"]["me"].to_s
    puts "player" + (c+1).to_s +  ": " + result1["condition"]["me"].to_s
  end
  puts ""
end

def play_game(player1, player2)
  cond1 = player1.initial_condition
  cond2 = player2.initial_condition
  server = Server.new(cond1, cond2)

  players = [player1, player2]
  continue = one_action(player1, player2, 0, server)
  c = 1
  i = 0
  while continue && i < 1000
    continue = one_action(players[c], players[1-c], c, server)
    c = 1 - c
    i += 1
  end

  if i == 1000
    puts "time up"
  else
    puts "player" + (2-c).to_s + " won"
  end
end

if __FILE__ == $0
  p1 = RandomPlayer.new
  p2 = RandomPlayer.new

  play_game(p1, p2)
end
