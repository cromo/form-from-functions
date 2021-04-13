(local fff (require :src/development-environment))

(local bootstrap {})
(var state nil)

(fn bootstrap.load []
  (set state (fff.init)))

(fn bootstrap.update [dt]
  (fff.update state dt))

(fn bootstrap.draw []
  (fff.draw state))

bootstrap