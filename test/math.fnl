(local {: wrap} (require :lib/math))

(T "When wrapping an index in a table"
   (fn [T]
     (let [t [7 8 9]]
       (T "when the index is zero"
          (fn [T]
            (T:assert (= (wrap 0 (length t)) (length t)) "should be the last index")))
       (T "when the index is one more than the length"
          (fn [T]
            (T:assert (= (wrap (+ 1 (length t)) (length t)) 1) "should be the first index"))))))