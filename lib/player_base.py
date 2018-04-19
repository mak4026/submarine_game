import json


# プレイヤーの船を表すクラスである．
class PlayerShip:
    # 船の種類と最大HPを定義している．
    MAX_HPS = {"w": 3, "c": 2, "s": 1}

    # 種類と場所を与えられる．HPは自動で決まる．
    def __init__(self, ship_type, position):
        if ship_type not in PlayerShip.MAX_HPS:
            raise ValueError('invalid type supecified')

        self.type = ship_type
        self.position = position
        self.hp = PlayerShip.MAX_HPS[ship_type]

    # 座標を変更する．
    def moved(self, to):
        self.position = to

    # ダメージを受けてHPが減る．
    def damaged(self, d):
        self.hp -= d

    # 座標が移動できる範囲(縦横)にあるか確認する．
    def can_reach(self, to):
        return self.position[0] == to[0] or self.position[1] == to[1]

    # 座標が攻撃できる範囲(自分の座標及び周囲1マス)にあるか確認する．
    def can_attack(self, to):
        return abs(to[0] - self.position[0]) <= 1\
            and abs(to[1] - self.position[1]) <= 1


# プレイヤーを表すクラスである．艦を複数保持している．
class Player:
    # フィールドの大きさを定義している．
    FIELD_SIZE = 5

    #
    # 艦種ごとに座標を与えられるので，Shipオブジェクトを作成し，連想配列に加える．
    # 艦のtypeがkeyになる．
    #
    def __init__(self, positions):
        self.ships = {ship_type: PlayerShip(ship_type, position)
                      for ship_type, position in positions.items()}

    # 初期状態をJSONで返す．
    def initial_condition(self):
        cond = {ship.type: ship.position for ship in self.ships.values()}
        return json.dumps(cond)

    # 行動する．行動を決定するアルゴリズムはサブクラスでそれぞれ記述するべきなので抽象メソッドである．
    def action(self):
        pass

    # 通知された情報で艦の状態を更新する．
    def update(self, json_):
        cond = json.loads(json_)['condition']['me']
        for ship_type in list(self.ships):
            if ship_type not in cond:
                self.ships.pop(ship_type)
            else:
                self.ships[ship_type].hp = cond[ship_type]['hp']
                self.ships[ship_type].position = cond[ship_type]['position']

    # 移動の処理を行い，連想配列で結果を返す．
    def move(self, ship_type, to):
        ship = self.ships[ship_type]
        ship.moved(to)
        return {
            "move": {
                "ship": ship_type,
                "to": to
            }
        }

    # 攻撃の処理を行い，連想配列で結果を返す．
    def attack(self, to):
        return {
            "attack": {
                "to": to
            }
        }

    # 艦隊の攻撃可能な範囲を返す．
    def can_attack(self, to):
        return Player.in_field(to)\
            and any([ship.can_attack(to) for ship in self.ships.values()])

    # 与えられた座標がフィールドないかどうかを返す．
    def in_field(position):
        return position[0] < Player.FIELD_SIZE and position[1] < Player.FIELD_SIZE\
            and position[0] >= 0 and position[1] >= 0

    # 与えられた座標にいる艦を返す．
    def overlap(self, position):
        for ship in self.ships.values():
            if ship.position == position:
                return ship
        return None

if __name__ == '__main__':
    import unittest

    class PlayerShipTest(unittest.TestCase):

        def test_init(self):
            with self.assertRaises(ValueError):
                PlayerShip('a', [0, 0])
            w = PlayerShip('w', [1, 1])
            self.assertEqual("w", w.type)
            self.assertEqual(3, w.hp)
            self.assertEqual([1, 1], w.position)

        def test_moved(self):
            w = PlayerShip("w", [1, 1])
            w.moved([1, 2])
            self.assertEqual(w.position, [1, 2])

        def test_damaged(self):
            w = PlayerShip("w", [1, 1])
            w.damaged(1)
            self.assertEqual(w.hp, 2)

        def test_can_reach(self):
            w = PlayerShip("w", [0, 0])
            self.assertEqual(True, w.can_reach([0, 4]))
            self.assertEqual(True, w.can_reach([4, 0]))
            self.assertEqual(False, w.can_reach([1, 1]))

        def test_can_attack(self):
            w = PlayerShip("w", [2, 2])
            self.assertEqual(True, w.can_attack([2, 3]))
            self.assertEqual(True, w.can_attack([3, 1]))
            self.assertEqual(True, w.can_attack([3, 3]))
            self.assertEqual(False, w.can_attack([2, 0]))

    class PlayerTest(unittest.TestCase):

        def test_init(self):
            p = Player({"w": [0, 0], "c": [0, 1], "s": [1, 0]})
            self.assertEqual([0, 0], p.ships["w"].position)
            self.assertEqual([0, 1], p.ships["c"].position)
            self.assertEqual([1, 0], p.ships["s"].position)

        def test_initial_condition(self):
            p = Player({"w": [0, 0], "c": [0, 1], "s": [1, 0]})
            self.assertEqual(json.dumps({"w": [0, 0], "c": [0, 1], "s": [1, 0]}),
                             p.initial_condition())

        def test_update(self):
            p = Player({"w": [0, 0], "c": [0, 1], "s": [1, 0]})
            json_ = json.dumps({
                "condition": {
                    "me": {
                        "w": {
                            "hp": 2,
                            "position": [0, 0]
                        },
                        "c": {
                            "hp": 2,
                            "position": [0, 4]
                        },
                        "s": {
                            "hp": 1,
                            "position": [1, 0]
                        }
                    }
                }
            })
            p.update(json_)
            self.assertEqual(2, p.ships["w"].hp)
            self.assertEqual([0, 4], p.ships["c"].position)

        def test_move(self):
            p = Player({"w": [0, 0], "c": [0, 1], "s": [1, 0]})
            self.assertEqual({
                "move": {
                    "ship": "w",
                    "to": [0, 2]
                }
            }, p.move("w", [0, 2]))
            self.assertEqual([0, 2], p.ships["w"].position)

        def test_attack(self):
            p = Player({"w": [0, 0], "c": [0, 1], "s": [1, 0]})
            self.assertEqual({"attack": {"to": [1, 1]}}, p.attack([1, 1]))

        def test_overlap(self):
            p = Player({"w": [0, 0], "c": [0, 1], "s": [1, 0]})
            self.assertEqual(None, p.overlap([1, 1]))
            self.assertEqual(p.ships["w"], p.overlap([0, 0]))

        def test_in_field(self):
            self.assertEqual(True, Player.in_field([0, 0]))
            self.assertEqual(False, Player.in_field([5, 5]))
            self.assertEqual(False, Player.in_field([-1, 0]))

    unittest.main()
