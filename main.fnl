; In order to get the very basic system working, these are the things that are needed:
; - Hands
; - Blocks
; - Snapping blocks together
; Then, after that
; - Some form of typing (maybe using pre-made labels for known values or a simple floating keyboard?)
; - A variable dictionary, potentially using generated names/colors

(lambda new-block [x y z]
        {:position (lovr.math.newVec3 x y z)})

(global store
        {:input
         {:hand/left {:was-tracked false
                      :is-tracked false
                      :thumbstick (lovr.math.newVec2)
                      :position (lovr.math.newVec3)
                      :contents nil}
          :hand/right {:was-tracked false
                       :is-tracked false
                       :thumbstick (lovr.math.newVec2)
                       :position (lovr.math.newVec3)
                       :contents nil}
          :mode :text}
         :logs ""
         :blocks [(new-block 0 1 -0.4)]
         :time {:frames-since-launch 0}
         :config
         {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}}})

(var text "")
(local character-list "ABC")
(var current-character 1)

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
          (string.format "%s {is: %s was: %s stick: %s pos: %s contents: %s}"
                         device-name
                         hand.is-tracked
                         hand.was-tracked
                         (format-vec2 hand.thumbstick)
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
    (set device.is-tracked is-tracked)
    (when is-tracked
      (set device.was-tracked true)
      (device.position:set (lovr.headset.getPosition device-name)))
    (update-grip-state device-name)
    (device.thumbstick:set (lovr.headset.getAxis device-name :thumbstick))))

(fn update-grabbed-position [device-name]
  (let [device (. store.input device-name)]
    (when device.contents (device.contents.position:set device.position))))

(fn update-text-input []
  (when (lovr.headset.wasPressed :hand/right :a)
    (set text (.. text (character-list:sub current-character current-character))))
  (when (lovr.headset.wasPressed :hand/right :b)
    (set text (text:sub 1 -2))))

(fn lovr.load []
  (log :info :config (.. "Headset refresh rate: " store.config.headset.refresh-rate-hz)))

(fn lovr.update [dt]
  (update-controller-state :hand/left)
  (update-controller-state :hand/right)
  (when (lovr.headset.wasPressed :hand/left :x)
    (add-block (new-block (lovr.headset.getPosition :hand/left))))
  (update-grabbed-position :hand/left)
  (update-grabbed-position :hand/right)
  (update-text-input))

(fn lovr.draw []
  ; Update frame count
  (set store.time.frames-since-launch
       (+ 1 store.time.frames-since-launch))
  ; Draw logs
  (lovr.graphics.print store.logs 0 1.5 -3 0.1 0 0 1 0 0 :center :top)
  ; Draw hands
  (var hands-drawn 0)
  (lovr.graphics.print (.. (format-hand :hand/left) "\n    " (format-hand :hand/right)) -0.03 1.55 -2 0.1)
  (each [hand {: was-tracked : is-tracked : position} (pairs store.input)]
        (when was-tracked
          (if (not is-tracked) (lovr.graphics.setColor 0.2 0.2 0.2 0.8))
          (lovr.graphics.sphere position 0.03)
          (lovr.graphics.print hand position 0.1)
          (if (not is-tracked) (lovr.graphics.setColor 1 1 1))
          (set hands-drawn (+ 1 hands-drawn))))
  (lovr.graphics.print (.. "hands drawn: " hands-drawn) -0.1 1.7 -1 0.1)
  ; Draw blocks
  (each [i block (ipairs store.blocks)]
        (lovr.graphics.box :line block.position 0.1 0.1 0.1))
  ; Draw text input
  (lovr.graphics.print (.. text (character-list:sub 1 1)) 0 1 -0.5 0.05)
  (lovr.graphics.print (tostring (select 2 (lovr.headset.getAxis :hand/left :thumbstick))) 0 0.9 -0.5 0.05))