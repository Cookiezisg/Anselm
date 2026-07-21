.DEFAULT_GOAL := help

help:
	@echo "Anselm web demo"
	@echo ""
	@echo "  make serve     preview the demo"
	@echo "  make test      run the Playwright matrix"

serve:
	@node tools/serve.mjs

test:
	@node tools/matrix.mjs

.PHONY: help serve test
