(local {:headset {:isDown is-down
                  :wasPressed was-pressed
                  :wasReleased was-released}} lovr)
(local fennel (require :third-party/fennel))
(local lxsc (require :third-party/lxsc))

(local binder (require :lib/adapters/binder))
(local breaker (require :lib/logging-breaker))
(local text-input (require :lib/input/layered-radial-text-input))
(local block (require :lib/block))
(local blocks (require :lib/blocks))
(local {: generate-code} (require :lib/code-gen))
(local elapsed-time (require :lib/elapsed-time))
(local hand (require :lib/input/hand))
(local log (require :lib/logging))
(local persistence (require :src/persistence))
(local scxml (require :lib/scxml))

(local development-environment {})

(local
 machine-scxml
 (let [{: statechart : state : transition : parallel : send} scxml]
   (statechart
    {}
    (parallel {:id :development-environment}
              (state {} (parallel {:id :development-controls-active}
                               (state {:id :dev-visible}
                                      (state {:id :user-also-visible}
                                             (transition {:event :change-display-mode
                                                          :target :dev-only}))
                                      (state {:id :dev-only}
                                             (transition {:event :change-display-mode
                                                          :target :user-only})))
                               (state {:id :input-mode}
                                      (state {:id :physical}
                                             (transition {:event :change-input-mode
                                                          :target :textual}))
                                      (state {:id :textual}
                                             (transition {:event :change-input-mode
                                                          :target :physical}))))
                     (state {:id :user-only}
                            (transition {:event :change-display-mode :target :dev-visible})))
              (state {:id :mode-display}
                     (state {:id :mode-display-off}
                            (transition {:event :change-display-mode
                                         :target :mode-display-on}
                                        (send {:event :mode-display-timed-out
                                               :delay :1s})))
                     (state {:id :mode-display-on}
                            (transition {:event :mode-display-timed-out
                                         :target :mode-display-off})))))))

