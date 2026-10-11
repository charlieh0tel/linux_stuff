RUFF = uvx ruff@0.15.10

SH = $(shell git ls-files '*.sh' | grep -v '^dotfiles/dot\.')
PY = $(shell git ls-files '*.py') bin/mkminircs

.PHONY: lint lint-sh lint-py format

lint: lint-sh lint-py

lint-sh:
	shellcheck $(SH)

lint-py:
	$(RUFF) check $(PY)
	$(RUFF) format --check $(PY)

format:
	$(RUFF) format $(PY)
