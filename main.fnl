; In order to get the very basic system working, these are the things that are needed:
; - Hands
; - Blocks
; - Snapping blocks together
; Then, after that
; - Some form of typing (maybe using pre-made labels for known values or a simple floating keyboard?)
; - A variable dictionary, potentially using generated names/colors

(local app (require :src/form-from-functions))

(fn lovr.load []
  (when app.load (app.load)))

(fn lovr.update [dt]
  (when app.update (app.update dt)))

(fn lovr.draw []
  (when app.draw (app.draw)))