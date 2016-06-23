require('test/unit')
load('server.rb')

class T_Server < Test::Unit::TestCase

  def test_ship_new
    assert_raise do
      Ship.new("a", [0,0])
    end
    w = Ship.new("w", [1,1])
    assert_equal("w", w.type)
    assert_equal(3, w.hp)
    assert_equal([1,1], w.position)
  end

  def test_ship_moved
    w = Ship.new("w", [1,1])
    w.moved([1,2])
    assert_equal(w.position, [1,2])
  end

  def test_ship_damaged
    w = Ship.new("w", [1,1])
    w.damaged(1)
    assert_equal(w.hp, 2)
  end

  def test_client_new
    assert_raise do
      Client.new({"w" => [0,0], "c" => [0,1], "s" => [0,0]})
    end
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal([0,0], c.ships["w"].position)
    assert_equal([0,1], c.ships["c"].position)
    assert_equal([1,0], c.ships["s"].position)
  end

  def test_client_move
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal(false, c.move("a", [1,1]))
    assert_equal(false, c.move("w", [5,5]))
    assert_equal(false, c.move("w", [0,1]))
    assert_equal(false, c.move("w", [1,1]))
    assert_equal({"ship" => "w", "distance" => [0, 2]}, c.move("w", [0,2]))
    assert_equal([0,2], c.ships["w"].position)
  end

  def test_client_attacked
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal(false, c.attacked([5,5]))
    assert_equal({
                   "position" => [2,2],
                   "near" => []
                 }, c.attacked([2,2]))
    assert_equal({
                   "position" => [0,0],
                   "hit" => "w",
                   "near" => ["c", "s"]
                 }, c.attacked([0,0]))
    assert_equal(2, c.ships["w"].hp)
    assert_equal({
                   "position" => [1,0],
                   "hit" => "s",
                   "near" => ["w", "c"]
                 }, c.attacked([1,0]))
    puts c.ships
    assert_equal(false, c.ships.has_key?("s"))
  end

  def test_client_condition
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal({
                   "w" => {
                     "hp" => 3,
                     "position" => [0,0]
                   },
                   "c" => {
                     "hp" => 2,
                     "position" => [0,1]
                   },
                   "s" => {
                     "hp" => 1,
                     "position" => [1,0]
                   }
                 }, c.condition(true))
    assert_equal({
                   "w" => {
                     "hp" => 3
                   },
                   "c" => {
                     "hp" => 2
                   },
                   "s" => {
                     "hp" => 1
                   }
                 }, c.condition(false))
  end

  def test_client_overlap
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_nil(c.send(:overlap, [1,1]))
    assert_equal(c.ships["w"], c.send(:overlap, [0,0]))
  end

  def test_client_near
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal([], c.send(:near, [2,2]))
    assert_equal([c.ships["c"]], c.send(:near, [0,2]))
  end

  def test_client_in_field?
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal(true, c.send(:in_field?, [0,0]))
    assert_equal(false, c.send(:in_field?, [5,5]))
  end

  def test_client_reachable?
    c = Client.new({"w" => [0,0], "c" => [0,1], "s" => [1,0]})
    assert_equal(true, c.send(:reachable?, c.ships["w"], [0,4]))
    assert_equal(true, c.send(:reachable?, c.ships["w"], [4,0]))
    assert_equal(false, c.send(:reachable?, c.ships["w"], [1,1]))
  end

  def test_server_action
    json1 = {"w" => [0,0], "c" => [0,1], "s" => [1,0]}.to_json
    json2 = {"w" => [1,1], "c" => [1,0], "s" => [0,1]}.to_json
    s = Server.new(json1, json2)
    atk_t = {
      "attack" => {
        "to" => [1,1]
      }
    }.to_json
    atk_f = {
      "attack" => {
        "to" => [5,5]
      }
    }.to_json
    mov_t = {
      "move" => {
        "ship" => "w",
        "to" => [0,2]
      }
    }.to_json
    mov_f = {
      "move" => {
        "ship" => "w",
        "to" => [5,5]
      }
    }.to_json
    
    assert_equal([
                   {
                     "result" => {
                       "attacked" => {
                         "position" => [1, 1],
                         "hit" => "w",
                         "near" => ["c", "s"]
                       }
                     },
                     "condition" => {
                       "me" => {
                         "w" => {
                           "hp" => 3,
                           "position" => [0,0]
                         },
                         "c" => {
                           "hp" => 2,
                           "position" => [0,1]
                         },
                         "s" => {
                           "hp" => 1,
                           "position" => [1,0]
                         }
                       },
                       "enemy" => {
                         "w" => {
                           "hp" => 2
                         },
                         "c" => {
                           "hp" => 2
                         },
                         "s" => {
                           "hp" => 1
                         }
                       }
                     }
                   }.to_json,
                   {
                     "result" => {
                       "attacked" => {
                         "position" => [1, 1],
                         "hit" => "w",
                         "near" => ["c", "s"]
                       }
                     },
                     "condition" => {
                       "me" => {
                         "w" => {
                           "hp" => 2,
                           "position" =>[1,1]
                         },
                         "c" => {
                           "hp" => 2,
                           "position" => [1,0]
                         },
                         "s" => {
                           "hp" => 1,
                           "position" => [0,1]
                         }
                       },
                       "enemy" => {
                         "w" => {
                           "hp" => 3
                         },
                         "c" => {
                           "hp" => 2
                         },
                         "s" => {
                           "hp" => 1
                         }
                       }
                     }
                   }.to_json
                 ], s.action(0, atk_t))
     assert_equal([
                    {
                      "result" => {
                        "attacked" => false
                      },
                      "outcome" => false,
                      "condition" => {
                        "me" => {
                          "w" => {
                            "hp" => 3,
                            "position" => [0,0]
                          },
                          "c" => {
                            "hp" => 2,
                            "position" => [0,1]
                          },
                          "s" => {
                            "hp" => 1,
                            "position" => [1,0]
                          }
                        },
                        "enemy" => {
                          "w" => {
                            "hp" => 2
                          },
                          "c" => {
                            "hp" => 2
                          },
                          "s" => {
                            "hp" => 1
                          }
                        }
                      }
                    }.to_json,
                    {
                      "result" => {
                        "attacked" => false
                      },
                      "outcome" => true,
                      "condition" => {
                        "me" => {
                          "w" => {
                            "hp" => 2,
                            "position" =>[1,1]
                          },
                          "c" => {
                            "hp" => 2,
                            "position" => [1,0]
                          },
                          "s" => {
                            "hp" => 1,
                            "position" => [0,1]
                          }
                        },
                        "enemy" => {
                          "w" => {
                            "hp" => 3
                          },
                          "c" => {
                            "hp" => 2
                          },
                          "s" => {
                            "hp" => 1
                          }
                        }
                      }
                    }.to_json
                  ], s.action(0, atk_f))
      assert_equal([
                     {
                       "condition" => {
                         "me" => {
                           "w" => {
                             "hp" => 3,
                             "position" => [0,2]
                           },
                           "c" => {
                             "hp" => 2,
                             "position" => [0,1]
                           },
                           "s" => {
                             "hp" => 1,
                             "position" => [1,0]
                           }
                         },
                         "enemy" => {
                           "w" => {
                             "hp" => 2
                           },
                           "c" => {
                             "hp" => 2
                           },
                           "s" => {
                             "hp" => 1
                           }
                         }
                       }
                     }.to_json,
                     {
                       "result" => {
                         "moved" => {
                           "ship" => "w",
                           "distance" => [0, 2]
                         }
                       },
                       "condition" => {
                         "me" => {
                           "w" => {
                             "hp" => 2,
                             "position" =>[1,1]
                           },
                           "c" => {
                             "hp" => 2,
                             "position" => [1,0]
                           },
                           "s" => {
                             "hp" => 1,
                             "position" => [0,1]
                           }
                         },
                         "enemy" => {
                           "w" => {
                             "hp" => 3
                           },
                           "c" => {
                             "hp" => 2
                           },
                           "s" => {
                             "hp" => 1
                           }
                         }
                       }
                     }.to_json
                   ], s.action(0, mov_t))
      assert_equal([
                     {
                       "outcome" => false,  
                       "condition" => {
                         "me" => {
                           "w" => {
                             "hp" => 3,
                             "position" => [0,2]
                           },
                           "c" => {
                             "hp" => 2,
                             "position" => [0,1]
                           },
                           "s" => {
                             "hp" => 1,
                             "position" => [1,0]
                           }
                         },
                         "enemy" => {
                           "w" => {
                             "hp" => 2
                           },
                           "c" => {
                             "hp" => 2
                           },
                           "s" => {
                             "hp" => 1
                           }
                         }
                       }
                     }.to_json,
                     {
                       "result" => {
                         "moved" => false
                       },
                       "outcome" => true,
                       "condition" => {
                         "me" => {
                           "w" => {
                             "hp" => 2,
                             "position" =>[1,1]
                           },
                           "c" => {
                             "hp" => 2,
                             "position" => [1,0]
                           },
                           "s" => {
                             "hp" => 1,
                             "position" => [0,1]
                           }
                         },
                         "enemy" => {
                           "w" => {
                             "hp" => 3
                           },
                           "c" => {
                             "hp" => 2
                           },
                           "s" => {
                             "hp" => 1
                           }
                         }
                       }
                     }.to_json
                   ], s.action(0, mov_f))
  end
end