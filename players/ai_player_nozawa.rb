# coding: utf-8
require 'socket'
require_relative '../lib/player'
require_relative '../lib/lib'

class StatePlayer2 < Player
  include Ex_array
  attr :field 
  attr :enemy_field #敵の存在位置を管理
  attr :my_field #敵から見た自艦の存在位置を管理
  attr :state
  attr :msg #異なるステートへのパラメータ引き渡しに使用
  attr :attacked_positions #索敵時に同じ場所を攻撃しないように

  INIT_SAMPLE_NUM=9 #自艦位置初期化時のサンプリング数(min:3 max: FIELD_SIZE*FIELD_SIZE。小さいほど艦の位置はランダムになるが密集する可能性が高く、大きいほど艦の位置は散開するが場所の大まかな予測もしやすくなる（フィールド周辺部に集まる）

  def initialize
    @state = :sakuteki
    @field = []
    @attacked_positions=[]
    #　敵艦の存在可能な場所を配列で管理。
    @enemy_field = { "w" => [], "c" => [], "s" => []}
    # 自艦も同じく
    @my_field = {"w" => [], "c" => [], "s" => []}
    for i in 0...FIELD_SIZE
      for j in 0...FIELD_SIZE
        @field.push([i,j])
        @enemy_field.each { |key,array| array.push([i,j])}
        @my_field.each {|key,array| array.push([i,j])}
      end
    end
    @field=@field.shuffle
    ps = @field.sample(INIT_SAMPLE_NUM)
    max_dis=0 #艦同士の距離の和
    max_ind=[]
    for i in 0...INIT_SAMPLE_NUM-2
      for j in i+1...INIT_SAMPLE_NUM-1
        for k in j+1...INIT_SAMPLE_NUM
          cur_dis=get_distance(ps[i],ps[j])+get_distance(ps[i],ps[k])+get_distance(ps[j],ps[k])
          #この計算式ではユークリッド距離ではなくその二乗の総和を評価しているが、中途半端に集まるよりは一部の艦が思いきり離れていた方が戦略上有利になるためそれで良いではないかという気持ち
          if (max_dis<cur_dis)
            max_dis=cur_dis
            max_ind=[i,j,k]
          end
        end
      end
    end
    positions = {"w" => ps[max_ind[0]], "c" => ps[max_ind[1]], "s" => ps[max_ind[2]]}
    super(positions)
  end

  def action
    p @enemy_field
    p @my_field
    #一人しかいなかったら潜行モードへ
    if @my_field.size==1
      @state=:stealth
      @my_field.each_key{|k| @msg=k}
    end
    #一箇所に絞られる敵がいた場合は攻撃ステートに移行、ただし潜行/逃走モード時は除く
    if @state!=:stealth && @state!=:escape
      @enemy_field.each{|type,array|
        if array.count==1
          @msg=array[0]
          @state=:attack
        end
      }
    end
    while true
      if @state == :sakuteki
        # ステート索敵: 基本戦略
        # 自艦は動かない。敵位置の情報収集が先決
        # 多くの敵艦の位置が大まかに絞れるよりも一部の敵艦の位置を正確に絞れた方が嬉しい。この目的に即した評価関数を作成し、攻撃可能座標を走査して一番評価関数が高くなった位置を攻撃
        # 攻撃場所の評価関数: (攻撃によって効果が及ぶマスのうちある艦が存在する可能性があるマスの数、ただし直撃の場合は1.5倍ボーナス)*FIELD_SIZE*FIELD_SIZE/(その艦の存在可能マス数）
        attackable_positions=[]
        for i in 0...FIELD_SIZE*FIELD_SIZE
          if (attackable?(field[i])) && !@attacked_positions.include?(field[i])
            attackable_positions.push(field[i])
          end
        end
        if attackable_positions.size==0
          #すべての攻撃可能箇所を索敵した場合、それ以外の場所にステート攻撃で攻撃
          for i in 0...FIELD_SIZE*FIELD_SIZE
            if (!attackable?(field[i])) && !@attacked_positions.include?(field[i])
              @msg=field[i]
              @state=:attack
              break
            end
          end
          next
        end
        max_eval=0
        max_ind=0
        for i in 0...attackable_positions.size
          attack_field=invert(near_map(attackable_positions[i]))
          #attack_fieldには座標attackable_positionsに攻撃することによりしぶきが上がるマスが格納される
          cur_eval=0
          for k in attack_field
            enemy_field.each{|key,array|
              if array.include?(k)
                cur_eval+=FIELD_SIZE*FIELD_SIZE/array.count
              end
            }
          end
          enemy_field.each{|key,array|
            if array.include?(attackable_positions[i])
              cur_eval+=FIELD_SIZE*FIELD_SIZE*1.5/array.count #直撃ボーナス
            end
          }
          if (cur_eval>max_eval)
            max_eval=cur_eval
            max_ind=i
          end
        end
        @attacked_positions.push(attackable_positions[max_ind])
        p "attack->#{attackable_positions[max_ind]}"
        p @state
        return attack(attackable_positions[max_ind]).to_json

      elsif @state==:attack
        #ステート攻撃: 基本戦略
        #自艦を動かさずに攻撃できるなら攻撃
        #自艦を一回動かせば攻撃できる場合：できるだけ相手に位置がバレていない艦を動かす
        #自艦を二回動かせば攻撃できる場合：適切な位置にバレていない艦を移動する
        #ただし、移動により自艦の場所が一箇所に絞られてしまう場合は索敵モードに移行する
        @attacked_positions=[] #索敵初期化
        if (attackable?(@msg))
          #攻撃できるならそのまま攻撃
          p "attack->#{@msg}"
          p @state
          return attack(@msg).to_json          
        end
        #　一回の移動でなんとかなる場合
        #評価関数：（移動後に推測されるであろう存在可能性情報を考慮した各艦の存在可能マス数）^2 を艦ごとに足し合わせる
        max_eval=0
        max_type=nil
        max_dist=[]
        skip_list=[] #移動によって一箇所に絞られてしまう艦リスト　二回移動の処理時は考慮しない
        @ships.each{|type,ship|
          position=ship.position
          cur_eval=0
          if (position[0]-@msg[0]).abs<=1
            next_my_field=@my_field.clone
            if (@msg[1]-position[1]>0)
              distance=@msg[1]-position[1]-1
            elsif
              distance=@msg[1]-position[1]+1
            end
            next_my_field[type]=invert(slide(convert(next_my_field[type]),[0,distance]))
            if (next_my_field[type].count!=1) #移動することで自分の場所が絞られてしまう場合は考えない
              next_my_field.each{|type,array|
                cur_eval+=array.count*array.count
              }
              if (cur_eval>max_eval)
                max_type=type
                max_eval=cur_eval
                max_dist=[0,distance]
              end
            elsif
              skip_list.push(type)
            end
          elsif (position[1]-@msg[1]).abs<=1
            next_my_field=@my_field.clone
            if (@msg[0]-position[0]>0)
              distance=@msg[0]-position[0]-1
            elsif
              distance=@msg[0]-position[0]+1
            end
            next_my_field[type]=invert(slide(convert(next_my_field[type]),[distance,0]))
            next_my_field.each{|type,array|
              cur_eval+=array.count*array.count
            }
            if (cur_eval>max_eval)
              max_type=type
              max_dist=[distance,0]
              max_eval=cur_eval
            end
          end
        }
        if (max_eval!=0)
          @my_field[max_type]=invert(slide(convert(@my_field[max_type]),max_dist))
          p "move (#{max_type},[#{@ships[max_type].position[0]+max_dist[0]},#{@ships[max_type].position[1]+max_dist[1]}])"
          p @state
          return move(max_type,[@ships[max_type].position[0]+max_dist[0],@ships[max_type].position[1]+max_dist[1]]).to_json
        end

        # 二回移動の時 評価関数は同様で、一つの艦ごとに二方向の移動を走査する点が異なる
        @ships.each{|type,ship|
          position=ship.position
          if (skip_list.include?(type))
            next
          end
          cur_eval=0
          next_my_field=@my_field.clone
          if (@msg[1]-position[1]>0)
            distance=@msg[1]-position[1]-1
          elsif
            distance=@msg[1]-position[1]+1
          end
          next_my_field[type]=invert(slide(convert(next_my_field[type]),[0,distance]))
          if next_my_field[type].count!=1 && (overlap([position[0],position[1]+distance])==nil)
            next_my_field.each{|type,array|
              cur_eval+=array.count*array.count
            }
            if (cur_eval>max_eval)
              max_type=type
              max_dist=[0,distance]
              max_eval=cur_eval
            end
          end
          cur_eval=0
          next_my_field=@my_field.clone
          if (@msg[0]-position[0]>0)
            distance=@msg[0]-position[0]-1
          elsif
            distance=@msg[0]-position[0]+1
          end
          next_my_field[type]=invert(slide(convert(next_my_field[type]),[distance,0]))
          if next_my_field[type].count!=1 && (overlap([position[0]+distance,position[1]])==nil)
            next_my_field.each{|type,array|
              cur_eval+=array.count*array.count
            }
            if (cur_eval>max_eval)
              max_eval=cur_eval
              max_type=type
              max_dist=[distance,0]
            end
          end
        }
        if (max_eval!=0)
          @my_field[max_type]=invert(slide(convert(@my_field[max_type]),max_dist))
          p "move (#{max_type},[#{@ships[max_type].position[0]+max_dist[0]},#{@ships[max_type].position[1]+max_dist[1]}])"
          p @state
         return move(max_type,[@ships[max_type].position[0]+max_dist[0],@ships[max_type].position[1]+max_dist[1]]).to_json
        else
          @state=:sakuteki
          next
        end
      elsif @state==:escape
        #ステート逃走：基本戦略
        #逃走可能箇所ごとに評価し一番スコアの高かった場所に逃走
        #敵の場所がわかっている場合はその敵に攻撃される場所は考慮しない
        #基本的にはより長く移動し、かつ敵に場所がよりバレておらずhpの高い味方艦の近くに移動して敵をおびき寄せようとする(おびき寄せた先で殴り合いになった場合勝てる可能性が高い）
        #評価関数：(移動量)*5+(移動した先のマスを攻撃できる味方艦のhp)*(その味方艦が敵に推測されていると思われる存在可能マス数)
        #移動量に掛ける定数項は適当
        @attacked_positions=[] #索敵初期化
        position=@ships[@msg].position
        max_eval=0
        danger_zone=[] #敵に攻撃されうる座標
        @enemy_field.each{|type,array|
          if array.count==1
            danger_zone+=invert(near_map(array[0]))
            danger_zone+=array[0]
          end
        }
        for i in 0...FIELD_SIZE #X軸の移動
          cur_eval=(i-position[0]).abs*5
          if danger_zone.include?([i,position[1]])
            next
          end
          if overlap([i,position[1]])!=nil
            next
          end
          @ships.each{|type,ship|
            if (ship.type==@msg)
              next
            end
            if (ship.position[0]-i).abs<=1 && (ship.position[1]-position[1]).abs<=1
              cur_eval+=ship.hp*@my_field[ship.type].count
            end
          }
          if (max_eval<cur_eval)
            max_to=[i,position[1]]
            max_eval=cur_eval
          end
        end
        for i in 0...FIELD_SIZE #Y軸方向の移動
          cur_eval=(i-position[1]).abs*5
          if danger_zone.include?([position[0],i])
            next
          end
          if overlap([position[0],i])!=nil
            next
          end
          @ships.each{|type,ship|
            if (ship.type==@msg)
              next
            end
            if (ship.position[0]-position[0]).abs<=1 && (ship.position[1]-i).abs<=1
              cur_eval+=ship.hp*@my_field[ship.type].count
            end
          }
          if (max_eval<cur_eval)
            max_to=[position[0],i]
            max_eval=cur_eval
          end
        end
        if (max_eval!=0)
          @my_field[@msg]=invert(slide(convert(@my_field[@msg]),[max_to[0]-@ships[@msg].position[0],max_to[1]-@ships[@msg].position[1]]))
          @state=:sakuteki #次ターンは索敵
          p "move (#{@msg},#{max_to})"
          p @state
          return move(@msg,max_to).to_json
        elsif
          #どこに逃げても敵の攻撃範囲内になる場合は反撃
          @enemy_field.each{|type,array|
            if array.count==1
              if (array[0][0]-@ships[@msg].position[0]).abs<=1 && (array[0][1]-@ships[@msg].position[1]).abs<=1
                @msg=array[0]
                @state=:attack
              end
            end
          }
          next
        end
      elsif @state==:stealth
        #ステート潜行：基本戦略
        #自分が残り一艦となった場合に発動。基本的に移動を繰り返し、出来るだけ位置情報を漏らさないようにする
        #相手の艦の場所が判明し、自分の位置情報があまり漏れない際にのみ攻撃
        @attacked_positions=[] #索敵初期化
        danger_zone=[]
        @enemy_field.each{|type,array|
          if array.count==1
            if attackable?(array[0])
              p "attack->#{array[0]}"
              p @state
              return attack(array[0]).to_json
            end
            danger_zone+=invert(near_map(array[0]))
            danger_zone+=array[0]
          end
        }
        #評価関数：移動量＋(移動後に相手に推測されると思われる存在可能マス数)/(移動前の相手に推測されていると思われる存在可能マス数)*25
        max_eval=0
        for x in 0...FIELD_SIZE #X軸
          if x == @ships[@msg].position[0]
            next
          end
          if danger_zone.include?([x,@ships[@msg].position[1]])
            next
          end
          cur_eval=(x-@ships[@msg].position[0]).abs
          next_my_field=@my_field.clone
          next_my_field[@msg]=invert(slide(convert(next_my_field[@msg]),[x-@ships[@msg].position[0],0]))
          cur_eval+=next_my_field[@msg].count/@my_field[@msg].count*25
          if (cur_eval>max_eval)
            max_eval=cur_eval
            max_to=[x,@ships[@msg].position[1]]
          end
        end
        for y in 0...FIELD_SIZE #Y軸
          if y == @ships[@msg].position[1]
            next
          end
          if danger_zone.include?([@ships[@msg].position[0],y])
            next
          end
          cur_eval=(y-@ships[@msg].position[1]).abs
          next_my_field=@my_field.clone
          next_my_field[@msg]=invert(slide(convert(next_my_field[@msg]),[0,y-@ships[@msg].position[1]]))
          cur_eval+=next_my_field[@msg].count/@my_field[@msg].count*25
          if (cur_eval>max_eval)
            max_eval=cur_eval
            max_to=[@ships[@msg].position[0],y]
          end
        end
        if (max_eval!=0)
          @my_field[@msg]=invert(slide(convert(@my_field[@msg]),[max_to[0]-@ships[@msg].position[0],max_to[1]-@ships[@msg].position[1]]))
          p "move (#{@msg},#{max_to})"
          p @state
          return move(@msg,max_to)
        else
          #どこに行っても敵にやられる可能性があるのでとりあえず索敵
          @state=:sakuteki
          next
        end
      end
    end
  end
  def update(json,status)
    super(json)
    data = JSON.parse(json)
    if data.has_key?("result")
      result=data["result"]
      cond=data["condition"]
      if status == :me
        if result.has_key?("attacked")
          if result["attacked"].has_key?("hit")
            ship=result["attacked"]["hit"]
            if !cond["enemy"].has_key?(ship)
              @enemy_field.delete(ship)
            else
              @enemy_field[ship]=[result["attacked"]["position"]]
            end
          else
            @enemy_field.keys.each{|ship|
              @enemy_field[ship].delete(result["attacked"]["position"])
            }
          end
          if result["attacked"].has_key?("near")
            near_map=near_map(result["attacked"]["position"])
            result["attacked"]["near"].each{|ship|
              ship_map=convert(@enemy_field[ship])
              @enemy_field[ship]=invert(product(ship_map,near_map))
            }
          end
        end
      elsif status == :enemy
        if result.has_key?("moved")
          ship=result["moved"]["ship"]
          dist=result["moved"]["distance"]
          @enemy_field[ship]=invert(slide(convert(@enemy_field[ship]),dist))
        elsif result.has_key?("attacked")
          if result["attacked"].has_key?("hit")
            if @ships.has_key?(result["attacked"]["hit"])
              @my_field[result["attacked"]["hit"]]=[result["attacked"]["position"]]
              counter_flag=false
              @enemy_field.each{|ship,field|
                if field.count==1
                  if @ships[result["attacked"]["hit"]].attackable?(field[0]) && @ships[result["attacked"]["hit"]].hp >= cond["enemy"][ship]["hp"]
                    @msg=field[0]
                    @state=:attack
                    counter_flag=true
                    break
                  end
                end
              }
              if !counter_flag
                @msg=result["attacked"]["hit"]
                @state=:escape
              end
            elsif
              @my_field.delete(result["attacked"]["hit"])
            end
          end
          if result["attacked"].has_key?("near")
            near_map=near_map(result["attacked"]["position"])
            result["attacked"]["near"].each{|ship|
              ship_map=convert(@my_field[ship])
              @my_field[ship]=invert(product(ship_map,near_map))
            }
          end
        end
      end
    end
  end
  
  private

  def get_distance(ps1,ps2)
    return (ps1[0]-ps2[0])*(ps1[0]-ps2[0])+(ps1[1]-ps2[1])*(ps1[1]-ps2[1])
  end
  
end

def main(host, port)
  begin
    sock = TCPSocket.open(host, port)
  rescue
    puts "TCPSocket.open faild:#$!\n"
  else
    puts sock.gets
    player = StatePlayer2.new
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
