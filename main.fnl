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
         :position (lovr.math.newVec3)
         :contents nil})

(fn d-pad-was-pressed [device-name button]
  (let [device (. store.input device-name)]
    (and (. device.d-pad button) (not (. device.previous.d-pad button)))))

(fn d-pad-was-released [device-name button]
  (let [device (. store.input device-name)]
    (and (not (. device.d-pad button)) (. device.previous.d-pad button))))

(fn wrap [index size]
  (+ 1 (% (- index 1) size)))

(lambda new-block [x y z]
        {:position (lovr.math.newVec3 x y z)})

(global store
        {:input
         {:hand/left (new-hand)
          :hand/right (new-hand)
          :mode :text}
         :logs ""
         :blocks [(new-block 0 1 -0.4)]
         :elapsed {:frames 0 :seconds 0}
         :config
         {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}}})

(var text "")
(local character-list " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")
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
          (string.format "%s {is: %s was: %s stick: %s up: %s down: %s pos: %s contents: %s}"
                         device-name
                         hand.is-tracked
                         hand.was-tracked
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
    (set device.is-tracked is-tracked)
    (when is-tracked
      (set device.was-tracked true)
      (device.position:set (lovr.headset.getPosition device-name)))
    (update-grip-state device-name)
    (device.thumbstick:set (lovr.headset.getAxis device-name :thumbstick))
    (set device.d-pad.down (< device.thumbstick.y -0.6))
    (set device.d-pad.up (< 0.6 device.thumbstick.y))
    (each [_ direction (ipairs device.pressed)]
          (when (d-pad-was-pressed device-name direction)
            (tset device.pressed direction store.elapsed.seconds)))))

(fn update-grabbed-position [device-name]
  (let [device (. store.input device-name)]
    (when device.contents (device.contents.position:set device.position))))

(fn update-text-input []
  (when (lovr.headset.wasPressed :hand/right :a)
    (set text (.. text (character-list:sub current-character current-character))))
  (when (lovr.headset.wasPressed :hand/right :b)
    (set text (text:sub 1 -2)))
  (when (d-pad-was-pressed :hand/left :down)
    (log :debug :input (.. "current char " current-character "/" (length character-list)))
    (set current-character (wrap (+ 1 current-character) (length character-list))))
  (when (d-pad-was-pressed :hand/left :up)
    (log :debug :input (.. "current char " current-character "/" (length character-list)))
    (set current-character (wrap (- current-character 1) (length character-list)))))

(fn lovr.load []
  (log :info :config (.. "Headset refresh rate: " store.config.headset.refresh-rate-hz)))

(fn lovr.update [dt]
  (set store.elapsed.seconds (+ store.elapsed.seconds dt))
  (update-controller-state :hand/left)
  (update-controller-state :hand/right)
  (when (lovr.headset.wasPressed :hand/left :x)
    (add-block (new-block (lovr.headset.getPosition :hand/left))))
  (update-grabbed-position :hand/left)
  (update-grabbed-position :hand/right)
  (update-text-input))

(fn lovr.draw []
  ; Update frame count
  (set store.elapsed.frames (+ 1 store.elapsed.frames))
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
  (lovr.graphics.print (.. text (character-list:sub current-character current-character)) 0 1 -0.5 0.05))