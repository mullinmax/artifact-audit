.PHONY: audit test

AUDIT_ARGS ?=

audit:
	./artifact_audit.sh $(AUDIT_ARGS)

test:
	bash tests/test_artifact_audit.sh
