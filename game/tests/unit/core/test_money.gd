extends GutTest
## Money reads the way people say it, and prices land on round numbers.


func test_format_groups_thousands() -> void:
	assert_eq(Money.format(0), "$0")
	assert_eq(Money.format(45), "$45")
	assert_eq(Money.format(1250), "$1,250")
	assert_eq(Money.format(1000000), "$1,000,000")


func test_format_negative_amounts() -> void:
	assert_eq(Money.format(-40), "-$40")
	assert_eq(Money.format(-2500), "-$2,500")


func test_step_grows_with_the_amount() -> void:
	assert_eq(Money.nice_step(199), 5)
	assert_eq(Money.nice_step(200), 10)
	assert_eq(Money.nice_step(999), 10)
	assert_eq(Money.nice_step(1000), 25)
	assert_eq(Money.nice_step(4999), 25)
	assert_eq(Money.nice_step(5000), 50)


func test_round_nice_rounds_to_the_nearest_step() -> void:
	assert_eq(Money.round_nice(47), 45)
	assert_eq(Money.round_nice(48), 50)
	assert_eq(Money.round_nice(234), 230)
	assert_eq(Money.round_nice(1012), 1000)
	assert_eq(Money.round_nice(2), 0)


func test_ceil_nice_rounds_up() -> void:
	assert_eq(Money.ceil_nice(11), 15)
	assert_eq(Money.ceil_nice(15), 15)
	assert_eq(Money.ceil_nice(201), 210)
