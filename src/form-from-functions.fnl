(local {:headset {:wasPressed was-pressed
                  :wasReleased was-released}} lovr)
(local fennel (require :third-party/fennel))

(local breaker (require :lib/logging-breaker))
(local text-input (require :lib/disk-text-input))
(local block (require :lib/block))
(local blocks (require :lib/blocks))
(local {: generate-code} (require :lib/code-gen))
(local elapsed-time (require :lib/elapsed-time))
(local hand (require :lib/hand))
(local log (require :lib/logging))
(local persistence (require :src/persistence))

(local form-from-functions {})
(local hands
       {:left (hand.init :hand/left)
        :right (hand.init :hand/right)})
(var input-mode :physical)
(var user-blocks (blocks.init))
(var text-focus nil)
(local elapsed (elapsed-time.init))
(local text-input (breaker.init text-input))

(var user-layer (breaker.init {}))

(fn form-from-functions.load []
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (when (persistence.blocks-file-exists?)
    (set user-blocks (persistence.load-blocks-file))))

(fn grab-nearby-block-if-able [hand blocks]
  (when (< 0 (length blocks))
    (local blocks-with-distance
          (icollect [_ block (ipairs user-blocks)]
                    [(: (- hand.position block.position) :length) block])) 
    (table.sort blocks-with-distance (fn [[d1 _] [d2 _]] (< d1 d2))) 
    (let [[distance nearest-block] (. blocks-with-distance 1)
           within-reach? (< distance 0.05)]
      (when within-reach?
        (set hand.contents nearest-block)))))

(fn adapt-physical-oculus-touch-input [query]
  {:evaluate (was-pressed :right :a)
   :save (was-pressed :right :b)
   :create-block (and (was-pressed :left :x)
                      (query.hand-contains-block? :left))
   :destroy-block (and (was-pressed :left :x)
                       (not (query.hand-contains-block? :left)))
   :link (and (or (was-pressed :left :trigger)
                  (was-pressed :right :trigger))
              (query.hand-contains-block? :left)
              (query.hand-contains-block? :right))
   :grab {:left (was-pressed :left :grip)
          :right (was-pressed :right :grip)}
   :drop {:left (was-released :left :grip)
          :right (was-released :right :grip)}
   :write-text (and (was-pressed :left :y)
                    (query.hand-contains-block? :left))})

(fn adapt-textual-oculus-touch-input [query]
  {:stop (was-pressed :left :y)})

(local available-input-adapters
       {:oculus {:physical adapt-physical-oculus-touch-input
                 :textual adapt-textual-oculus-touch-input}})

(local input-adapter available-input-adapters.oculus)

;; Provide a read-only way for input adapters to query the environment to
;; allow them to emit contextual events. These should return booleans so that
;; they can easily be slotted in to the existing expressions and not affect
;; their return type. Generally, they should also be called last in a chain of
;; conditionals because they may be computationally expensive - e.g. scanning
;; all items in the scene.
(local
 environmental-queries
 {:hand-contains-block? #(not (not (. hands $1 :contents)))})

(fn physical-update [dt]
  (match (input-adapter.physical environmental-queries)
    {:evaluate true}
    (xpcall
     (fn [] (set user-layer (breaker.init (fennel.eval (generate-code user-blocks)))))
     (fn [error]
       (log.error :codegen error)))
    {:save true}
    (persistence.save-blocks-file user-blocks)

    ({:create-block true})
    (let [block-to-remove hands.left.contents]
      (set hands.left.contents nil)
      (blocks.remove user-blocks block-to-remove))
    {:destroy-block true}
    (blocks.add user-blocks (block.init (hands.left.position:unpack)))
    ({:link true})
    (block.link hands.left.contents hands.right.contents)

    {:grab {:left true}}
    (grab-nearby-block-if-able hands.left user-blocks)
    {:grab {:right true}}
    (grab-nearby-block-if-able hands.right user-blocks)
    {:drop {:left true}}
    (set hands.left.contents nil)
    {:drop {:right true}}
    (set hands.right.contents nil)

    ({:write-text true})
    (do (set text-focus hands.left.contents)
        (set hands.left.contents nil)))
  (if text-focus :textual :physical))

(fn textual-update [dt]
  (breaker.update text-input dt text-focus)
  (match (input-adapter.textual environmental-queries)
    {:stop true} (set text-focus nil))
  (if text-focus :textual :physical))

(fn form-from-functions.update [dt]
  (elapsed-time.update elapsed dt)
  (hand.update hands.left)
  (hand.update hands.right)
  (set input-mode
       (match input-mode
         :physical (physical-update dt)
         :textual (textual-update dt)))
  (breaker.update user-layer))

(fn form-from-functions.draw []
  (elapsed-time.draw elapsed)
  (log.draw)
  (lovr.graphics.print
   (.. (hand.format hands.left) "\n    "
       (hand.format hands.right))
   -0.03 1.3 -2 0.1)
  (each [_ hand-name (pairs [:left :right])]
        (hand.draw (. hands hand-name)))
  (blocks.draw user-blocks)
  (breaker.draw text-input)
  (breaker.draw user-layer))

form-from-functions