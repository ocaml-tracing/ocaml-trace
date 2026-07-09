(lang dune 2.9)

(name trace)

(generate_opam_files true)

(version 0.12)

(source
 (github ocaml-tracing/ocaml-trace))

(authors "Simon Cruanes")

(maintainers "Simon Cruanes")

(license MIT)

;(documentation https://url/to/documentation)

(package
 (name trace)
 (synopsis
  "A lightweight stub for tracing/observability, agnostic in how data is collected")
 (description
  "ocaml-trace can be used to instrument libraries and programs with low overhead. It doesn't do any IO unless a collector is plugged in, which only the final executable should do.")
 (depends
  (ocaml
   (>= 4.08))
  dune)
 (depopts
  unix
  lwt
  (thread-local-storage (>= 0.2))
  (mtime
   (>= 2.0)))
 (tags
  (trace tracing observability profiling)))

(package
 (name ppx_trace)
 (synopsis "A ppx-based preprocessor for trace")
 (depends
  (ocaml
   (>= 4.12))
  ; we use __FUNCTION__
  (ppxlib
   (and
    (>= 0.37)
    (< 0.39)))
  (trace
   (= :version))
  (trace-tef
   (and
    (= :version)
    :with-test))
  dune)
 (depopts
  (mtime
   (>= 2.0)))
 (tags
  (trace ppx)))

(package
 (name trace-tef)
 (synopsis
  "A simple backend for trace, emitting Catapult/TEF JSON into a file")
 (depends
  (ocaml
   (>= 4.08))
  (trace
   (= :version))
  (mtime
   (>= 2.0))
  base-unix
  dune)
 (tags
  (trace tracing catapult TEF chrome-format chrome-trace json)))

(package
 (name trace-fuchsia)
 (synopsis
  "A high-performance backend for trace, emitting a Fuchsia trace into a file")
 (depends
  (ocaml
   (>= 4.08))
  (trace
   (= :version))
  (mtime
   (>= 2.0))
  base-bigarray
  base-unix
  dune)
 (tags
  (trace tracing fuchsia)))

(package
 (name trace-runtime-events)
 (synopsis
  "A simple collector relying on runtime-events for OCaml 5. Some assembly required.")
 (depends
  (ocaml
   (>= 5.1))
  (trace
   (= :version))
  (ppx_trace (and (= :version) :with-test))
  base-bigarray
  base-unix
  dune)
 (tags
  (trace tracing trace runtime-events)))

(package
 (name trace-spall)
 (synopsis
  "A fast binary backend for trace, emitting Spall profiler format (.spall)")
 (depends
  (ocaml
   (>= 4.08))
  (trace
   (= :version))
  (mtime
   (>= 2.0))
  (thread-local-storage
   (>= 0.2))
  base-unix
  dune)
 (tags
  (trace tracing spall profiling)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
