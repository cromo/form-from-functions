(local elapsed-time {})

(fn elapsed-time.init []
  {:seconds 0 :frames 0})

(fn elapsed-time.update [state dt]
  (set state.seconds (+ state.seconds dt)))

(fn elapsed-time.draw [state]
  (set state.frames (+ 1 state.frames)))

elapsed-time