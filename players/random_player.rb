require 'socket'
require_relative('../lib/player')

# ランダムに行動を決定するプレイヤーである．
class RandomPlayer < Player

  # フィールドを2x2の配列として持っている．
  attr :field

  # 初期配置を非復元抽出でランダムに決める．
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

  #
  # 移動か攻撃かランダムに決める．
  # どれがどこへ移動するか，あるいはどこに攻撃するかもランダム．
  #
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

# 仕様に従ってサーバとソケット通信を行う．
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
      elsif info == "even"
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