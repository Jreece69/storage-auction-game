extends GutTest
## Proves the test runner itself works. If this is the only failure, the
## problem is GUT or CI, not the game.


func test_runner_executes_tests() -> void:
	assert_true(true, "GUT found and ran this test")
