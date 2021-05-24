(local code-gen {})

(fn code-gen.generate-code [block]
  (let [tokens {}]
    (fn gather-next [block]
      (table.insert tokens block.text)
      (if block.next (gather-next block.next)))
    (gather-next block)
    (table.concat tokens " ")))

code-gen