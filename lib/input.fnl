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

;; Handling built-in inputs
(fn update-grip-state [device-name]
  (let [hand (. store.input device-name)]
    (when (lovr.headset.wasPressed device-name :grip)
      (let [nearby-blocks (icollect [_ block (ipairs store.blocks)]
                                    (when (< (: (- hand.position block.position) :length) 0.1) block))
            nearest-block (. nearby-blocks 1)]
        (set hand.contents nearest-block))) 
    (when (lovr.headset.wasReleased device-name :grip)
      (tset store.input device-name :contents nil))))

(fn input.update-controller-state [device-name]
  (let [device (. store.input device-name)
        is-tracked (lovr.headset.isTracked device-name)]
    ; Save off previous virtual d-pad state
    (each [key-name is-pressed (pairs device.d-pad)]
          (tset device.previous.d-pad key-name is-pressed))
    ; Update tracking state and position
    (set device.is-tracked is-tracked)
    (when is-tracked
      (set device.was-tracked true)
      (device.position:set (lovr.headset.getPosition device-name))
      (device.rotation:set (lovr.headset.getOrientation device-name)))
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

input