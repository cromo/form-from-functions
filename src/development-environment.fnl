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

(local development-environment {})

(fn development-environment.init []
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  {:display-mode :simultaneous  ;; Can be one of simultaneous, dev, or user.
   :display-display-mode-until -1
   :elapsed (elapsed-time.init)
   :hands {:left (hand.init :hand/left)
           :right (hand.init :hand/right)}
   :input-mode :physical
   :text-focus nil
   :text-input (binder.init breaker text-input)
   :user-blocks (if (persistence.blocks-file-exists?)
                  (persistence.load-blocks-file)
                  (blocks.init))
   :user-layer (breaker.init {})})

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

(local
 available-input-adapters
 {:oculus-touch
  {:physical (fn [query]
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
   :textual (fn [query]
              {:stop (was-pressed :left :y)})}
  :vive-wands
  {:physical (fn [query]
               {:evaluate (was-pressed :right :touchpad)
                :save (was-pressed :right :menu)
                :create-block (and (was-pressed :left :touchpad)
                                   (query.hand-contains-block? :left))
                :destroy-block (and (was-pressed :left :touchpad)
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
                :write-text (and (was-pressed :left :menu)
                                 (query.hand-contains-block? :left))})
   :textual (fn [query]
              {:stop (was-pressed :left :menu)})}})

(local input-adapter
       (match (lovr.headset.getName)
         "Oculus Quest" available-input-adapters.oculus-touch
         "HTC" available-input-adapters.vive-wands))

(fn physical-update [self dt]
  (match (input-adapter.physical
          {:hand-contains-block? #(not (not (. self.hands $1 :contents)))})
    {:evaluate true}
    (xpcall
     (fn [] (set self.user-layer (breaker.init (fennel.eval (generate-code self.user-blocks)))))
     (fn [error]
       (log.error :codegen error)))
    {:save true}
    (persistence.save-blocks-file self.user-blocks)

    ({:create-block true})
    (let [block-to-remove self.hands.left.contents]
      (set self.hands.left.contents nil)
      (blocks.remove self.user-blocks block-to-remove))
    {:destroy-block true}
    (blocks.add self.user-blocks (block.init (self.hands.left.position:unpack)))
    ({:link true})
    (block.link self.hands.left.contents self.hands.right.contents)

    {:clone-grab {:left true}}
    (let [nearest-block (nearest-block-in-grab-distance self.hands.left.position self.user-blocks)]
      (when nearest-block
        (let [new-block (block.init (self.hands.left.position:unpack))]
          (set new-block.text nearest-block.text)
          (blocks.add self.user-blocks new-block)
          (set self.hands.left.contents new-block))))
    {:clone-grab {:right true}}
    (let [nearest-block (nearest-block-in-grab-distance self.hands.right.position self.user-blocks)]
      (when nearest-block
        (let [new-block (block.init (self.hands.right.position:unpack))]
          (set new-block.text nearest-block.text)
          (blocks.add self.user-blocks new-block)
          (set self.hands.right.contents new-block))))
    {:grab {:left true}}
    (grab-nearby-block-if-able self.hands.left self.user-blocks)
    {:grab {:right true}}
    (grab-nearby-block-if-able self.hands.right self.user-blocks)
    {:drop {:left true}}
    (set self.hands.left.contents nil)
    {:drop {:right true}}
    (set self.hands.right.contents nil)

    ({:write-text true})
    (do (set self.text-focus self.hands.left.contents)
        (set self.hands.left.contents nil)))
  (if self.text-focus :textual :physical))

(fn textual-update [self dt]
  (self.text-input:update dt self.text-focus)
  (match (input-adapter.textual environmental-queries)
    {:stop true} (set self.text-focus nil))
  (if self.text-focus :textual :physical))

(fn update-dev [self dt]
  (hand.update self.hands.left)
  (hand.update self.hands.right)
  (set self.input-mode
       (match self.input-mode
         :physical (physical-update self dt)
         :textual (textual-update self dt))))

(fn development-environment.update [self dt]
  (elapsed-time.update self.elapsed dt)
  (when (and (was-pressed :left :y)
             (not self.hands.left.contents))
    (set self.display-display-mode-until (+ self.elapsed.seconds 1))
    (set self.display-mode
         (match self.display-mode
           :simultaneous :dev
           :dev :user
           :user :simultaneous)))
  (match self.display-mode
    :simultaneous (do (update-dev self dt) (breaker.update self.user-layer))
    :dev (update-dev self dt)
    :user (breaker.update self.user-layer)))

(fn draw-dev [self]
  (lovr.graphics.push)
  (lovr.graphics.translate -2 0 -3)
  (lovr.graphics.scale 0.1)
  (log.draw)
  (lovr.graphics.pop)

  (lovr.graphics.print
   (.. (hand.format self.hands.left) "\n    "
       (hand.format self.hands.right))
   -0.03 1.3 -2 0.1)
  (each [_ hand-name (pairs [:left :right])]
        (hand.draw (. self.hands hand-name)))
  (blocks.draw self.user-blocks)

  (when (= self.input-mode :textual)
    (lovr.graphics.push)
    (lovr.graphics.translate (self.hands.left.position:unpack))
    (lovr.graphics.rotate (self.hands.left.rotation:unpack))
    (lovr.graphics.translate 0 0.1 -0.1)
    (lovr.graphics.rotate (- (/ math.pi 4)) 1 0 0)
    (lovr.graphics.scale 0.05)
    (self.text-input:draw)
    (lovr.graphics.pop)))

(fn development-environment.draw [self]
  (elapsed-time.draw self.elapsed)
  (when (< self.elapsed.seconds self.display-display-mode-until)
    (lovr.graphics.print self.display-mode -0.02 1 -2 0.25))
  (match self.display-mode
    :simultaneous (do (draw-dev self) (breaker.draw self.user-layer))
    :dev (draw-dev self)
    :user (breaker.draw self.user-layer)))

development-environment