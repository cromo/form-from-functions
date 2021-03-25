(local fennel (require :third-party/fennel))

(local {: update-text-input} (require :lib/arcade-text-input))
(local {: new-block
        : add-block} (require :lib/block))
(local {: generate-code} (require :lib/code-gen))
(local {: format-hand : draw-hand} (require :lib/hand))
(local {: update-controller-state} (require :lib/input))
(local {: log} (require :lib/logging))

(require :src/store)

(local form-from-functions {})

(fn update-grabbed-position [device-name]
  (let [device (. store.input device-name)]
    (when device.contents (device.contents.position:set device.position))))

(fn form-from-functions.load []
  (log :info :config (.. "Headset refresh rate: " store.config.headset.refresh-rate-hz))
  (log :info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory))))

(fn form-from-functions.update [dt]
  (set store.elapsed.seconds (+ store.elapsed.seconds dt))
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
      (log :debug :codegen (generate-code store.blocks))
      (fennel.eval (generate-code store.blocks)))
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
    (update-text-input store.input.text-focus)))

(fn form-from-functions.draw []
  ; Update frame count
  (set store.elapsed.frames (+ 1 store.elapsed.frames))
  ; Draw logs
  (lovr.graphics.print store.logs 0 1.5 -3 0.1 0 0 1 0 0 :center :top)
  ; Draw hands
  (lovr.graphics.print (.. (format-hand :hand/left) "\n    " (format-hand :hand/right)) -0.03 1.55 -2 0.1)
  (each [_ hand (pairs [:hand/left :hand/right])]
        (draw-hand (. store.input hand)))
  ; Draw blocks
  (each [i block (ipairs store.blocks)]
        (lovr.graphics.box :line block.position 0.1 0.1 0.1)
        (lovr.graphics.print block.text block.position 0.0254)
        (when block.next (lovr.graphics.line block.position block.next.position)))
  ; Draw text input
  (lovr.graphics.print (store.config.character-list:sub store.input.text-index store.input.text-index) 0 1 -0.5 0.05))

form-from-functions