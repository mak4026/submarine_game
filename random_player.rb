require 'socket'
require './player'

class RandomPlayer < Player
  attr :field

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

def main(host, port)
  begin
    sock = TCPSocket.open(host, port)
  rescue
    puts "TCPSocket.open faild:#$!\n"
  else
    puts sock.gets
    player = RandomPlayer.new
    sock.puts(player.initial_condition)

    loop do
      info = sock.gets.rstrip
      puts info
      if info == "your turn"
        sock.puts(player.action)
        player.update(sock.gets)
      elsif info == "waiting"
        player.update(sock.gets)
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