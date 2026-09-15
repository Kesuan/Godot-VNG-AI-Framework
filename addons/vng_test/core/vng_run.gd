class_name VngRun
extends RefCounted

static var seed: int = 0
static var timeout_sec: float = 10.0
static var root: String = "res://tests"
static var report_dir: String = "res://test-results"
static var tree: SceneTree = null
static var update_traces := false
static var trace_dir := "res://tests/story/traces"
