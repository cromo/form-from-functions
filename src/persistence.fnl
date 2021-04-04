(local blocks (require :lib/blocks))

(local persistence {})

(local blocks-filename :blocks.json)

(fn persistence.blocks-file-exists? []
  (lovr.filesystem.isFile blocks-filename))

(fn persistence.save-blocks-file [blocks-to-save]
  (lovr.filesystem.write blocks-filename (blocks.serialize blocks-to-save)))

(fn persistence.load-blocks-file []
  (blocks.deserialize (lovr.filesystem.read blocks-filename)))

persistence