; In order to get the very basic system working, these are the things that are needed:
; - Hands
; - Blocks
; - Snapping blocks together
; Then, after that
; - Some form of typing (maybe using pre-made labels for known values or a simple floating keyboard?)
; - A variable dictionary, potentially using generated names/colors

(lambda new-hand []
        {:was-tracked false
         :is-tracked false
         :thumbstick (lovr.math.newVec2)
         :d-pad {:up false :down false}
         :previous {:d-pad {:up  false :down false}}
         :pressed {:up 0 :down 0}
         :next-repeat {:up -1 :down -1}
         :repeated {:up false :down false}
         :position (lovr.math.newVec3)
         :contents nil})

(fn d-pad-was-pressed [device-name button]
  (let [device (. store.input device-name)]
    (and (. device.d-pad button) (not (. device.previous.d-pad button)))))

(fn d-pad-was-repeated [device-name button]
  (. store.input device-name :repeated button))

(fn d-pad-was-pressed-or-repeated [device-name button]
  (or (d-pad-was-pressed device-name button)
      (d-pad-was-repeated device-name button)))

(fn d-pad-is-down [device-name button]
  (. store.input device-name :d-pad button))

(fn d-pad-was-released [device-name button]
  (let [device (. store.input device-name)]
    (and (not (. device.d-pad button)) (. device.previous.d-pad button))))

(fn wrap [index size]
  (+ 1 (% (- index 1) size)))

(lambda new-block [x y z]
        {:position (lovr.math.newVec3 x y z)
         :text ""})

(global store
        {:input
         {:hand/left (new-hand)
          :hand/right (new-hand)
          :text-index 1
          :mode :physical
          :text-focus nil}
         :logs ""
         :blocks [(new-block 0 1 -0.4)]
         :elapsed {:frames 0 :seconds 0}
         :config
         {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}
          :repeat {:delay 0.7 :hz 0.05}
          :character-list " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"}})

(fn log [level tag message]
  (set store.logs (.. store.logs "\n" level " " tag " " message)))

(lambda add-block [block]
        (table.insert store.blocks block))

(lambda format-vec2 [vec]
        (string.format "(vec2 %.2f, %.2f)" (vec:unpack)))

(lambda format-vec3 [vec]
        (string.format "(vec3 %.2f, %.2f, %.2f)" (vec:unpack)))

(lambda format-hand [device-name]
        (let [hand (. store.input device-name)]
          (string.format "%s {is: %s was: %s pressed: {up: %.2f down: %.2f} stick: %s up: %s down: %s pos: %s contents: %s}"
                         device-name
                         hand.is-tracked
                         hand.was-tracked
                         hand.pressed.up
                         hand.pressed.down
                         (format-vec2 hand.thumbstick)
                         (tostring hand.d-pad.up)
                         (tostring hand.d-pad.down)
                         (format-vec3 hand.position)
                         (not (not hand.contents)))))

(fn update-grip-state [device-name]
  (let [hand (. store.input device-name)]
    (when (lovr.headset.wasPressed device-name :grip)
      (let [nearby-blocks (icollect [_ block (ipairs store.blocks)]
                                    (when (< (: (- hand.position block.position) :length) 0.1) block))
            nearest-block (. nearby-blocks 1)]
        (set hand.contents nearest-block))) 
    (when (lovr.headset.wasReleased device-name :grip)
      (tset store.input device-name :contents nil))))

(fn update-controller-state [device-name]
  (let [device (. store.input device-name)
        is-tracked (lovr.headset.isTracked device-name)]
    ; Save off previous virtual d-pad state
    (each [key-name is-pressed (pairs device.d-pad)]
          (tset device.previous.d-pad key-name is-pressed))
    ; Update tracking state and position
    (set device.is-tracked is-tracked)
    (when is-tracked
      (set device.was-tracked true)
      (device.position:set (lovr.headset.getPosition device-name)))
    ; Process grabbing things
    (update-grip-state device-name)
    ; Process thumbsticks and virtual d-pad
    (device.thumbstick:set (lovr.headset.getAxis device-name :thumbstick))
    (set device.d-pad.down (< device.thumbstick.y -0.6))
    (set device.d-pad.up (< 0.6 device.thumbstick.y))
    (each [direction _ (pairs device.pressed)]
          (tset device.repeated direction false)
          (when (d-pad-was-pressed device-name direction)
            (tset device.pressed direction store.elapsed.seconds)
            (tset device.next-repeat direction (+ store.elapsed.seconds store.config.repeat.delay)))
          (when (and (d-pad-is-down device-name direction) (< (. device.next-repeat direction) store.elapsed.seconds))
            (tset device.repeated direction true)
            (tset device.next-repeat direction (+ (. device.next-repeat direction) store.config.repeat.hz))))))

(fn update-grabbed-position [device-name]
  (let [device (. store.input device-name)]
    (when device.contents (device.contents.position:set device.position))))

(fn update-text-input [container]
  (let [{: input :config {: character-list}} store] 
    (when (lovr.headset.wasPressed :hand/right :a)
      (set container.text (.. container.text (character-list:sub input.text-index input.text-index)))) 
    (when (lovr.headset.wasPressed :hand/right :b)
      (set container.text (container.text:sub 1 -2))) 
    (when (d-pad-was-pressed-or-repeated :hand/left :down)
      (set input.text-index (wrap (+ 1 input.text-index) (length character-list)))) 
    (when (d-pad-was-pressed-or-repeated :hand/left :up)
      (set input.text-index (wrap (- input.text-index 1) (length character-list))))))

(fn generate-code [blocks]
  (let [tokens {}]
    (fn gather-next [block]
      (table.insert tokens block.text)
      (if block.next (gather-next block.next)))
    (gather-next (. blocks 1))
    (table.concat tokens " ")))

(fn lovr.load []
  (log :info :config (.. "Headset refresh rate: " store.config.headset.refresh-rate-hz))
  (log :info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory))))

(fn lovr.update [dt]
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
      (log :debug :codegen (generate-code store.blocks)))
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

(fn lovr.draw []
  ; Update frame count
  (set store.elapsed.frames (+ 1 store.elapsed.frames))
  ; Draw logs
  (lovr.graphics.print store.logs 0 1.5 -3 0.1 0 0 1 0 0 :center :top)
  ; Draw hands
  (var hands-drawn 0)
  (lovr.graphics.print (.. (format-hand :hand/left) "\n    " (format-hand :hand/right)) -0.03 1.55 -2 0.1)
  (each [_ hand (pairs [:hand/left :hand/right])]
        (let [{: was-tracked : is-tracked : position} (. store.input hand)] 
          (when was-tracked
            (if (not is-tracked) (lovr.graphics.setColor 0.2 0.2 0.2 0.8))
            (lovr.graphics.sphere position 0.03)
            (lovr.graphics.print hand position 0.1)
            (if (not is-tracked) (lovr.graphics.setColor 1 1 1))
            (set hands-drawn (+ 1 hands-drawn)))))
  (lovr.graphics.print (.. "hands drawn: " hands-drawn) -0.1 1.7 -1 0.1)
  ; Draw blocks
  (each [i block (ipairs store.blocks)]
        (lovr.graphics.box :line block.position 0.1 0.1 0.1)
        (lovr.graphics.print block.text block.position 0.0254)
        (when block.next (lovr.graphics.line block.position block.next.position)))
  ; Draw text input
  (lovr.graphics.print (store.config.character-list:sub store.input.text-index store.input.text-index) 0 1 -0.5 0.05))