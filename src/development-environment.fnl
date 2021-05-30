(local {:headset {:isDown is-down
                  :wasPressed was-pressed
                  :wasReleased was-released
                  :isTouched is-touched}} lovr)
(local fennel (require :third-party/fennel))
(local lxsc (require :third-party/lxsc))

(local binder (require :lib/adapters/binder))
(local non-empty-breaker-stack (require :lib/adapters/non-empty-breaker-stack))
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
(local hotkey (require :lib/input/hotkey))

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
  (var escape-start nil)
  (let [machine (lxsc:parse machine-scxml)]
    (machine:start)
    {:elapsed (elapsed-time.init)
     :hands {:left (hand.init :hand/left)
             :right (hand.init :hand/right)}
     :text-focus nil
     :link-from {:left nil
                 :right nil}
     :link-type {:left nil
                 :right nil}
     : machine
     :hotkeys [(hotkey.init #(let [down (vec3 0 -1 0)
                                   left-hand-orientation (quat (lovr.headset.getOrientation :left))
                                   left-hand-relative-down (: (left-hand-orientation:direction) :dot down)
                                   right-hand-orientation (quat (lovr.headset.getOrientation :right))
                                   right-hand-relative-down (: (right-hand-orientation:direction) :dot down)
                                   gesture-recognized
                                   (and (is-touched :left :trigger)
                                       (is-touched :right :trigger)
                                       (not (is-touched :left :x))
                                       (not (is-touched :left :y))
                                       (not (is-touched :right :a))
                                       (not (is-touched :right :b))
                                       (not (is-touched :left :thumbstick))
                                       (not (is-touched :right :thumbstick))
                                       (< 0.6 left-hand-relative-down)
                                       (< 0.6 right-hand-relative-down))]
                               (match [gesture-recognized escape-start]
                                 (where [false t] (not= t nil)) (do (set escape-start nil)
                                                                    (log.info :escape "escape gesture stopped"))
                                 [true nil] (do (set escape-start (os.clock))
                                                (log.info :escape "escape gesture recognized")))
                               (when escape-start
                                 (< 1 (- (os.clock) escape-start))))
                            #(do (log.info :escape "Escape triggered")
                                 (non-empty-breaker-stack.clear $1.text-input)))]
     :text-input (non-empty-breaker-stack.init text-input
                                               #(log.error :input (debug.traceback (.. "In " $1 " layer: " (tostring $2)))))
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
                :create-block (and (is-down :left :grip)
                                   (was-pressed :left :trigger)
                                   (not (query.hand-contains-block? :left)))
                :destroy-block (and (was-pressed :left :trigger)
                                    (query.hand-contains-block? :left))
                :change-block-type (and (was-pressed :left :x)
                                        (query.hand-contains-block? :left))
                :start-link {:left (was-pressed :left :trigger)
                             :right (was-pressed :right :trigger)}
                :end-link {:left (and (was-released :left :trigger)
                                      (query.drawing-link? :left))
                           :right (and (was-released :right :trigger)
                                       (query.drawing-link? :right))}
                :change-link-type {:left (and (was-pressed :left :x)
                                              (query.drawing-link? :left))
                                   :right false}
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
              {:stop (was-pressed :left :y)})}})

(local input-adapter
       (match (lovr.headset.getName)
         "Oculus Quest" available-input-adapters.oculus-touch
         "HTC" available-input-adapters.vive-wands))

(fn physical-update [self dt]
  (let [input (input-adapter.physical
               {:hand-contains-block? #(not (not (. self.hands $1 :contents)))
                :drawing-link? #(. self.link-from $1)})]
    (when input.evaluate
      (match self.user-blocks
        [first-block & _]
        (xpcall
         (fn [] (set self.user-layer
                     (breaker.init (fennel.eval (generate-code first-block))
                                   {:add-text-input #(non-empty-breaker-stack.push self.text-input $1 $2)})))
         (fn [error]
           (log.error :codegen error)))))
    (when input.save
      (persistence.save-blocks-file self.user-blocks))
    (when input.create-block
      (let [new-block (block.init (self.hands.left.position:unpack))]
        (set self.hands.left.contents new-block)
        (blocks.add self.user-blocks new-block)))
    (when input.destroy-block
      (let [block-to-remove self.hands.left.contents]
        (set self.hands.left.contents nil)
        (blocks.remove self.user-blocks block-to-remove)))
    (when input.change-block-type
      (block.become-next-type self.hands.left.contents))
    (fn update-symmetric-hand-input [hand-name]
      (let [hand (. self.hands hand-name)
            start-link (. input.start-link hand-name)
            end-link (. input.end-link hand-name)
            link-from (. self.link-from hand-name)
            clone-grab (. input.clone-grab hand-name)
            grab (. input.grab hand-name)
            drop (. input.drop hand-name)
            change-link-type (. input.change-link-type hand-name)]
        (when start-link
          (let [nearest-block (nearest-block-in-grab-distance hand.position self.user-blocks)]
            (when nearest-block
              (tset self.link-type hand-name :next)
              (tset self.link-from hand-name nearest-block))))
        (when end-link
          (let [nearest-block (nearest-block-in-grab-distance hand.position self.user-blocks)]
            (when nearest-block
              (if (= (. self.link-type hand-name) :next)
                (block.link link-from nearest-block)
                (block.link-contents link-from nearest-block)))
            (tset self.link-from hand-name nil)))
        (when (and change-link-type (= link-from.type :container))
          (let [link-type (. self.link-type hand-name)]
            (tset self.link-type hand-name (match link-type
                                             :next :contents
                                             :contents :next))))
        (if clone-grab
          (let [nearest-block (nearest-block-in-grab-distance hand.position self.user-blocks)]
            (when nearest-block
              ;; A clone grab overrides a link draw, so cancel the link.
              (tset self.link-from hand-name nil)
              (let [new-block (block.init (hand.position:unpack))]
                (set new-block.text nearest-block.text)
                (set new-block.prefix nearest-block.prefix)
                (set new-block.suffix nearest-block.suffix)
                (set new-block.type nearest-block.type)
                (blocks.add self.user-blocks new-block)
                (set hand.contents new-block))))
          grab (grab-nearby-block-if-able hand self.user-blocks)
          drop (set hand.contents nil))))
    (update-symmetric-hand-input :left)
    (update-symmetric-hand-input :right)
    
    (when input.write-text
      (self.machine:fireEvent :change-input-mode)
      (set self.text-focus self.hands.left.contents)
      (set self.hands.left.contents nil))))

(fn textual-update [self dt]
  (non-empty-breaker-stack.update self.text-input dt self.text-focus)
  (match (input-adapter.textual environmental-queries)
    {:stop true} (do (self.machine:fireEvent :change-input-mode)
                     (set self.text-focus nil))))

(fn update-dev [self dt]
  (hand.update self.hands.left)
  (hand.update self.hands.right)
  (each [_ hk (ipairs self.hotkeys)]
        ;; (log.verbose :hotkey "Calling hotkey.update")
        (hotkey.update hk self))
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
                (x2 y2 z2) (: (. self.hands hand-name :position) :unpack)
                link-type (. self.link-type hand-name)
                color (match link-type
                        :next :0xffffff
                        :contents :0x00ffff)]
            (lovr.graphics.setColor color)
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
      (non-empty-breaker-stack.draw self.text-input)
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