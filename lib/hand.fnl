(local {: format-vec2
        : format-vec3}
       (require :lib/math))

(local hand {})

(lambda hand.new-hand []
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

(lambda hand.format-hand [device-name]
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

hand