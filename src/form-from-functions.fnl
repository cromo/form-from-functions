(local fennel (require :third-party/fennel))

(local logging-breaker (require :lib/logging-breaker))
(local disk-text-input (require :lib/disk-text-input))
(local {: new-block
        : add-block
        : draw-block
        : serialize-blocks
        : deserialize-blocks} (require :lib/block))
(local {: generate-code} (require :lib/code-gen))
(local elapsed-time (require :lib/elapsed-time))
(local hand (require :lib/hand))
(local log (require :lib/logging))

(require :src/store)

(local form-from-functions {})

(local text-input (logging-breaker.init disk-text-input))

(fn form-from-functions.load []
  (log.info :config (.. "Headset refresh rate: " store.config.headset.refresh-rate-hz))
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (when (lovr.filesystem.isFile :blocks.json)
    (set store.blocks (deserialize-blocks (lovr.filesystem.read :blocks.json)))))

(fn physical-update [dt]
  (when (lovr.headset.wasPressed :hand/right :a)
    (log.debug :codegen (generate-code store.blocks))
    (xpcall
     (fn [] (fennel.eval (generate-code store.blocks)))
     (fn [error]
       (log.error :codegen error))))
  (when (lovr.headset.wasPressed :hand/right :b)
    (let [serialized-blocks (serialize-blocks store.blocks)]
      (log.debug :persistence serialized-blocks)
      (lovr.filesystem.write "blocks.json" serialized-blocks)))
  (when (lovr.headset.wasPressed :hand/left :x)
    (add-block (new-block (lovr.headset.getPosition :hand/left))))
  (when (and (or (lovr.headset.wasPressed :hand/left :trigger)
                 (lovr.headset.wasPressed :hand/right :trigger))
             store.input.hand/left.contents
             store.input.hand/right.contents)
    (if store.input.hand/left.contents.next
      (set store.input.hand/left.contents.next nil)
      (set store.input.hand/left.contents.next store.input.hand/right.contents)))
  (if (and (lovr.headset.wasPressed :hand/left :y)
           store.input.hand/left.contents)
    (do (set store.input.text-focus store.input.hand/left.contents)
        (set store.input.hand/left.contents nil)
        :textual)
    :physical))

(fn textual-update [dt]
  (logging-breaker.update text-input store.input.text-focus)
  (if (lovr.headset.wasPressed :hand/left :y)
    (do (set store.input.text-focus nil)
        :physical)
    :textual))

(fn form-from-functions.update [dt]
  (elapsed-time.update store.elapsed dt)
  (hand.update store.input.hand/left)
  (hand.update store.input.hand/right)
  (set store.input.mode
       (match store.input.mode
         :physical (physical-update dt)
         :textual (textual-update dt))))

(fn form-from-functions.draw []
  (elapsed-time.draw store.elapsed)
  (log.draw store.logs)
  (lovr.graphics.print
   (.. (hand.format store.input.hand/left) "\n    "
       (hand.format store.input.hand/right))
   -0.03 1.3 -2 0.1)
  (each [_ hand-name (pairs [:hand/left :hand/right])]
        (hand.draw (. store.input hand-name)))
  (each [i block (ipairs store.blocks)]
        (draw-block block))
  (logging-breaker.draw text-input))

form-from-functions