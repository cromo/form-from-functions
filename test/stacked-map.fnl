(local stacked-map (require :lib/stacked-map))

(T "A stacked map"
   (fn [T]
     (local sm (stacked-map.new))
     (T "when pushing an item"
        (fn [T]
          (T "should add it if that key doesn't exist"
             (fn [T]
               (stacked-map.push sm :key 23)
               (T:assert (= (length sm) 1) "but the size didn't increase")
               (T:assert (= (stacked-map.top sm) 23) "but it wasn't put on top")))
          (T "that uses an existing key"
             (fn [T]
               (T "should replace it"
                  (fn [T]
                    (stacked-map.push sm :key 3)
                    (stacked-map.push sm :key 14)
                    (T:assert (= (length sm) 1) "but the size changed")
                    (T:assert (= (stacked-map.top sm) 14) "but the top value wasn't changed")))
               (T "should bring it to the top"
                  (fn [T]
                    (stacked-map.push sm :a 15)
                    (stacked-map.push sm :b 9)
                    (stacked-map.push sm :a 26)
                    (T:assert (= (length sm) 2) "but the size changed")
                    (T:assert (= (stacked-map.top sm) 26) "but the top value wasn't changed")))))))
     (T "when popping an item"
        (fn [T]
          (T "should do nothing when empty"
             (fn [T]
               (stacked-map.pop sm)))
          (T "should remove the top item if no key is specified"
             (fn [T]
               (stacked-map.push sm :a 5)
               (stacked-map.push sm :b 35)
               (stacked-map.pop sm)
               (T:assert (= (length sm) 1) "but the size didn't change as expected")
               (T:assert (= (stacked-map.top sm) 5) "but the top item wasn't removed")))
          (T "should remove the named item if a key is specified"
             (fn [T]
               (stacked-map.push sm :a 89)
               (stacked-map.push sm :b 79)
               (stacked-map.pop sm :a)
               (T:assert (= (length sm) 1) "but the size didn't change")
               (T:assert (= (stacked-map.top sm) 79) "but the top item was altered")))
          (T "should return the popped value"
             (fn [T]
               (stacked-map.push sm :a 3)
               (T:assert (= (stacked-map.pop sm) 3) "but it was something else")))))
     (T "should remove all items when cleared"
        (fn [T]
          (stacked-map.push sm :a 4)
          (stacked-map.push sm :b 8)
          (stacked-map.push sm :c 15)
          (stacked-map.push sm :d 16)
          (stacked-map.push sm :e 23)
          (stacked-map.push sm :f 42)
          (stacked-map.clear sm)
          (T:assert (= (length sm) 0) "but it didn't")))))