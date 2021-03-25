# Insights

This file documents things I learned that may not have been obvious when first starting with VR development while working on Form From Functions.

## Scheduling recurring tasks for a future time is easier than waiting for edge change

For example, it's a lot easier to say "when it's past this time, run this logic and update the time to wait for" than it is to keep the last time and try to detect a transition like "it is a new second". Scheduling tasks like this is also very flexible - changing the timing from "once a second" to "five times a second" is merely adding 0.2 instead of 1 to the next scheduled time instead of having to concoct a formula to detect the boundary condition.

## It makes more sense to anchor logs from the bottom than the top

It was a bit of a duh moment when I realized this. Usually the most interesting logs are the most recent, and those are near the bottom of the logs. Rendering the logs to go up into the sky instead of into the earth makes them much more useful.