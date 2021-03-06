; In order to get the very basic system working, these are the things that are needed:
; - Hands
; - Blocks
; - Snapping blocks together
; Then, after that
; - Some form of typing (maybe using pre-made labels for known values or a simple floating keyboard?)
; - A variable dictionary, potentially using generated names/colors

(lambda new-block [x y z]
        (lovr.math.newVec3 x y z))

(global environment
        {:state
         {:input
          {:hand/left {:was-tracked false
                       :is-tracked false
                       :position (lovr.math.newVec3)
                       :grabbed nil}
           :hand/right {:was-tracked false
                        :is-tracked false
                        :position (lovr.math.newVec3)
                        :grabbed nil}}
          :logs ""
          :blocks [(new-block 0 1 -0.4)]
          :time {:frames-since-launch 0}}
         :config
         {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}}})

(fn log [level tag message]
  (set environment.state.logs (.. environment.state.logs "\n" level " " tag " " message)))

(lambda add-block [block]
        (table.insert environment.state.blocks block))

(lambda format-vec3 [vec]
        (string.format "(vec3 %.2f, %.2f, %.2f)" (vec:unpack)))

(lambda format-hand [device-name]
        (let [hand (. environment.state.input device-name)]
          (string.format "%s {is: %s was: %s pos: %s grabbed: %s}"
                         device-name
                         hand.is-tracked
                         hand.was-tracked
                         (format-vec3 hand.position)
                         (not (not hand.grabbed)))))

(fn update-grip-state [device-name]
  (let [hand (. environment.state.input device-name)]
    (when (lovr.headset.wasPressed device-name :grip)
      (let [nearby-blocks (icollect [_ block (ipairs environment.state.blocks)]
                                    (when (< (: (- hand.position block) :length) 0.1) block))
            nearest-block (. nearby-blocks 1)]
        (set hand.grabbed nearest-block))) 
    (when (lovr.headset.wasReleased device-name :grip)
      (tset environment.state.input device-name :grabbed nil))))

(fn update-controller-state [device-name]
  (let [device (. environment.state.input device-name)
        is-tracked (lovr.headset.isTracked device-name)]
    (set device.is-tracked is-tracked)
    (when is-tracked
      (set device.was-tracked true)
      (device.position:set (lovr.headset.getPosition device-name)))
    (update-grip-state device-name)
    ))

(fn update-grabbed-position [device-name]
  (let [device (. environment.state.input device-name)]
    (when device.grabbed (device.grabbed:set device.position))))

(fn lovr.load []
  (log :info :config (.. "Headset refresh rate: " environment.config.headset.refresh-rate-hz)))

(fn lovr.update [dt]
  (update-controller-state :hand/left)
  (update-controller-state :hand/right)
  (when (lovr.headset.wasPressed :hand/left :x)
    (add-block (new-block (lovr.headset.getPosition :hand/left))))
  (update-grabbed-position :hand/left)
  (update-grabbed-position :hand/right))

(fn lovr.draw []
  ; Update frame count
  (set environment.state.time.frames-since-launch
       (+ 1 environment.state.time.frames-since-launch))
  ; Draw logs
  (lovr.graphics.print environment.state.logs 0 1.5 -3 0.1 0 0 1 0 0 :center :top)
  ; Draw hands
  (var hands-drawn 0)
  (lovr.graphics.print (.. (format-hand :hand/left) "\n    " (format-hand :hand/right)) -0.03 1.55 -2 0.1)
  (each [hand {: was-tracked : is-tracked : position} (pairs environment.state.input)]
        (when was-tracked
          (if (not is-tracked) (lovr.graphics.setColor 0.2 0.2 0.2 0.8))
          (lovr.graphics.sphere position 0.03)
          (lovr.graphics.print hand position 0.1)
          (if (not is-tracked) (lovr.graphics.setColor 1 1 1))
          (set hands-drawn (+ 1 hands-drawn))))
  (lovr.graphics.print (.. "hands drawn: " hands-drawn) -0.1 1.7 -1 0.1)
  ; Draw blocks
  (each [i position (ipairs environment.state.blocks)]
        (lovr.graphics.box :line position 0.1 0.1 0.1)))