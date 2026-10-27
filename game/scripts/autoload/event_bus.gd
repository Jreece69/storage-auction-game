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

## A save slot was written to disk.
signal game_saved(slot: String)

## A save slot was read and applied to the game.
signal game_loaded(slot: String)
