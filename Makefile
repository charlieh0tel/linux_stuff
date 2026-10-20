RUFF = uvx ruff@0.15.10

SH = $(shell git ls-files '*.sh' | grep -v '^dotfiles/dot\.')
PY = $(shell git ls-files '*.py') bin/mkminircs
PL = $(shell git ls-files '*.pl')

.PHONY: lint lint-sh lint-py lint-pl format

lint: lint-sh lint-py lint-pl

lint-sh:
	shellcheck -x $(SH)

lint-py:
	$(RUFF) check $(PY)
	$(RUFF) format --check $(PY)

lint-pl:
	for f in $(PL); do perl -cw "$$f" || exit 1; done

format:
	$(RUFF) format $(PY)
