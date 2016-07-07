require 'json'
require 'socket'

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
      if !Client.in_field?(position)
        raise ArgumentError, "position out of field"
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

    info["near"] = near.map { |s| s.type }

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
    Client.in_field?(to) && @ships.values.any? { |ship| ship.attackable?(to) }
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
    info = Array.new(2) { {} }
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

  def condition(c)
    {
        "condition" => {
            "me" => @clients[c].condition(true),
            "enemy" => @clients[1-c].condition(false)
        }
    }
  end
end

module Reporter
  FIELD_SIZE = 5

  def self.report_result(results, c)
    result1 = JSON.parse(results[0])
    result2 = JSON.parse(results[1])

    if result2["result"].has_key?("moved")
      if result2["result"]["moved"]
        puts "player" + (c+1).to_s + " moved " + result2["result"]["moved"]["ship"] + " by " + result2["result"]["moved"]["distance"].to_s
      else
        puts "player " + (c+1).to_s + " faild to move"
      end
    else

      if result2["result"]["attacked"]
        puts "player" + (c+1).to_s + " attacked " + result2["result"]["attacked"]["position"].to_s

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
      puts "player" + (c+1).to_s + ": " + result1["condition"]["me"].to_s
      puts "player" + (2-c).to_s + ": " + result2["condition"]["me"].to_s
    else
      puts "player" + (2-c).to_s + ": " + result2["condition"]["me"].to_s
      puts "player" + (c+1).to_s + ": " + result1["condition"]["me"].to_s
    end
    puts ""
  end

  def self.report_field(result, c)
    results = [JSON.parse(result[0]), JSON.parse(result[1])]

    fleets = [results[c]["condition"]["me"], results[1-c]["condition"]["me"]]
    if result[1]["result"].nil?
      attacked = nil
    else
      attacked = results[1]["result"]["attacked"].nil? ? nil : results[1]["result"]["attacked"]["position"]
    end

    2.times do
      print_in_cell("\s\s\s")
      for i in 0...FIELD_SIZE
        print_in_cell("\s" + i.to_s + "\s")
      end
    end
    print_bars
    for y in 0...FIELD_SIZE
      print_in_cell("\s" + y.to_s + "\s")
      for d in 0..1
        for x in 0...FIELD_SIZE
          if d == 1-c && attacked == [x, y]
            print "!"
          else
            print "\s"
          end
          s = true
          fleets[d].each do |ship|
            if ship[1]["position"] == [x, y]
              print_in_cell(ship[0] + ship[1]["hp"].to_s)
              s = false
              break
            end
          end
          if s
            print_in_cell("\s\s")
          end
        end
        if d == 0
          print_in_cell("\s\s\s")
        end
      end
      print_bars
    end
    print "\n"
  end

  private

  def self.print_in_cell(s)
    print s + "|"
  end

  def self.print_bar
    FIELD_SIZE.times do
      print "----"
    end
  end

  def self.print_bars
    print "\n"
    print "----"
    print_bar
    print "\s\s\s\s"
    print_bar
    print "\n"
  end
end

def one_action(active, passive, c, server)
  act = active.gets
  results = server.action(c, act)
  Reporter.report_field(results, c)
  active.puts(results[0])
  passive.puts(results[1])

  !JSON.parse(results[0]).has_key?("outcome")
end

def main(port)
  tcp_server = TCPServer.open(port)
  sockets = []
  2.times do
    sockets.push(tcp_server.accept)
  end
  sockets.each do |socket|
    socket.puts("you are connected. please send me initial state.")
  end

  server = Server.new(sockets[0].gets, sockets[1].gets)

  c = 0
  Reporter.report_field(server.initial_condition(c), c)
  begin
    sockets[c].puts("your turn")
    sockets[1-c].puts("waiting")
    continue = one_action(sockets[c], sockets[1-c], c, server)
    c = 1 - c
  end while continue
  sockets[1-c].puts("you win")
  sockets[c].puts("you lose")

  puts "player" + (2-c).to_s + " win"

  sockets.each do |socket|
    socket.close
  end
  tcp_server.close
end

if __FILE__ == $0
  main(ARGV[0])
end
