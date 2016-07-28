require 'socket'
require './player'
require './lib'

class StatePlayer < Player
  include Ex_array
  attr :field
  attr :enemy_field
  attr :state

  def initialize
    @state = :attack
    @focus = nil
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
    while true
      if @state == :attack
        # 狙う艦を決定
        # @focus に値が入っていればそれを使う
        target = @focus.nil? ? @enemy_field.keys.sample : @focus 
        # 攻撃場所を狙う艦の存在する可能性のある場所から決定
        to = @enemy_field[target].sample

        # ハマる可能性があるので、敵艦の存在場所を狙うのは25回まで
        count = 0
        while !attackable?(to)
          to = @enemy_field[target].sample
          count += 1
          break if count > 60
        end

        if attackable?(to) # 攻撃可能ならそのまま攻撃
          p "attack -> #{target} #{to}"
          return attack(to).to_json
        else # だめな場合はstateを:chase に
          @state = :chase
        end
      elsif @state == :chase
        while
          ship = @ships.values.sample
          target = @focus.nil? ? @enemy_field.keys.sample : @focus 
          target_point = @enemy_field[target].sample
          # ターゲットの x 座標か y 座標が同じ点に移動を試みる
          to = []
          for i in 0..1
            to[i] = target_point[i]
            to[1-i] = ship.position[1-i]
            # 移動できれば移動
            if ship.reachable?(to) && overlap(to).nil?
              # 一度 :chase したら :attackに戻る
              @state = :attack
              p "move -> #{ship.type} #{to}"
              return move(ship.type, to).to_json
            end
          end
        end
      end
    end
  end

  def update(json,status)
    super(json)
    data = JSON.parse(json)
    if data.has_key?("result") # result は初回ターンのみ存在しないので確認
      result = data["result"]
      cond = data["condition"]
      if status == :me # 自分のターン
        if result.has_key?("attacked") # 攻撃した場合
          if result["attacked"].has_key?("hit") # 命中した場合
            ship = result["attacked"]["hit"]
            if !cond["enemy"].has_key?(ship) # 死亡した艦は@enemy_field のキーを削除する
              @enemy_field.delete(ship)
              @focus = nil
            else
              @enemy_field[ship] = [result["attacked"]["position"]]
              # 一度ヒットした敵は狙い撃つ
              @focus = ship
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
      elsif status == :enemy # 敵のターン
        if result.has_key?("moved")
          ship = result["moved"]["ship"]
          dist = result["moved"]["distance"]
          @enemy_field[ship] = invert(slide(convert(@enemy_field[ship]),dist))
        end
      end
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
    player = StatePlayer.new
    sock.puts(player.initial_condition)

    loop do
      info = sock.gets.rstrip
      puts info
      if info == "your turn"
        sock.puts(player.action)
        player.update(sock.gets,:me)
      elsif info == "waiting"
        player.update(sock.gets,:enemy)
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