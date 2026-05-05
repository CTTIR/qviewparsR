# error messages match snapshots

    Code
      read_qview("nonexistent.Q-View")
    Condition
      Error:
      ! `path` must be an existing file.
      x 'nonexistent.Q-View' does not exist.

---

    Code
      read_qview(123)
    Condition
      Error:
      ! `path` must be a single non-empty string.
      x Got <numeric> of length 1.

