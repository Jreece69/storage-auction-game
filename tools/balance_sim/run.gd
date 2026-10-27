extends SceneTree
## The balance sim: BalanceBot plays many runs of 30 in-game days, at a few
## bidding styles, and this prints a Markdown report of cash over time and
## how lockers pay off. Every run has its own seed, so any run can be
## replayed. Start it with tools/balance_sim.sh.
##
## Options (after --): --seeds=N (runs per style, default 200),
## --days=N (default 30), --out=path (also write the report there).

## The bidding styles compared: [share of the estimate to bid up to,
## whether the bot plays the rivals (reads the shark, jump-bids the rookie)
## and minds its stock (sits auctions out with this many items unsold, 0 for
## never)].
const STYLES: Array[Array] = [[0.6, false, 0], [0.75, true, 0], [0.75, true, 14]]
## The style the day-by-day table follows (an index into STYLES).
const MAIN_STYLE: int = 2
## A locker worth this many times its price counts as a jackpot.
const JACKPOT_MULTIPLE: float = 10.0


## Everything measured for one bidding style, across all its runs.
class StyleResult:
	var share: float
	var reads: bool
	var max_stock: int
	## Per day, every run's cash (and net worth) after the day closed.
	var cash_by_day: Array[PackedInt64Array] = []
	var worth_by_day: Array[PackedInt64Array] = []
	var wins: Array[Dictionary] = []
	var lockers_offered: int = 0
	var spent: int = 0
	## Sales plus scrap.
	var takings: int = 0
	var runs_with_scrap_job: int = 0
	var runs_below_start: int = 0
	## Per run, the market value of what was still unsold at the end.
	var stock_left: PackedInt64Array = PackedInt64Array()


func _initialize() -> void:
	var options := _options()
	var seeds := options["seeds"].to_int() if options.has("seeds") else 200
	var days := options["days"].to_int() if options.has("days") else 30
	var catalog := Catalog.load_from()
	if not catalog.errors.is_empty():
		printerr("The content doesn't load:\n" + "\n".join(catalog.errors))
		quit(1)
		return
	var started := Time.get_ticks_msec()
	var styles: Array[StyleResult] = []
	for style in STYLES:
		var reads: bool = style[1]
		styles.append(_run_style(catalog, JsonValue.as_float(style[0]), reads, JsonValue.as_int(style[2]), seeds, days))
	var report := _report(catalog, styles, seeds, days)
	print(report)
	print("(%d runs in %.1f s)" % [seeds * STYLES.size(), (Time.get_ticks_msec() - started) / 1000.0])
	if options.has("out"):
		var file := FileAccess.open(options["out"], FileAccess.WRITE)
		file.store_string(report)
		file.close()
	quit()


## Plays [param seeds] runs of [param days] days with one bidding style.
func _run_style(catalog: Catalog, share: float, reads: bool, max_stock: int, seeds: int, days: int) -> StyleResult:
	var result := StyleResult.new()
	result.share = share
	result.reads = reads
	result.max_stock = max_stock
	for day in days:
		result.cash_by_day.append(PackedInt64Array())
		result.worth_by_day.append(PackedInt64Array())
	for run_seed in range(1, seeds + 1):
		var controller := RunController.new_run(catalog, RngStreams.new(run_seed))
		var bot := BalanceBot.new(controller)
		bot.bid_share = share
		bot.reads_rivals = reads
		bot.jumps_at_skittish = reads
		bot.max_stock = max_stock
		for day in days:
			var summary := bot.play_day()
			result.cash_by_day[day].append(controller.run.cash)
			result.worth_by_day[day].append(controller.net_worth())
			result.lockers_offered += JsonValue.as_int(summary["lockers_won"]) + JsonValue.as_int(summary["lockers_lost"])
			result.spent += JsonValue.as_int(summary["spent_on_lockers"])
			result.takings += JsonValue.as_int(summary["sales"]) + JsonValue.as_int(summary["scrap"])
		result.wins.append_array(bot.wins)
		if bot.scrap_jobs > 0:
			result.runs_with_scrap_job += 1
		if controller.run.cash < catalog.economy.starting_cash:
			result.runs_below_start += 1
		result.stock_left.append(controller.net_worth() - controller.run.cash)
	return result


