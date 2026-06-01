# malformed-input error messages are stable

    Code
      read_qview(p, verbose = FALSE)
    Condition
      Error:
      ! `path` is not a valid .Q-View project file.
      x '<tmp>.csv' is missing the expected container header.
      i Expected a numeric container version followed by "Q-View Project".

---

    Code
      read_qview_template(q, verbose = FALSE)
    Condition
      Error:
      ! `path` is not a recognisable Q-View well-assignment template.
      x '<tmp>.csv' is missing the top-left "NxM" dimensions cell.
      i Expected the top-left cell to look like "12x8".

