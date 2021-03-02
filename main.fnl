; In order to get the very basic system working, these are the things that are needed:
; - Hands
; - Blocks
; - Snapping blocks together
; Then, after that
; - Some form of typing (maybe using pre-made labels for known values or a simple floating keyboard?)
; - A variable dictionary, potentially using generated names/colors

(global envronment
        {:state {:input
                 {:hand/left {:was-tracked false
                              :is-tracked false
                              :position (lovr.math.newVec3)}
                  :hand/right {:was-tracked false
                               :is-tracked false
                               :position (lovr.math.newVec3)}}}})
(global boxes [{:x 0 :y 1 :z -0.3}])

(fn update-controller-state [device-name]
  (let [device (. envronment.state.input device-name)
        is-tracked (lovr.headset.isTracked device-name)]
    (set device.is-tracked is-tracked)
    (when is-tracked
      (set device.was-tracked true)
      (device.position:set (lovr.headset.getPosition device-name)))))

(fn lovr.update [dt]
  (update-controller-state :hand/left)
  (update-controller-state :hand/right))

(fn lovr.draw []
  (lovr.graphics.print (.. "hello" "fennel" (lovr.headset.getDriver)) 0 1.7 -3 0.5)
  (each [hand {: was-tracked : is-tracked : position} (pairs envronment.state.input)]
        (when was-tracked
          (if (not is-tracked) (lovr.graphics.setColor 0.2 0.2 0.2 0.8))
          (lovr.graphics.sphere position 0.03)
          (if (not is-tracked) (lovr.graphics.setColor 1 1 1))))
  (each [i {: x : y : z} (ipairs boxes)]
        (lovr.graphics.box :line x y z 0.1 0.1 0.1)))