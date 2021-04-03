(local input {})

;; Virtual d-pad handling
;; (this should probably be moved out into its own module)
(fn d-pad-was-pressed [device-name button]
  (let [device (. store.input device-name)]
    (and (. device.d-pad button) (not (. device.previous.d-pad button)))))

(fn d-pad-was-repeated [device-name button]
  (. store.input device-name :repeated button))

(fn input.d-pad-was-pressed-or-repeated [device-name button]
  (or (d-pad-was-pressed device-name button)
      (d-pad-was-repeated device-name button)))

(fn d-pad-is-down [device-name button]
  (. store.input device-name :d-pad button))

(fn d-pad-was-released [device-name button]
  (let [device (. store.input device-name)]
    (and (not (. device.d-pad button)) (. device.previous.d-pad button))))

(fn input.update-virtual-d-pad [device-name]
  (let [device (. store.input device-name)]
    ; Save off previous virtual d-pad state
    (each [key-name is-pressed (pairs device.d-pad)]
          (tset device.previous.d-pad key-name is-pressed))
    ; Process thumbsticks and virtual d-pad
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

input