(local elapsed-time {})

(fn elapsed-time.add-seconds [dt]
  (set store.elapsed.seconds (+ store.elapsed.seconds dt)))

(fn elapsed-time.add-frame []
  (set store.elapsed.frames (+ 1 store.elapsed.frames)))

elapsed-time