(fn development-environment.init []
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (let [machine (lxsc:parse machine-scxml)]
    (machine:start)
    {:elapsed (elapsed-time.init)
     :hands {:left (hand.init :hand/left)
             :right (hand.init :hand/right)}
     :text-focus nil
     :link-from {:left nil
                 :right nil}
     : machine
     :text-input (binder.init breaker text-input)
     :user-blocks (if (persistence.blocks-file-exists?)
                    (persistence.load-blocks-file)
                    (blocks.init))
     :user-layer (breaker.init {})}))

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
                                   (not (query.hand-contains-block? :left)))
                :destroy-block (and (was-pressed :left :x)
                                    (query.hand-contains-block? :left))
                :start-link {:left (was-pressed :left :trigger)
                             :right (was-pressed :right :trigger)}
                :end-link {:left (and (was-released :left :trigger)
                                      (query.drawing-link? :left))
                           :right (and (was-released :right :trigger)
                                       (query.drawing-link? :right))}
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
  (let [input (input-adapter.physical
               {:hand-contains-block? #(not (not (. self.hands $1 :contents)))
                :drawing-link? #(. self.link-from $1)})]
    (when input.evaluate
      (xpcall
       (fn [] (set self.user-layer (breaker.init (fennel.eval (generate-code self.user-blocks)))))
       (fn [error]
         (log.error :codegen error))))
    (when input.save
      (persistence.save-blocks-file self.user-blocks))
    (when input.create-block
      (blocks.add self.user-blocks (block.init (self.hands.left.position:unpack))))
    (when input.destroy-block
      (let [block-to-remove self.hands.left.contents]
        (set self.hands.left.contents nil)
        (blocks.remove self.user-blocks block-to-remove)))
    (when input.start-link.left
      (let [nearest-block (nearest-block-in-grab-distance self.hands.left.position self.user-blocks)]
        (when nearest-block
          (set self.link-from.left nearest-block))))
    (when input.end-link.left
      (let [nearest-block (nearest-block-in-grab-distance self.hands.left.position self.user-blocks)]
        (when nearest-block
          (block.link self.link-from.left nearest-block))
        (set self.link-from.left nil)))
    (if input.clone-grab.left
      (let [nearest-block (nearest-block-in-grab-distance self.hands.left.position self.user-blocks)]
        (when nearest-block
          ;; A clone grab overrides a link draw, so cancel the link.
          (set self.link-from.left nil)
          (let [new-block (block.init (self.hands.left.position:unpack))]
            (set new-block.text nearest-block.text)
            (blocks.add self.user-blocks new-block)
            (set self.hands.left.contents new-block))))
      input.grab.left (grab-nearby-block-if-able self.hands.left self.user-blocks)
      input.drop.left (set self.hands.left.contents nil))
    (if input.clone-grab.right
      (let [nearest-block (nearest-block-in-grab-distance self.hands.right.position self.user-blocks)]
        (when nearest-block
          (let [new-block (block.init (self.hands.right.position:unpack))]
            (set new-block.text nearest-block.text)
            (blocks.add self.user-blocks new-block)
            (set self.hands.right.contents new-block))))
      input.grab.right (grab-nearby-block-if-able self.hands.right self.user-blocks)
      input.drop.right (set self.hands.right.contents nil))
    (when input.write-text
      (self.machine:fireEvent :change-input-mode)
      (set self.text-focus self.hands.left.contents)
      (set self.hands.left.contents nil))))

(fn textual-update [self dt]
  (self.text-input:update dt self.text-focus)
  (match (input-adapter.textual environmental-queries)
    {:stop true} (do (self.machine:fireEvent :change-input-mode)
                     (set self.text-focus nil))))

(fn update-dev [self dt]
  (hand.update self.hands.left)
  (hand.update self.hands.right)
  (let [{: physical : textual} (self.machine:activeStateIds)]
    (when physical (physical-update self dt))
    (when textual (textual-update self dt))))

(fn development-environment.update [self dt]
  (elapsed-time.update self.elapsed dt)
  (when (and (was-pressed :left :y)
             (not self.hands.left.contents)
             (or (self.machine:isActive :physical)
                 (self.machine:isActive :user-only)))
    (self.machine:fireEvent :change-display-mode))
  (self.machine:step)
  (let [active-states (self.machine:activeStateIds)]
    (when active-states.dev-visible (update-dev self dt))
    (when (or active-states.user-also-visible active-states.user-only)
      (breaker.update self.user-layer dt))))

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
        (hand.draw (. self.hands hand-name))
        (when (. self.link-from hand-name)
          (let [(x1 y1 z1) (: (. self.link-from hand-name :position) :unpack)
                (x2 y2 z2) (: (. self.hands hand-name :position) :unpack)]
            (lovr.graphics.line x1 y1 z1 x2 y2 z2))))
  (blocks.draw self.user-blocks)

  (let [{: textual} (self.machine:activeStateIds)]
    (when textual
      (lovr.graphics.push)
      (lovr.graphics.translate (self.hands.left.position:unpack))
      (lovr.graphics.rotate (self.hands.left.rotation:unpack))
      (lovr.graphics.translate 0 0.1 -0.1)
      (lovr.graphics.rotate (- (/ math.pi 4)) 1 0 0)
      (lovr.graphics.scale 0.05)
      (self.text-input:draw)
      (lovr.graphics.pop))))

(fn development-environment.draw [self]
  (elapsed-time.draw self.elapsed)
  (let [active-states (self.machine:activeStateIds)]
    (when active-states.mode-display-on
      (lovr.graphics.print
       (if (and active-states.dev-visible active-states.user-also-visible) :simultaneous
           active-states.dev-visible :dev
           :user)
       -0.02 1 -2 0.25))
    (when active-states.dev-visible (draw-dev self))
    (when (or active-states.user-also-visible active-states.user-only)
      (breaker.draw self.user-layer))))

development-environment