(local selector (require "lib/adapters/selector"))

(T "A selector layer"
   (fn [T]
     (T "when created"
        (fn [T]
          (T "should pass the provided arguments"
             (fn [T]
               (T "to the first layer"
                  (fn [T]
                    (var arg nil)
                    (let [first {:init #(set arg $1)}
                          wrapper (selector.init first [:hey])]
                      (T:assert (= arg :hey) "but it didn't"))))
               (T "to the second layer"
                  (fn [T]
                    (var arg nil)
                    (let [first {:init #nil}
                          second {:init #(set arg $1)}
                          wrapper (selector.init first [] second [:hi])]
                      (T:assert (= arg :hi) "but it didn't"))))))
          (T "when passed no arguments for the last layer should not pass any arguments"
             (fn [T]
               (var count -1)
               (let [lonely {:init #(set count (select :# $...))}
                     wrapper (selector.init lonely)]
                 (T:assert (= count 0) "but it passed something"))))))
     (T "when running a callback"
        (fn [T]
          (T "should only pass it to one layer"
             (fn [T]
               (var call-count 0)
               (let [dupe {:init #nil :update #(set call-count (+ 1 call-count))}
                     wrapper (selector.init dupe [] dupe [])]
                 (selector.update wrapper))
               (T:assert (= call-count 1) "but it didn't")))
          (T "should pass it to the first layer by default"
             (fn [T]
               (var called-layer 0)
               (let [first {:init #nil :update #(set called-layer 1)}
                     second {:init #nil :update #(set called-layer 2)}
                     wrapper (selector.init first [] second [])]
                 (selector.update wrapper))
               (T:assert (= called-layer 1) "but it wasn't")))
          (T "should pass it to the selected layer"
             (fn [T]
               (var called-layer 0)
               (let [first {:init #nil :update #(set called-layer 1)}
                     second {:init #nil :update #(set called-layer 2)}
                     wrapper (selector.init first [] second [])]
                 (selector.select-next wrapper)
                 (selector.update wrapper))
               (T:assert (= called-layer 2) "but it wasn't")))))))