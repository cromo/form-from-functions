;; This code may be a bit broken; it was originally used for the arcade text
;; input, but that fell by the wayside when the disk input was written.

(local virtual-d-pad {})

(local repeat-delay-seconds 0.7)
(local repeat-period-seconds 0.05)

(fn virtual-d-pad.init [device-name]
  {:name device-name
   :elapsed-seconds 0
   :current {:up false :down false}
   :previous {:up  false :down false}
   :next-repeat {:up -1 :down -1}
   :repeated {:up false :down false}})

(fn d-pad-was-pressed [self button]
  (and (. self.current button) (not (. self.previous button))))

(fn d-pad-was-repeated [self button]
  (. self.repeated button))

(fn virtual-d-pad.d-pad-was-pressed-or-repeated [self button]
  (or (d-pad-was-pressed self button)
      (d-pad-was-repeated self button)))

(fn d-pad-is-down [self button]
  (. self.current button))

(fn d-pad-was-released [self button]
  (and (not (. self.current button)) (. self.previous button)))

(fn virtual-d-pad.update [self dt]
  (set self.elapsed-seconds (+ self.elapsed-seconds dt))
  ; Save off previous virtual d-pad state
  (each [key-name is-pressed (pairs self.current)]
        (tset self.previous key-name is-pressed))
  (let [(x y) (lovr.headset.getAxis self.name :thumbstick)]
    (set self.current.down (< y -0.6))
    (set self.current.up (< 0.6 y)))
  (each [direction _ (pairs self.current)]
        (tset self.repeated direction false)
        (when (d-pad-was-pressed self direction)
          (tset self.next-repeat direction (+ self.elapsed-seconds repeat-delay-seconds)))
        (when (and (d-pad-is-down self direction) (< (. self.next-repeat direction) self.elapsed-seconds))
          (tset self.repeated direction true)
          (tset self.next-repeat direction (+ (. self.next-repeat direction) repeat-period-seconds)))))

virtual-d-pad