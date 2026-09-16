class_name VngCondition
extends RefCounted

const COMPARISON_OPS := ["==", "!=", ">=", "<=", ">", "<"]


static func parse(text: String) -> Dictionary:
	var tokens: Array = []
	var tokenize_error := _tokenize(text, tokens)
	if tokenize_error != "":
		return {"ok": false, "error": tokenize_error, "ast": null}
	var parser := {"tokens": tokens, "index": 0, "error": ""}
	var ast: Variant = _parse_or(parser)
	if ast == null:
		var message: String = parser.error
		return {"ok": false, "error": message if message != "" else "表达式解析失败", "ast": null}
	if parser.index < tokens.size():
		return {"ok": false, "error": "多余的内容 '%s'" % _token_text(tokens[parser.index]), "ast": null}
	return {"ok": true, "error": "", "ast": ast}


static func evaluate(ast: Variant, state: VngStoryState, undefined_names: Array = []) -> Dictionary:
	if ast == null or not (ast is Dictionary):
		return {"ok": false, "value": false, "error": "空表达式"}
	var kind: String = ast.get("k", "")
	match kind:
		"lit":
			return {"ok": true, "value": ast.get("v", null), "error": ""}
		"ident":
			return _resolve_identifier(ast.get("v", ""), state, undefined_names)
		"not":
			var inner := evaluate(ast.get("x", null), state, undefined_names)
			if not inner.ok:
				return inner
			var inner_value: Variant = inner.value
			if inner_value == null:
				inner_value = false
			if not (inner_value is bool):
				return {"ok": false, "value": false, "error": "'not' 需要布尔值"}
			return {"ok": true, "value": not (inner_value as bool), "error": ""}
		"and", "or":
			return _evaluate_logical(kind, ast, state, undefined_names)
		"cmp":
			return _evaluate_comparison(ast, state, undefined_names)
	return {"ok": false, "value": false, "error": "未知表达式节点 '%s'" % kind}


static func evaluate_text(text: String, state: VngStoryState, undefined_names: Array = []) -> Dictionary:
	var parsed := parse(text)
	if not parsed.ok:
		return {"ok": false, "value": false, "error": parsed.error}
	return evaluate(parsed.ast, state, undefined_names)


static func _evaluate_logical(kind: String, ast: Dictionary, state: VngStoryState, undefined_names: Array) -> Dictionary:
	var left := evaluate(ast.get("l", null), state, undefined_names)
	if not left.ok:
		return left
	var left_value: Variant = left.value
	if left_value == null:
		left_value = false
	if not (left_value is bool):
		return {"ok": false, "value": false, "error": "'%s' 需要布尔值" % kind}
	if kind == "and" and not (left_value as bool):
		return {"ok": true, "value": false, "error": ""}
	if kind == "or" and (left_value as bool):
		return {"ok": true, "value": true, "error": ""}
	var right := evaluate(ast.get("r", null), state, undefined_names)
	if not right.ok:
		return right
	var right_value: Variant = right.value
	if right_value == null:
		right_value = false
	if not (right_value is bool):
		return {"ok": false, "value": false, "error": "'%s' 需要布尔值" % kind}
	return {"ok": true, "value": right_value, "error": ""}


static func _evaluate_comparison(ast: Dictionary, state: VngStoryState, undefined_names: Array) -> Dictionary:
	var left := evaluate(ast.get("l", null), state, undefined_names)
	if not left.ok:
		return left
	var right := evaluate(ast.get("r", null), state, undefined_names)
	if not right.ok:
		return right
	var lv: Variant = _default_if_undefined(left.value, right.value)
	var rv: Variant = _default_if_undefined(right.value, left.value)
	var op: String = ast.get("op", "")
	if op == "==" or op == "!=":
		if lv == null or rv == null:
			return {"ok": false, "value": false, "error": "'%s' 无法比较空值" % op}
		if typeof(lv) != typeof(rv) and not (_is_number(lv) and _is_number(rv)):
			return {"ok": false, "value": false, "error": "'%s' 两侧类型不一致" % op}
		var equal: bool = lv == rv
		return {"ok": true, "value": equal if op == "==" else not equal, "error": ""}
	if not (_is_number(lv) and _is_number(rv)):
		return {"ok": false, "value": false, "error": "比较运算需要数值"}
	var a := float(lv)
	var b := float(rv)
	match op:
		">":
			return {"ok": true, "value": a > b, "error": ""}
		">=":
			return {"ok": true, "value": a >= b, "error": ""}
		"<":
			return {"ok": true, "value": a < b, "error": ""}
		"<=":
			return {"ok": true, "value": a <= b, "error": ""}
	return {"ok": false, "value": false, "error": "未知比较运算 '%s'" % op}


static func _default_if_undefined(value: Variant, other: Variant) -> Variant:
	if value != null:
		return value
	if other == null:
		return false
	if _is_number(other):
		return 0
	if other is bool:
		return false
	return null


static func _resolve_identifier(name: String, state: VngStoryState, undefined_names: Array) -> Dictionary:
	if state.flags.has(name):
		return {"ok": true, "value": state.flags[name], "error": ""}
	if state.vars.has(name):
		return {"ok": true, "value": state.vars[name], "error": ""}
	if not undefined_names.has(name):
		undefined_names.append(name)
	return {"ok": true, "value": null, "error": ""}


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _parse_or(parser: Dictionary) -> Variant:
	var left: Variant = _parse_and(parser)
	if left == null:
		return null
	while _peek_op(parser, "||"):
		_next(parser)
		var right: Variant = _parse_and(parser)
		if right == null:
			return null
		left = {"k": "or", "l": left, "r": right}
	return left


