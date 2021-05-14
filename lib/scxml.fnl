(local module {})

(fn xml-tag [tag allowed-attributes]
  (fn [attributes ...]
    (let [attribute-strings (icollect [_ attribute (ipairs allowed-attributes)]
                                      (when (. attributes attribute)
                                        (.. attribute "=\"" (. attributes attribute) "\"")))
          children [...]]
      (.. "<" tag " " (table.concat attribute-strings " ") ">\n"
          (table.concat children "\n")
          "\n</" tag ">"))))

(local raw-statechart (xml-tag :scxml [:xmlns :version]))

(fn module.statechart [attributes ...]
  (set attributes.xmlns "http://www.w3.org/2005/07/scxml")
  (set attributes.version "1.0")
  (raw-statechart attributes ...))
(set module.state (xml-tag :state [:id]))
(set module.transition (xml-tag :transition [:event :target]))

module