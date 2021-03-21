(local app (require :src/form-from-functions))

(fn lovr.load []
  (when app.load (app.load)))

(fn lovr.update [dt]
  (when app.update (app.update dt)))

(fn lovr.draw []
  (when app.draw (app.draw)))