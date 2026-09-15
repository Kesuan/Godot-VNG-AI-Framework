extends RefCounted


static func build() -> Dictionary:
	return {
		"chapter": "chapter1",
		"nodes": {
			"prologue": {
				"id": "prologue",
				"steps": [
					{"op": "bg", "asset": "classroom_day"},
					{"op": "show", "char": "yuki", "expr": "happy", "pos": "center"},
					{"op": "bgm", "asset": "bgm_daily"},
					{"op": "say", "who": "yuki", "text": "早上好！"},
					{"op": "set", "name": "met_yuki", "assign": "=", "value": true},
					{"op": "say", "who": "", "text": "你推开了门。"},
					{
						"op": "choice",
						"options": [
							{"text": "打招呼", "target": "greet_warm", "cond": "trust >= 2"},
							{"text": "打招呼", "target": "greet"},
							{"text": "无视", "target": "ignore"},
						],
					},
				],
			},
			"greet_warm": {
				"id": "greet_warm",
				"steps": [
					{"op": "set", "name": "route_yuki", "assign": "=", "value": true},
					{"op": "say", "who": "yuki", "text": "你终于来了。"},
					{"op": "goto", "target": "END"},
				],
			},
			"greet": {
				"id": "greet",
				"steps": [
					{"op": "set", "name": "trust", "assign": "+=", "value": 1},
					{"op": "set", "name": "route_yuki", "assign": "=", "value": true},
					{"op": "say", "who": "yuki", "text": "太好了。"},
					{"op": "goto", "target": "END"},
				],
			},
			"ignore": {
				"id": "ignore",
				"steps": [
					{"op": "say", "who": "yuki", "text": "……"},
					{"op": "hide", "char": "yuki"},
					{"op": "goto", "target": "END"},
				],
			},
		},
	}
