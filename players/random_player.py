import sys
import json
import socket
import random

import os, sys
sys.path.append(os.getcwd())
from lib.player_base import Player, PlayerShip


class RandomPlayer(Player):

    def __init__(self):
        # フィールドを2x2の配列として持っている．
        self.field = [[i, j] for i in range(Player.FIELD_SIZE)
                      for j in range(Player.FIELD_SIZE)]

        # 初期配置を非復元抽出でランダムに決める．
        ps = random.sample(self.field, 3)
        positions = {'w': ps[0], 'c': ps[1], 's': ps[2]}
        super().__init__(positions)

    #
    # 移動か攻撃かランダムに決める．
    # どれがどこへ移動するか，あるいはどこに攻撃するかもランダム．
    #
    def action(self):
        act = random.choice(["move", "attack"])

        if act == "move":
            ship = random.choice(list(self.ships.values()))
            to = random.choice(self.field)
            while not ship.can_reach(to) or not self.overlap(to) is None:
                to = random.choice(self.field)

            return json.dumps(self.move(ship.type, to))
        elif act == "attack":
            to = random.choice(self.field)
            while not self.can_attack(to):
                to = random.choice(self.field)

            return json.dumps(self.attack(to))


# 仕様に従ってサーバとソケット通信を行う．
def main(host, port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.connect((host, int(port)))
        with sock.makefile(mode='rw', buffering=1) as sockfile:
            get_msg = sockfile.readline()
            print(get_msg)
            player = RandomPlayer()
            sockfile.write(player.initial_condition()+'\n')

            while True:
                info = sockfile.readline().rstrip()
                print(info)
                if info == "your turn":
                    sockfile.write(player.action()+'\n')
                    get_msg = sockfile.readline()
                    player.update(get_msg)
                elif info == "waiting":
                    get_msg = sockfile.readline()
                    player.update(get_msg)
                elif info == "you win":
                    break
                elif info == "you lose":
                    break
                elif info == "even":
                    break
                else:
                    raise RuntimeError('unknown information')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
