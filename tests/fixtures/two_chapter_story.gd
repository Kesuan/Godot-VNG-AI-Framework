extends RefCounted


static func build() -> Dictionary:
	return {
		"manifest": {
			"schema": 1,
			"entry": "chapter1.start",
			"entries": {"chapter1": "start", "chapter2": "wake"},
			"chapters": ["chapter1", "chapter2"],
			"characters": {"kaede": {"name": "枫"}},
		},
		"chapters": {
			"chapter1": {
				"schema": 1,
				"chapter": "chapter1",
				"source": "res://tests/fixtures/story_two/chapter1.vns",
				"nodes": {
					"start": {
						"id": "start",
						"steps": [
							{"op": "bg", "asset": "room"},
							{"op": "set", "name": "met_kaede", "assign": "=", "value": true},
							{"op": "say", "who": "", "text": "第一章开始了。"},
							{"op": "goto", "target": "proceed"},
						],
					},
					"proceed": {
						"id": "proceed",
						"steps": [
							{"op": "say", "who": "kaede", "text": "雨停了。"},
							{"op": "goto", "target": "END"},
						],
					},
					"detour": {
						"id": "detour",
						"steps": [
							{"op": "say", "who": "", "text": "你提前离开。"},
							{"op": "goto", "target": "chapter2.early"},
						],
					},
				},
			},
			"chapter2": {
				"schema": 1,
				"chapter": "chapter2",
				"source": "res://tests/fixtures/story_two/chapter2.vns",
				"nodes": {
					"wake": {
						"id": "wake",
						"steps": [
							{"op": "say", "who": "", "text": "第二章开始了。"},
							{"op": "goto", "target": "END"},
						],
					},
					"early": {
						"id": "early",
						"steps": [
							{"op": "say", "who": "", "text": "你提前抵达。"},
							{"op": "goto", "target": "STORY_END"},
						],
					},
				},
			},
		},
	}


static func build_missing_entry() -> Dictionary:
	var story := build()
	(story.manifest as Dictionary)["entries"] = {"chapter1": "start"}
	return story
