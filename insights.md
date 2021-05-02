# Insights

This file documents things I learned that may not have been obvious when first starting with VR development while working on Form From Functions.

## Scheduling recurring tasks for a future time is easier than waiting for edge change

For example, it's a lot easier to say "when it's past this time, run this logic and update the time to wait for" than it is to keep the last time and try to detect a transition like "it is a new second". Scheduling tasks like this is also very flexible - changing the timing from "once a second" to "five times a second" is merely adding 0.2 instead of 1 to the next scheduled time instead of having to concoct a formula to detect the boundary condition.

## It makes more sense to anchor logs from the bottom than the top

It was a bit of a duh moment when I realized this. Usually the most interesting logs are the most recent, and those are near the bottom of the logs. Rendering the logs to go up into the sky instead of into the earth makes them much more useful.

## Avoid doing things that prevent the framework from batching draw calls

When I started making a larger program within VR, I noticed significant slowdowns after creating about 70 blocks. It seemed like that should be way too few to cause problems, considering all the crazy rendering full games can get away with when I was drawing little more than some boxes, lines, and text. It turns out that drawing each block, which consists of a box, some text, and a line to link it to the next box, individually was interfering with LOVR's built in batching abilities.

According to bjornbytes in the LOVR Slack channel,
> [LOVR] does try to reorder those to batch them together but it has a few limits, in particular lines/prints can't be moved around since they append to a buffer, and blending (required for text) limits the way things can be reordered

Batching it so that all boxes are drawn, then all links, then all text reduced the number of draw calls from 207 to 5 and the number of shader switches from 140 to 2, bringing the performance of the app back up to a comfy 72Hz on my headset.