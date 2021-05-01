(local {: format-vec2
        : format-vec3}
       (require :lib/math))

(local hand {})

(lambda hand.init [name]
        {:name name
         :was-tracked false
         :is-tracked false
         :thumbstick (lovr.math.newVec2)
         :position (lovr.math.newVec3)
         :rotation (lovr.math.newQuat)
         :contents nil})

(lambda hand.format [hand]
        (string.format "%s {is: %s was: %s stick: %s pos: %s contents: %s}"
                       hand.name
                       hand.is-tracked
                       hand.was-tracked
                       (format-vec2 hand.thumbstick)
                       (format-vec3 hand.position)
                       (not (not hand.contents))))

(fn update-tracking [self]
  (let [is-tracked (lovr.headset.isTracked self.name)]
    (set self.is-tracked is-tracked)
    (when is-tracked
      (set self.was-tracked true)
      (self.position:set (lovr.headset.getPosition self.name))
      (self.rotation:set (lovr.headset.getOrientation self.name)))))

(fn update-contents-pose [self]
  (self.contents.position:set self.position)
  (self.contents.rotation:set self.rotation))

(fn hand.update [self]
  (update-tracking self)
  (self.thumbstick:set (lovr.headset.getAxis self.name :thumbstick))
  (when self.contents (update-contents-pose self)))

(fn hand.draw [{: was-tracked : is-tracked : position : name}]
  (when was-tracked
    (let [(x y z) (position:unpack)
          poses (lovr.headset.getSkeleton name)]
      (if (not is-tracked) (lovr.graphics.setColor 0.2 0.2 0.2 0.8))
      (if poses
        (each [i [x y z a rx ry rz] (ipairs poses)]
              (lovr.graphics.print (tostring i) x y z 0.01 a rx ry rz))
        (lovr.graphics.sphere x y z 0.03))
      (if (not is-tracked) (lovr.graphics.setColor 1 1 1)))))

hand