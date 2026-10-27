extends Node
## Game-wide signals. Systems emit and listen here instead of holding
## references to each other, so each system can be built and tested alone.
##
## Add a signal when a second system needs to hear about an event. Keep the
## arguments plain data (ints, strings, dictionaries), never scene nodes.

# Signals are emitted from other scripts, which the per-class check can't see.
@warning_ignore_start("unused_signal")

## A new in-game day began.
signal day_started(day: int)

## The player's cash changed. [param cash] is the new balance in whole dollars.
signal cash_changed(cash: int)

## A locker's auction ended. [param winner] is a crew member (p1 to p4), a
## rival id, or empty if it went unsold.
signal locker_settled(lot_number: int, winner: StringName, price: int)

## An item left the shop with a customer.
signal item_sold(uid: int, price: int)

## The day closed. [param summary] holds the end-of-day numbers.
signal day_ended(summary: Dictionary)

## A screen asks to move on to another one (see Screens). The app shell
## does the swap, so a screen never needs to know about the others.
signal screen_requested(screen: StringName)

## Something about the day in progress changed (see DayFlow): screens
## redraw, and the app shell shows the screen for the day's stage.
signal flow_changed()

## What happened in the auction, in order (see Auction), for feeds and
## effects.
signal auction_events(events: Array[Dictionary])

## A save slot was written to disk.
signal game_saved(slot: String)

## A save slot was read and applied to the game.
signal game_loaded(slot: String)
