class_name Money
extends RefCounted
## Money is whole dollars in an int. Formatting and rounding to numbers people
## actually say ($45, $120, $1,250) live here.


## "$1,250". Negative amounts read "-$40".
static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-$" if amount < 0 else "$") + digits + grouped


## The rounding step for an amount of this size: $5 under $200, $10 under
## $1,000, $25 under $5,000, $50 above.
static func nice_step(amount: float) -> int:
	var size := absf(amount)
	if size < 200.0:
		return 5
	if size < 1000.0:
		return 10
	if size < 5000.0:
		return 25
	return 50


## [param amount] rounded to the nearest nice step. Can return 0.
static func round_nice(amount: float) -> int:
	var step := nice_step(amount)
	return roundi(amount / step) * step


## [param amount] rounded up to the next nice step, for raises and minimums.
static func ceil_nice(amount: float) -> int:
	var step := nice_step(amount)
	return ceili(amount / step) * step
