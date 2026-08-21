.DEFAULT_GOAL := link
.PHONY: link check status dry-run doctor unlink test help

link:
	@./deploy.sh

check:
	@./deploy.sh --check

status:
	@./deploy.sh --status

dry-run:
	@./deploy.sh --dry-run

doctor:
	@./deploy.sh --doctor

unlink:
	@./deploy.sh --unlink

test:
	@bash tests/test_deploy.sh

help:
	@./deploy.sh --help
