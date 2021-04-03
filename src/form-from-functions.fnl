(local fennel (require :third-party/fennel))

(local logging-breaker (require :lib/logging-breaker))
(local text-input (require :lib/disk-text-input))
(local block (require :lib/block))
(local blocks (require :lib/blocks))
(local {: generate-code} (require :lib/code-gen))
(local elapsed-time (require :lib/elapsed-time))
(local hand (require :lib/hand))
(local log (require :lib/logging))

(local store
       {:input
        {:hand/left (hand.init :hand/left)
         :hand/right (hand.init :hand/right)
         :mode :physical
         :text-focus nil}
        :blocks (blocks.init)
        :text-input (text-input.init)
        :elapsed (elapsed-time.init)
        :config
        {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}}})

(local form-from-functions {})

(local text-input (logging-breaker.init text-input))

(fn form-from-functions.load []
  (log.info :config (.. "Headset refresh rate: " store.config.headset.refresh-rate-hz))
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (when (lovr.filesystem.isFile :blocks.json)
    (set store.blocks (blocks.deserialize (lovr.filesystem.read :blocks.json)))))

(fn grab-nearby-block-if-able [hand blocks]
  (let [nearby-blocks (icollect [_ block (ipairs store.blocks)]
                                (when (< (: (- hand.position block.position) :length) 0.1) block))
        nearest-block (. nearby-blocks 1)]
    (set hand.contents nearest-block)))

(fn physical-update [dt]
  (when (lovr.headset.wasPressed :hand/right :a)
    (xpcall
     (fn [] (fennel.eval (generate-code store.blocks)))
     (fn [error]
       (log.error :codegen error))))
  (when (lovr.headset.wasPressed :hand/right :b)
    (let [serialized-blocks (blocks.serialize store.blocks)]
      (lovr.filesystem.write "blocks.json" serialized-blocks)))
  (when (lovr.headset.wasPressed :hand/left :x)
    (blocks.add store.blocks (block.init (lovr.headset.getPosition :hand/left))))
  (when (and (or (lovr.headset.wasPressed :hand/left :trigger)
                 (lovr.headset.wasPressed :hand/right :trigger))
             store.input.hand/left.contents
             store.input.hand/right.contents)
    (block.link store.input.hand/left.contents store.input.hand/right.contents))
  (each [_ hand-name (pairs [:hand/left :hand/right])]
        (when (lovr.headset.wasPressed hand-name :grip)
          (grab-nearby-block-if-able (. store.input hand-name) store.blocks))
        (when (lovr.headset.wasReleased hand-name :grip)
          (tset store.input hand-name :contents nil)))
  (if (and (lovr.headset.wasPressed :hand/left :y)
           store.input.hand/left.contents)
    (do (set store.input.text-focus store.input.hand/left.contents)
        (set store.input.hand/left.contents nil)
        :textual)
    :physical))

(fn textual-update [dt]
  (logging-breaker.update text-input dt store.input.text-focus)
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
  (log.draw)
  (lovr.graphics.print
   (.. (hand.format store.input.hand/left) "\n    "
       (hand.format store.input.hand/right))
   -0.03 1.3 -2 0.1)
  (each [_ hand-name (pairs [:hand/left :hand/right])]
        (hand.draw (. store.input hand-name)))
  (blocks.draw store.blocks)
  (logging-breaker.draw text-input))

form-from-functions