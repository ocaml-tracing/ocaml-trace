
DUNE_OPTS?=
all:
	dune build @all $(DUNE_OPTS)

clean:
	@dune clean

test:
	@dune runtest $(DUNE_OPTS)
test-autopromote:
	@dune runtest $(DUNE_OPTS) --auto-promote

doc:
	@dune build $(DUNE_OPTS) @doc

format:
	@dune build @fmt --auto-promote

format-check:
	@dune build @fmt --ignore-promoted-rules

WATCH?= @install @runtest
watch:
	dune build $(DUNE_OPTS) -w $(WATCH)

.PHONY: test clean watch

VERSION=$(shell awk '/^version:/ {print $$2}' trace.opam)

update_next_tag:
	@echo "update version to $(VERSION)..."
	sed --follow-symlinks -i "s/NEXT_VERSION/$(VERSION)/g" $(wildcard src/**.ml) $(wildcard src/**.mli) \
			$(wildcard src/**/*.ml) $(wildcard src/**/*.mli)
	sed --follow-symlinks -i "s/NEXT_RELEASE/$(VERSION)/g" $(wildcard src/**.ml) $(wildcard src/**.mli) \
		$(wildcard src/**/*.ml) $(wildcard src/**/*.mli)
