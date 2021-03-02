; In order to get the very basic system working, these are the things that are needed:
; - Hands
; - Blocks
; - Snapping blocks together
; Then, after that
; - Some form of typing (maybe using pre-made labels for known values or a simple floating keyboard?)
; - A variable dictionary, potentially using generated names/colors

(global boxes [{:x 0 :y 1 :z -0.3}])

(fn lovr.update [dt])

(fn lovr.draw []
  (lovr.graphics.print (.. "hello" "fennel" (lovr.headset.getDriver)) 0 1.7 -3 0.5)
  (each [i hand (ipairs (lovr.headset.getHands))]
        (let [(x y z) (lovr.headset.getPosition hand)]
          (lovr.graphics.sphere x y z 0.03)))
  (each [i {: x : y : z} (ipairs boxes)]
        (lovr.graphics.box :line x y z 0.1 0.1 0.1)))