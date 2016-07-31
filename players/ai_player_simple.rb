require 'socket'
require_relative('../lib/player')
require_relative('../lib/lib')

class SimplePlayer < Player
  include Ex_array
  attr :field
  attr :enemy_field

  def initialize
    @field = []
    # 敵艦の存在可能な場所を配列で格納する
    @enemy_field = { "w" => [], "c" => [], "s" => []}
    for i in 0...FIELD_SIZE
      for j in 0...FIELD_SIZE
        @field.push([i,j])
        @enemy_field.each{ |key,array|
          array.push([i,j])
        }
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
      # 狙う艦を決定
      target = @enemy_field.keys.sample
      # 攻撃場所を狙う艦の存在する可能性のある場所から決定
      to = @enemy_field[target].sample

      # 移動によって@enemy_field が全てnilになってしまう場合があるので、そうなったら@enemy_fieldをやり直す(仮)
      # 多分呼ばれることはないけど一応残す
      if to.nil?
        for i in 0...FIELD_SIZE
          for j in 0...FIELD_SIZE
            @enemy_field[target].push([i,j])
          end
        end
        to = @enemy_field[target].sample
        p "!!!!enemy fleet lost!!!!"
      end
      
      # ハマる可能性があるので、敵艦の存在場所を狙うのは25回まで
      count = 0
      while !attackable?(to)
        to = @enemy_field[target].sample
        count += 1
        break if count > 60
      end

      if attackable?(to) # 攻撃可能ならそのまま攻撃
        attack(to).to_json
      else # だめな場合は適当に攻撃
        while !attackable?(to)
          to = @field.sample
        end
        attack(to).to_json
      end
    end
  end

  def update(json,status)
    super(json)
    data = JSON.parse(json)
    return if data.has_key?("outcome")
    if data.has_key?("result") # result は初回ターンのみ存在しないので確認
      result = data["result"]
      cond = data["condition"]
      p result
      p cond
      if status == "me" # 自分のターン
        if result.has_key?("attacked") # 攻撃した場合
          if result["attacked"].has_key?("hit") # 命中した場合
            ship = result["attacked"]["hit"]
            if !cond["enemy"].has_key?(ship) # 死亡した艦は@enemy_field のキーを削除する
              @enemy_field.delete(ship)
            else
              @enemy_field[ship] = [result["attacked"]["position"]]
            end
          else # 命中しなかった場合、その座標には何も居ないのが確定する
            @enemy_field.keys.each{ |ship|
              @enemy_field[ship].delete(result["attacked"]["position"])
            }
          end

          if result["attacked"].has_key?("near") # 至近弾の場合
            # 敵艦情報を更新していく
            near_map = near_map(result["attacked"]["position"])
            result["attacked"]["near"].each { |ship|
              ship_map = convert(@enemy_field[ship])
              @enemy_field[ship] = invert(product(ship_map,near_map))
            }
          end
        end
      elsif status == "enemy" # 敵のターン
        if result.has_key?("moved")
          ship = result["moved"]["ship"]
          dist = result["moved"]["distance"]
          @enemy_field[ship] = invert(slide(convert(@enemy_field[ship]),dist))
        end
      end
      p @enemy_field
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
    player = SimplePlayer.new
    sock.puts(player.initial_condition)

    loop do
      info = sock.gets.rstrip
      puts info
      if info == "your turn"
        sock.puts(player.action)
        player.update(sock.gets,"me")
      elsif info == "waiting"
        player.update(sock.gets,"enemy")
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