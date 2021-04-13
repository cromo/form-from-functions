(local app (require :src/bootstrap))

(fn lovr.load []
  (when app.load (app.load)))

(fn lovr.update [dt]
  (when app.update (app.update dt)))

(fn lovr.draw []
  (when app.draw (app.draw)))