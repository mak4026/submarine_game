require 'json'

# プレイヤーの船を表すクラスである．
class PlayerShip

  # 船の種類と最大HPを定義している．
  MAX_HPS = {"w" => 3, "c" => 2, "s" => 1}
  # 種類を参照できる．
  attr :type
  # 場所とHPは更新できる．
  attr_accessor :position, :hp

  # 種類と場所を与えられる．HPは自動で決まる．
  def initialize(type, position)
    if !MAX_HPS.has_key?(type)
      raise ArgumentError, "invalid type supecified"
    end

    @type = type
    @position = position
    @hp = MAX_HPS[type]
  end

  # 座標を変更する．
  def moved(to)
    @position = to
  end

  # ダメージを受けてHPが減る．
  def damaged(d)
    @hp -= d
  end

  # 座標が移動できる範囲(縦横)にあるか確認する．
  def reachable?(to)
    @position[0] == to[0] || @position[1] == to[1]
  end

  # 座標が攻撃できる範囲(自分の座標及び周囲1マス)にあるか確認する．
  def attackable?(to)
    (to[0] - @position[0]).abs <= 1 && (to[1] - @position[1]).abs <= 1
  end
end

# プレイヤーを表すクラスである．艦を複数保持している．
class Player

  # フィールドの大きさを定義している．
  FIELD_SIZE = 5
  # 艦隊(Shipオブジェクトの連想配列)にアクセスできる．
  attr :ships

  #
  # 艦種ごとに座標を与えられるので，Shipオブジェクトを作成し，連想配列に加える．
  # 艦のtypeがkeyになる．
  #
  def initialize(positions)
    @ships = {}
    positions.each do |type, position|
      @ships[type] = PlayerShip.new(type, position)
    end
  end

  # 初期状態をJSONで返す．
  def initial_condition
    cond = {}
    @ships.values.each do |ship|
      cond[ship.type] = ship.position
    end
    cond.to_json
  end

  # 行動する．行動を決定するアルゴリズムはサブクラスでそれぞれ記述するべきなので抽象メソッドである．
  def action
  end

  # 通知された情報で艦の状態を更新する．
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

  # 移動の処理を行い，連想配列で結果を返す．
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

  # 攻撃の処理を行い，連想配列で結果を返す．
  def attack(to)
    {
        "attack" => {
            "to" => to
        }
    }
  end

  #
  # 攻撃された時の処理．攻撃を受けた艦，あるいは周囲1マスにいる艦を調べ，状態を更新する．
  # 相手プレイヤーに渡す情報を連想配列で返す．
  #
  def attacked(to)
    ship = overlap(to)

    if !ship.nil?
      ship.damaged(1)

      if ship.hp == 0
        @ships.delete(ship.type)
      end
    end
  end

  # 艦隊の攻撃可能な範囲を返す．
  def attackable?(to)
    Player.in_field?(to) && @ships.values.any?{|ship| ship.attackable?(to)}
  end

  # 与えられた座標がフィールドないかどうかを返す．
  def self.in_field?(position)
    position[0] < FIELD_SIZE && position[1] < FIELD_SIZE &&
        position[0] >= 0 && position[1] >= 0
  end

  # 与えられた座標にいる艦を返す．
  def overlap(position)
    @ships.values.each do |ship|
      if ship.position == position
        return ship
      end
    end
    nil
  end
end
