(local code-gen {})

(fn code-gen.generate-code [blocks]
  (let [tokens {}]
    (fn gather-next [block]
      (table.insert tokens block.text)
      (if block.next (gather-next block.next)))
    (gather-next (. blocks 1))
    (table.concat tokens " ")))

code-gen