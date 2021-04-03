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
(local {: format-hand : draw-hand} (require :lib/hand))
(local {: update-controller-state} (require :lib/input))
(local log (require :lib/logging))

(require :src/store)

(local form-from-functions {})

(local text-input (logging-breaker.init disk-text-input))

(fn update-grabbed-position [device-name]
  (let [device (. store.input device-name)]
    (when device.contents
      (device.contents.position:set device.position)
      (device.contents.rotation:set device.rotation))))

(fn form-from-functions.load []
  (log.info :config (.. "Headset refresh rate: " store.config.headset.refresh-rate-hz))
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (when (lovr.filesystem.isFile :blocks.json)
    (set store.blocks (deserialize-blocks (lovr.filesystem.read :blocks.json)))))

(fn form-from-functions.update [dt]
  (elapsed-time.update store.elapsed dt)
  (update-controller-state :hand/left)
  (update-controller-state :hand/right)
  (when (lovr.headset.wasPressed :hand/left :y)
    (if store.input.hand/left.contents
      (do (set store.input.mode :textual)
          (set store.input.text-focus store.input.hand/left.contents)
          (set store.input.hand/left.contents nil))
      store.input.text-focus
      (do (set store.input.mode :physical)
          (set store.input.text-focus nil))))
  (when (= store.input.mode :physical)
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
    (update-grabbed-position :hand/left)
    (update-grabbed-position :hand/right))
  ; Process linking blocks
  (when (and (or (lovr.headset.wasPressed :hand/left :trigger)
                 (lovr.headset.wasPressed :hand/right :trigger))
             store.input.hand/left.contents
             store.input.hand/right.contents)
    (if store.input.hand/left.contents.next
      (set store.input.hand/left.contents.next nil)
      (set store.input.hand/left.contents.next store.input.hand/right.contents)))
  (when (= store.input.mode :textual)
    (logging-breaker.update text-input store.input.text-focus)))

(fn form-from-functions.draw []
  (elapsed-time.draw store.elapsed)
  (log.draw store.logs)
  (lovr.graphics.print (.. (format-hand :hand/left) "\n    " (format-hand :hand/right)) -0.03 1.3 -2 0.1)
  (each [_ hand (pairs [:hand/left :hand/right])]
        (draw-hand (. store.input hand)))
  (each [i block (ipairs store.blocks)]
        (draw-block block))
  (logging-breaker.draw text-input))

form-from-functions