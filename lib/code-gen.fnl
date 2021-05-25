(local code-gen {})

(local generators {})

(fn gather-next [tokens block]
  (table.insert tokens ((. generators block.type) block))
  (if block.next (gather-next tokens block.next)))

(fn generators.plain-text [block]
  block.text)

(fn generators.container [block]
  (match block.contents
    nil (.. block.prefix block.suffix)
    contents (.. block.prefix (code-gen.generate-code contents) block.suffix)))

(fn code-gen.generate-code [block]
  (let [tokens []]
    (gather-next tokens block)
    (table.concat tokens " ")))

code-gen