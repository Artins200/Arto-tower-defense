--!strict
-- Конфигурация, которую сервер считает источником истины.
return {
 {{kind="Rabbit", count=5, interval=1.2}},
 {{kind="Rabbit", count=7, interval=0.9}, {kind="Cat", count=3, interval=1.2}},
 {{kind="Cat", count=8, interval=0.9}, {kind="Rabbit", count=6, interval=0.6}},
 {{kind="Dog", count=5, interval=1.3}, {kind="Cat", count=7, interval=0.8}},
 {{kind="Dog", count=6, interval=1}, {kind="Raccoon", count=1, interval=1}},
 {{kind="Bear", count=4, interval=1.5}, {kind="Rabbit", count=12, interval=0.5}},
 {{kind="Cat", count=12, interval=0.6}, {kind="Dog", count=8, interval=0.8}},
 {{kind="Bear", count=7, interval=1}, {kind="Dog", count=8, interval=0.7}},
 {{kind="Rabbit", count=18, interval=0.4}, {kind="Bear", count=9, interval=0.8}},
 {{kind="Bear", count=10, interval=0.7}, {kind="Raccoon", count=2, interval=2}},
}
