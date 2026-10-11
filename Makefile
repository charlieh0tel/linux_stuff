.PHONY: lint

lint:
	git ls-files -z '*.sh' | grep -zv '^dotfiles/dot\.' | xargs -0 shellcheck
