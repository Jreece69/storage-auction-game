class_name ShopCounter
extends RefCounted
## One crew member's place at the shop counter: the customer they're serving
## and how the last one went. In co-op every member has their own, so several
## customers can be served at once.

enum Outcome { NONE, SOLD, DEAL, RAISED, LOST_PATIENCE, DECLINED, BROWSING, TOO_PRICEY }

## The customer at this counter, or null.
var customer: Customer = null
## What kind of item they picked up, kept after it's sold.
var item_def: StringName = &""
var outcome: Outcome = Outcome.NONE
## What the outcome was about: the sale price, or the raised offer.
var amount: int = 0


## Whether a customer here is still making offers.
func is_busy() -> bool:
	return customer != null and customer.is_offering()


func to_dict(secrets: bool = false) -> Dictionary:
	return {
		"customer": customer.to_dict(secrets) if customer != null else {},
		"item_def": String(item_def),
		"outcome": outcome,
		"amount": amount,
	}


static func from_dict(data: Dictionary, catalog: Catalog, price_step: int) -> ShopCounter:
	var counter := ShopCounter.new()
	var customer_data: Dictionary = data.get("customer", {})
	if not customer_data.is_empty():
		counter.customer = Customer.from_dict(customer_data, catalog, price_step)
	counter.item_def = JsonValue.as_name(data.get("item_def", ""))
	counter.outcome = JsonValue.as_int(data.get("outcome", Outcome.NONE)) as Outcome
	counter.amount = JsonValue.as_int(data.get("amount", 0))
	return counter
