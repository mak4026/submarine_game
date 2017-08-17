from subprocess import Popen, PIPE, DEVNULL, TimeoutExpired
import time
import argparse
import sys
import os
import csv
import glob
from collections import Counter

class PlayerRuntimeError(Exception):
    pass

def result_from_bytes(bytes):
    return bytes.decode('UTF-8').rsplit('\n',2)[-2]

def play_one_game(timelimit, player_path, enemy_path):
    result = None

    server_proc = Popen(["ruby", "source/server.rb", "8000"], stdout=DEVNULL)
    time.sleep(1)
    player_proc = Popen(["ruby", player_path, "localhost", "8000"], stdout=PIPE, stderr=PIPE)
    enemy_proc = Popen(["ruby", enemy_path, "localhost", "8000"], stdout=DEVNULL)

    try:
        out, err = player_proc.communicate(timeout=15)
        if player_proc.returncode != 0: raise PlayerRuntimeError(err)
        result = result_from_bytes(out)
    except TimeoutExpired:
        player_proc.kill()
        server_proc.kill()
        enemy_proc.kill()
        result = "timeout"
    except PlayerRuntimeError as e:
        print(e)
        player_proc.kill()
        server_proc.kill()
        enemy_proc.kill()
        result = "runtime error"

    return result

def play_games(n, timelimit, player_path, enemy_path="players/random_player.rb"):
    total_result = {
        "player": os.path.basename(player_path),
        "win": 0,
        "total": 0,
        "timeout": 0,
        "error": 0
    }
    print("start {} vs. {}".format(player_path, enemy_path))

    for i in range(n):
        print("#{0}".format(i))
        r = play_one_game(timelimit, player_path, enemy_path)
        print(r)
        if r == "you win":
            total_result["win"] += 1
        elif r == "timeout":
            total_result["timeout"] += 1
        elif r == "runtime error":
            total_result["error"] += 1
        total_result["total"] += 1

    return total_result

def play_round_robin(n, timelimit, players_path_list):
    all_results = []
    for player_path in players_path_list:
        total_result = Counter({
            "player": os.path.basename(player_path),
            "win": 0,
            "total": 0,
            "timeout": 0,
            "error": 0
        })
        for enemy_path in players_path_list:
            one_result = play_games(n, timelimit, player_path, enemy_path)
            del one_result["player"]
            total_result.update(one_result)
        all_results.append(dict(total_result))
    return all_results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="潜水艦ゲームの連続対局を行います")
    parser.add_argument('player_dir', help="対局させるプレイヤープログラムがあるディレクトリ")
    parser.add_argument('-t', '--timelimit', nargs='?', type=int, help="タイムアウトする時間（秒） デフォルト15秒", default=15)
    parser.add_argument('-n', nargs='?', type=int, help="対局する回数 デフォルト10回", default=10)
    parser.add_argument('-o', '--output', nargs='?', help="csv出力するときのファイル名")
    parser.add_argument('--round-robin', action='store_true', help="総当り戦を行う")
    args = parser.parse_args()

    plist = glob.glob(args.player_dir + "*.rb")
    print("players -> {}".format(plist))
    print("="*15)
    try:
        if args.round_robin:
            res = play_round_robin(args.n, args.timelimit, plist)
        else:
            res = [play_games(args.n, args.timelimit, p) for p in plist]
    except:
        print(sys.exc_info())
    else:
        print("games end")

    print("="*15)

    if args.output is None:
        print("result")
        print(res)
    else:
        with open(args.output, 'w') as csvfile:
            fieldnames = ["player", "win", "total", "timeout", "error"]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for r in res:
                writer.writerow(r)
        print("output -> {}".format(args.output))
