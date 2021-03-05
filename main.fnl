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
                        :position (lovr.math.newVec3)}}
          :logs ""
          :blocks [(new-block 0 1 -0.4)]
          :time {:frames-since-launch 0}}
         :config
         {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}}})

(fn log [level tag message]
  (set environment.state.logs (.. environment.state.logs "\n" level " " tag " " message)))

(lambda add-box [box]
        (table.insert environment.state.blocks box))

(lambda format-vec3 [vec]
        (string.format "(vec3 %.2f, %.2f, %.2f)" (vec:unpack)))

(fn update-controller-state [device-name]
  (let [device (. environment.state.input device-name)
        is-tracked (lovr.headset.isTracked device-name)]
    (set device.is-tracked is-tracked)
    (when is-tracked
      (set device.was-tracked true)
      (device.position:set (lovr.headset.getPosition device-name)))))

(fn lovr.load []
  (log :info :config (.. "Headset refresh rate: " environment.config.headset.refresh-rate-hz)))

(fn lovr.update [dt]
  (update-controller-state :hand/left)
  (update-controller-state :hand/right)
  (when (lovr.headset.wasPressed :hand/left :x)
    (add-box (new-block (lovr.headset.getPosition :hand/left))))
  (when (lovr.headset.wasPressed :hand/left :grip)
    (let [hand environment.state.input.hand/left.position
          nearby-boxes (icollect [_ box (ipairs environment.state.blocks)]
                                 (when (< (: (- hand box) :length) 0.1) box))
          nearest-box (. nearby-boxes 1)]
      (log :info :physics
           (.. "boxes " (length nearby-boxes)
               " nearest " (tostring nearest-box)))
      (set environment.state.input.hand/left.grabbed nearest-box)))
  (when (lovr.headset.wasReleased :hand/left :grip)
    (set environment.state.input.hand/left.grabbed nil))
  (when environment.state.input.hand/left.grabbed
    (environment.state.input.hand/left.grabbed:set environment.state.input.hand/left.position)))

(fn lovr.draw []
  (set environment.state.time.frames-since-launch
       (+ 1 environment.state.time.frames-since-launch))
  (lovr.graphics.print environment.state.logs 0 1.5 -3 0.1 0 0 1 0 0 :center :top)
  (each [hand {: was-tracked : is-tracked : position} (pairs environment.state.input)]
        (when was-tracked
          (if (not is-tracked) (lovr.graphics.setColor 0.2 0.2 0.2 0.8))
          (lovr.graphics.sphere position 0.03)
          (if (not is-tracked) (lovr.graphics.setColor 1 1 1))))
  (each [i position (ipairs environment.state.blocks)]
        (lovr.graphics.box :line position 0.1 0.1 0.1)))