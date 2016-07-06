require 'socket'
require 'json'
require './player'

class ManualPlayer < Player

  def initialize
    puts "please input x, y in 0 ~ " + (FIELD_SIZE - 1).to_s
    puts "warship"
    w = select_position
    puts "cruiser"
    c = select_position
    puts "submarine"
    s = select_position
    super({"w" => w, "c" => c, "s" => s})
    show_field
  end

  def action
    act = select_action

    if act == "m"
      ship = ships[select_ship]
      to = select_position
      while !ship.reachable?(to) || !overlap(to).nil?
        puts "you can't move " + ship.type + ship.position.to_s + " to " + to.to_s
        to = select_position
      end

      move(ship.type, to).to_json
    elsif act == "a"
      to = select_position
      while !attackable?(to)
        to = select_position
      end

      attack(to).to_json
    end
  end

  def update(json, c)
    info = JSON.parse(json)
    report(info, c)
    super(json)
    if c == 1
      if info["result"].has_key?("attacked")
        show_field(info["result"]["attacked"]["position"])
      else
        show_field
      end
    else
      show_field
    end
  end

  def report(info, c)
    if c == 0
      player = "you"
    else
      player = "enemy"
    end
    if info.has_key?("result")
      print player
      if info["result"].has_key?("attacked")
        report_attacked(info["result"]["attacked"])
      elsif info["result"].has_key?("moved")
        report_moved(info["result"]["moved"])
      end
    end

    report_condition(info["condition"])
  end

  def show_field(hit=nil)
    print_in_cell("\s\s\s")
    for i in 0...FIELD_SIZE
      print_in_cell("\s" + i.to_s + "\s")
    end
    print "\n"
    print_bar

    for y in 0...FIELD_SIZE
      print_in_cell("\s" + y.to_s + "\s")
      for x in 0...FIELD_SIZE
        if [x, y] == hit
          print "!"
        else
          print "\s"
        end
        ship = overlap([x, y])
        if ship.nil?
          print_in_cell("\s\s")
        else
          print_in_cell(ship.type + ship.hp.to_s)
        end
      end
      print "\n"
      print_bar
    end
  end

  private

  def select_action
    puts "select your action:"
    puts "m: move"
    puts "a: attack"

    begin
      puts "please input \"a\" or \"m\""
      act = STDIN.gets.rstrip
    end while act != "m" && act != "a"

    act
  end

  def select_ship
    puts "w: warship c: cruiser s: submarine"

    print "select your ship: "
    ship = STDIN.gets.rstrip
    while ship != "w" && ship != "c" && ship != "s"
      puts "please input \"w\" or \"c\" or \"s\""
      print "select your ship: "
      ship = STDIN.gets.rstrip
    end

    ship
  end

  def select_position
    print "x = "
    x = STDIN.gets.to_i
    print "y = "
    y = STDIN.gets.to_i
    position = [x, y]
    while !Player.in_field?(position)
      puts "out of field"
      print "x = "
      x = STDIN.gets.to_i
      print "y = "
      y = STDIN.gets.to_i
      position = [x, y]
    end
    position
  end

  def print_in_cell(s)
    print s + "|"
  end

  def print_bar
    (FIELD_SIZE + 1).times do
      print "----"
    end
    print "\n"
  end

  def report_moved(moved)
    print " moved " + moved["ship"] + " by "
    if moved["distance"][0] > 0
      arrow = "^" * moved["distance"][0]
    elsif moved["distance"][0] < 0
      arrow = "v" * (-moved["distance"][0])
    elsif moved["distance"][1] > 0
      arrow = ">" * moved["distance"][1]
    elsif moved["distance"][1] < 0
      arrow = "<" * (-moved["distance"][1])
    end
    puts arrow
  end

  def report_attacked(attacked)
    print " attacked "  + attacked["position"].to_s
    if attacked.has_key?("hit")
      print " hit " + attacked["hit"]
    end
    if attacked.has_key?("near")
      print " near " + attacked["near"].to_s
    end
    print "\n"
  end

  def report_condition(condition)
    print "enemy ships: "
    condition["enemy"].each do |type, state|
      print type + ":" + state["hp"].to_s + "\s"
    end
    print "\n"
  end
end

def main(host, port)
  begin
    sock = TCPSocket.open(host, port)
  rescue
    puts "TCPSocket.open faild:#$!\n"
  else
    puts sock.gets
    player = ManualPlayer.new
    sock.puts(player.initial_condition)

    loop do
      info = sock.gets.rstrip
      print "\n"
      puts info
      if info == "your turn"
        sock.puts(player.action)
        player.update(sock.gets, 0)
      elsif info == "waiting"
        player.update(sock.gets, 1)
      elsif info == "you win"
        break
      elsif info == "you lose"
        break
      else
        raise RuntimeError, "unknown information"
      end
    end
  end
  sock.close
end

if __FILE__ == $0
  main(ARGV[0], ARGV[1])
end