static func _parse_and(parser: Dictionary) -> Variant:
	var left: Variant = _parse_unary(parser)
	if left == null:
		return null
	while _peek_op(parser, "&&"):
		_next(parser)
		var right: Variant = _parse_unary(parser)
		if right == null:
			return null
		left = {"k": "and", "l": left, "r": right}
	return left


static func _parse_unary(parser: Dictionary) -> Variant:
	if _peek_op(parser, "!"):
		_next(parser)
		var operand: Variant = _parse_unary(parser)
		if operand == null:
			return null
		return {"k": "not", "x": operand}
	return _parse_comparison(parser)


static func _parse_comparison(parser: Dictionary) -> Variant:
	var left: Variant = _parse_primary(parser)
	if left == null:
		return null
	for op in COMPARISON_OPS:
		if _peek_op(parser, op):
			_next(parser)
			var right: Variant = _parse_primary(parser)
			if right == null:
				return null
			return {"k": "cmp", "op": op, "l": left, "r": right}
	return left


static func _parse_primary(parser: Dictionary) -> Variant:
	var token := _peek(parser)
	if token.is_empty():
		_set_error(parser, "表达式意外结束")
		return null
	match token.get("k", ""):
		"lparen":
			_next(parser)
			var inner: Variant = _parse_or(parser)
			if inner == null:
				return null
			if not _peek_kind(parser, "rparen"):
				_set_error(parser, "缺少右括号")
				return null
			_next(parser)
			return inner
		"int", "bool":
			_next(parser)
			return {"k": "lit", "v": token.get("v", null)}
		"ident":
			_next(parser)
			return {"k": "ident", "v": token.get("v", "")}
	_set_error(parser, "意外符号 '%s'" % _token_text(token))
	return null


static func _peek(parser: Dictionary) -> Dictionary:
	var tokens: Array = parser.tokens
	var index: int = parser.index
	if index >= tokens.size():
		return {}
	return tokens[index]


static func _peek_kind(parser: Dictionary, kind: String) -> bool:
	return _peek(parser).get("k", "") == kind


static func _peek_op(parser: Dictionary, value: String) -> bool:
	var token := _peek(parser)
	return token.get("k", "") == "op" and token.get("v", "") == value


static func _next(parser: Dictionary) -> void:
	parser.index += 1


static func _set_error(parser: Dictionary, message: String) -> void:
	if parser.error == "":
		parser.error = message


static func _token_text(token: Dictionary) -> String:
	return str(token.get("v", "?"))


static func _tokenize(text: String, out: Array) -> String:
	var i := 0
	var length := text.length()
	while i < length:
		var c := text[i]
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			i += 1
			continue
		if c == "(":
			out.append({"k": "lparen", "v": "(", "pos": i})
			i += 1
			continue
		if c == ")":
			out.append({"k": "rparen", "v": ")", "pos": i})
			i += 1
			continue
		if c == "&" and i + 1 < length and text[i + 1] == "&":
			out.append({"k": "op", "v": "&&", "pos": i})
			i += 2
			continue
		if c == "|" and i + 1 < length and text[i + 1] == "|":
			out.append({"k": "op", "v": "||", "pos": i})
			i += 2
			continue
		if c == "=" and i + 1 < length and text[i + 1] == "=":
			out.append({"k": "op", "v": "==", "pos": i})
			i += 2
			continue
		if c == "!" and i + 1 < length and text[i + 1] == "=":
			out.append({"k": "op", "v": "!=", "pos": i})
			i += 2
			continue
		if c == "!":
			out.append({"k": "op", "v": "!", "pos": i})
			i += 1
			continue
		if c == ">" or c == "<":
			if i + 1 < length and text[i + 1] == "=":
				out.append({"k": "op", "v": c + "=", "pos": i})
				i += 2
			else:
				out.append({"k": "op", "v": c, "pos": i})
				i += 1
			continue
		if c == "-" and i + 1 < length and _is_digit(text[i + 1]):
			var end_negative := _scan_digits(text, i + 1)
			out.append({"k": "int", "v": int(text.substr(i, end_negative - i)), "pos": i})
			i = end_negative
			continue
		if _is_digit(c):
			var end_number := _scan_digits(text, i)
			out.append({"k": "int", "v": int(text.substr(i, end_number - i)), "pos": i})
			i = end_number
			continue
		if _is_ident_start(c):
			var end_ident := _scan_ident(text, i)
			var word := text.substr(i, end_ident - i)
			if word == "true" or word == "false":
				out.append({"k": "bool", "v": word == "true", "pos": i})
			elif word == "not":
				out.append({"k": "op", "v": "!", "pos": i})
			else:
				out.append({"k": "ident", "v": word, "pos": i})
			i = end_ident
			continue
		return "无法识别的字符 '%s'（位置 %d）" % [c, i]
	return ""


static func _scan_digits(text: String, start: int) -> int:
	var i := start
	while i < text.length() and _is_digit(text[i]):
		i += 1
	return i


static func _scan_ident(text: String, start: int) -> int:
	var i := start
	while i < text.length() and _is_ident_char(text[i]):
		i += 1
	return i


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_ident_start(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


static func _is_ident_char(c: String) -> bool:
	return _is_ident_start(c) or _is_digit(c)
