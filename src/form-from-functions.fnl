(local {:headset {:isDown is-down
                  :wasPressed was-pressed
                  :wasReleased was-released}} lovr)
(local fennel (require :third-party/fennel))

(local binder (require :lib/binder))
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
(local text-input (binder.init breaker text-input))

(var user-layer (breaker.init {}))
;; Can be one of simultaneous, dev, or user.
(var display-mode :simultaneous)

(fn form-from-functions.init []
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (when (persistence.blocks-file-exists?)
    (set user-blocks (persistence.load-blocks-file))))

;; Sort all blocks by distance from a point.
;; Returns a list of [distance block] tuples.
(fn blocks-sorted-by-distance [from user-blocks]
  (local blocks-with-distance
          (icollect [_ block (ipairs user-blocks)]
                    [(: (- from block.position) :length) block])) 
  (table.sort blocks-with-distance (fn [[d1 _] [d2 _]] (< d1 d2)))
  blocks-with-distance)

;; Get the nearest block within grab distance from a point.
;; Returns a reference to the nearest block or nil if there isn't one in range.
(fn nearest-block-in-grab-distance [from user-blocks]
  (local blocks-with-distance (blocks-sorted-by-distance from user-blocks))
  (when (< 0 (length blocks-with-distance))
    (let [[[distance nearest-block]] blocks-with-distance
          within-reach? (< distance 0.05)]
      (when within-reach? nearest-block))))

(fn grab-nearby-block-if-able [hand blocks]
  (set hand.contents (nearest-block-in-grab-distance hand.position blocks)))

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
   :clone-grab {:left (and (is-down :left :trigger)
                           (was-pressed :left :grip))
                :right (and (is-down :right :trigger)
                            (was-pressed :right :grip))}
   :drop {:left (was-released :left :grip)
          :right (was-released :right :grip)}
   :write-text (and (was-pressed :left :y)
                    (query.hand-contains-block? :left))})

(fn adapt-textual-oculus-touch-input [query]
  {:stop (was-pressed :left :y)})

(local available-input-adapters
       {"Oculus Quest" {:physical adapt-physical-oculus-touch-input
                        :textual adapt-textual-oculus-touch-input}})

(local input-adapter (. available-input-adapters (lovr.headset.getName)))

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

    {:clone-grab {:left true}}
    (let [nearest-block (nearest-block-in-grab-distance hands.left.position user-blocks)]
      (when nearest-block
        (let [new-block (block.init (hands.left.position:unpack))]
          (set new-block.text nearest-block.text)
          (blocks.add user-blocks new-block)
          (set hands.left.contents new-block))))
    {:clone-grab {:right true}}
    (let [nearest-block (nearest-block-in-grab-distance hands.right.position user-blocks)]
      (when nearest-block
        (let [new-block (block.init (hands.right.position:unpack))]
          (set new-block.text nearest-block.text)
          (blocks.add user-blocks new-block)
          (set hands.right.contents new-block))))
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
  (text-input:update dt text-focus)
  (match (input-adapter.textual environmental-queries)
    {:stop true} (set text-focus nil))
  (if text-focus :textual :physical))

(fn update-dev [dt]
  (hand.update hands.left)
  (hand.update hands.right)
  (set input-mode
       (match input-mode
         :physical (physical-update dt)
         :textual (textual-update dt))))

(fn form-from-functions.update [self dt]
  (elapsed-time.update elapsed dt)
  (when (and (was-pressed :left :y)
             (not (environmental-queries.hand-contains-block? :left)))
    (set display-mode
         (match display-mode
           :simultaneous :dev
           :dev :user
           :user :simultaneous)))
  (match display-mode
    :simultaneous (do (update-dev dt) (breaker.update user-layer))
    :dev (update-dev dt)
    :user (breaker.update user-layer)))

(fn draw-dev []
  (log.draw)
  (lovr.graphics.print
   (.. (hand.format hands.left) "\n    "
       (hand.format hands.right))
   -0.03 1.3 -2 0.1)
  (each [_ hand-name (pairs [:left :right])]
        (hand.draw (. hands hand-name)))
  (blocks.draw user-blocks)
  (text-input:draw))

(fn form-from-functions.draw [self]
  (elapsed-time.draw elapsed)
  (match display-mode
    :simultaneous (do (draw-dev) (breaker.draw user-layer))
    :dev (draw-dev)
    :user (breaker.draw user-layer)))

form-from-functions