func _report(catalog: Catalog, styles: Array[StyleResult], seeds: int, days: int) -> String:
	var lines: Array[String] = []
	lines.append("# Balance sim report")
	lines.append("")
	lines.append("%d runs of %d days for each bidding style (seeds 1 to %d), starting with %s. Made by `tools/balance_sim.sh`." % [seeds, days, seeds, Money.format(catalog.economy.starting_cash)])
	lines.append("Each bot estimates a locker from the items it can see and bids up to a share of that estimate. A bot that plays the rivals also raises its estimate while the shark keeps bidding, judges the locker from the price the shark drops out at, and opens with a jump bid to scare off the rookie. A bot that minds its stock sits the auctions out while 14 or more items are unsold.")
	lines.append("Ranges are the middle 80% of runs.")
	lines.append("")
	lines.append("## Cash at the end of each week")
	lines.append("")
	var header := "| Bot |"
	var rule := "|---|"
	var checkpoints: Array[int] = []
	for day in range(7, days + 1, 7):
		checkpoints.append(day)
	if checkpoints.is_empty() or checkpoints[-1] != days:
		checkpoints.append(days)
	for day in checkpoints:
		header += " Day %d |" % day
		rule += "---|"
	lines.append(header)
	lines.append(rule)
	for style in styles:
		var row := "| %s |" % _style_name(style)
		for day in checkpoints:
			row += " %s |" % _spread(style.cash_by_day[day - 1])
		lines.append(row)
	lines.append("")
	lines.append("## Lockers")
	lines.append("")
	lines.append("| Bot | Won | Median price | Contents value ÷ price, all wins | Median win | Wins worth %d× or more | Left behind, share of contents | Sales and scrap ÷ spent | Same, counting unsold stock |" % roundi(JACKPOT_MULTIPLE))
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for style in styles:
		var prices := PackedInt64Array()
		var multiples := PackedFloat64Array()
		var total_price := 0
		var total_value := 0
		var jackpots := 0
		var left_behind := 0
		for win in style.wins:
			left_behind += JsonValue.as_int(win["left_behind"])
			var price := JsonValue.as_int(win["price"])
			var value := JsonValue.as_int(win["value"])
			prices.append(price)
			multiples.append(float(value) / maxi(price, 1))
			total_price += price
			total_value += value
			if value >= price * JACKPOT_MULTIPLE:
				jackpots += 1
		var won := style.wins.size()
		var won_share := "%d of %d (%d%%)" % [won, style.lockers_offered, roundi(100.0 * won / maxi(style.lockers_offered, 1))]
		var jackpot_text := "none" if jackpots == 0 else "1 in %d" % roundi(float(won) / jackpots)
		var stock := 0
		for value in style.stock_left:
			stock += value
		lines.append("| %s | %s | %s | %.2f× | %.2f× | %s | %d%% | %.2f× | %.2f× |" % [
			_style_name(style), won_share, Money.format(_percentile(prices, 0.5)),
			float(total_value) / maxi(total_price, 1), _percentile_f(multiples, 0.5), jackpot_text,
			roundi(100.0 * left_behind / maxi(total_value, 1)), float(style.takings) / maxi(style.spent, 1),
			float(style.takings + stock) / maxi(style.spent, 1)])
	lines.append("")
	lines.append("## Trouble")
	lines.append("")
	lines.append("| Bot | Runs that needed a scrap job | Runs below the starting cash on day %d | Unsold stock on day %d, at market value |" % [days, days])
	lines.append("|---|---|---|---|")
	for style in styles:
		lines.append("| %s | %d of %d | %d of %d | %s |" % [_style_name(style), style.runs_with_scrap_job, seeds, style.runs_below_start, seeds, _spread(style.stock_left)])
	lines.append("")
	var main := styles[MAIN_STYLE]
	lines.append("## Day by day: %s" % _style_name(main))
	lines.append("")
	lines.append("| Day | Cash | Net worth |")
	lines.append("|---|---|---|")
	for day in days:
		lines.append("| %d | %s | %s |" % [day + 1, _spread(main.cash_by_day[day]), _spread(main.worth_by_day[day])])
	lines.append("")
	return "\n".join(lines)


func _style_name(style: StyleResult) -> String:
	var name := "%d%% of its estimate" % roundi(style.share * 100.0)
	if style.reads:
		name += ", plays the rivals"
	if style.max_stock > 0:
		name += ", minds its stock"
	return name


## "$640 ($410 to $900)": the median and the middle 80%.
func _spread(values: PackedInt64Array) -> String:
	return "%s (%s to %s)" % [Money.format(_percentile(values, 0.5)), Money.format(_percentile(values, 0.1)), Money.format(_percentile(values, 0.9))]


func _percentile(values: PackedInt64Array, share: float) -> int:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(roundi(share * (sorted.size() - 1)), 0, sorted.size() - 1)]


func _percentile_f(values: PackedFloat64Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(roundi(share * (sorted.size() - 1)), 0, sorted.size() - 1)]


func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
