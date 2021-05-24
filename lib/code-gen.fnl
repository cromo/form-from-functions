(local code-gen {})

(local generators {})

(fn generators.plain-text [block]
  block.text)

(fn code-gen.generate-code [block]
  (let [tokens {}]
    (fn gather-next [block]
      (table.insert tokens ((. generators block.type) block))
      (if block.next (gather-next block.next)))
    (gather-next block)
    (table.concat tokens " ")))

code-gen