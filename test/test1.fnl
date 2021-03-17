(local T (require :third-party/knife-test))

(T "Given a value of 1"
   (fn [T]
     (var value 1)
     (T "When incremented by 1"
        (fn [T]
          (set value (+ 1 value))
          (T:assert (= value 2) "Then the value is equal to 2")))))