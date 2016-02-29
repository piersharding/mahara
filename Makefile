all: css

production = true
css:
ifeq (, $(shell which npm))
	$(error ERROR: Can't find the "npm" executable. Try "sudo apt-get install npm")
endif
ifeq (, $(shell which node))
	$(error ERROR: Can't find the "node" executable. Try "sudo apt-get install nodejs-legacy")
endif
ifeq (, $(shell which gulp))
	$(error ERROR: Can't find the "gulp" executable. Try doing "sudo npm install -g gulp")
endif
ifndef npmsetup
	npm install
endif
	@echo "Building CSS..."
	@if gulp css --production $(production) ; then echo "Done!"; else npm install; gulp css --production $(production);  fi

clean-css:
	find ./htdocs/theme/* -maxdepth 1 -name "style" -type d -exec rm -Rf {} \;

help:
	@echo "Run 'make' to do "build" Mahara (currently only CSS)"
	@echo "Run 'make initcomposer' to install Composer and phpunit"
	@echo "Run 'make phpunit' to execute phpunit tests"
	@echo "Run 'make ssphp' to install SimpleSAMLphp"
	@echo "Run 'make cleanssphp' to remove SimpleSAMLphp"
	@echo "Run 'make imageoptim' to losslessly optimise all images"
	@echo "Run 'make minaccept' to run the quick pre-commit tests"
	@echo "Run 'make checksignoff' to check that your commits are all Signed-off-by"
	@echo "Run 'make push' to push your changes to the repo"

imageoptim:
	find . -iname '*.png' -exec optipng -o7 -q {} \;
	find . -iname '*.gif' -exec gifsicle -O2 -b {} \;
	find . -iname '*.jpg' -exec jpegoptim -q -p --strip-all {} \;
	find . -iname '*.jpeg' -exec jpegoptim -q -p --strip-all {} \;

composer := $(shell ls external/composer.phar 2>/dev/null)

installcomposer:
ifdef composer
	@echo "Composer allready installed..."
else
	@echo "Installing Composer..."
	@curl -sS https://getcomposer.org/installer | php -- --install-dir=external
endif

initcomposer: installcomposer
	@echo "Updating external dependencies with Composer..."
	@php external/composer.phar --working-dir=external update

simplesamlphp := $(shell ls -d htdocs/auth/saml/extlib/simplesamlphp 2>/dev/null)

cleanssphp:
	@echo "Cleaning out SimpleSAMLphp..."
	rm -rf htdocs/auth/saml/extlib/simplesamlphp

ssphp: installcomposer
ifdef simplesamlphp
	@echo "SimpleSAMLphp already exists - doing nothing"
else
	@echo "Pulling SimpleSAMLphp from download ..."
	@curl -sS https://simplesamlphp.org/res/downloads/simplesamlphp-1.14.0.tar.gz | tar  --transform s/simplesamlphp-1.14.0/simplesamlphp/ -C htdocs/auth/saml/extlib -xzf -
	@php external/composer.phar --working-dir=htdocs/auth/saml/extlib/simplesamlphp update
endif


vendorphpunit := $(shell external/vendor/bin/phpunit --version 2>/dev/null)

phpunit:
	@echo "Running phpunit tests..."
ifdef vendorphpunit
	@external/vendor/bin/phpunit --log-junit logs/tests/phpunit-results.xml htdocs/
else
	@phpunit --log-junit logs/tests/phpunit-results.xml htdocs/
endif


revision := $(shell git rev-parse --verify HEAD 2>/dev/null)
whitelist := $(shell grep / test/WHITELIST | xargs -I entry find entry -type f | xargs -I file echo '! -path ' file 2>/dev/null)

minaccept:
	@echo "Running minimum acceptance test..."
ifdef revision
	@git diff-tree --diff-filter=ACM --no-commit-id --name-only -z -r $(revision) htdocs | grep -z "^htdocs/.*\.php$$" | xargs -0 -n 1 -P 2 --no-run-if-empty php -l
	@php test/versioncheck.php
	@git diff-tree --diff-filter=ACM --no-commit-id --name-only -z -r $(revision) htdocs | grep -z '^htdocs/.*/db/install\.xml$$' | xargs -0 -n 1 -P 2 --no-run-if-empty xmllint --schema htdocs/lib/xmldb/xmldb.xsd --noout
	@git diff-tree --diff-filter=ACM --no-commit-id --name-only -r $(revision) | xargs -I {} find {} $(whitelist) | xargs -I list git show $(revision) -- list | test/coding-standard-check.pl
	@echo "Acceptance test passed. :)"
else
	@echo "No revision found!"
endif

jenkinsaccept: minaccept
	@find ./ ! -path './.git/*' -type f -print0 | xargs -0 clamscan > /dev/null && echo All good!

sshargs := $(shell git config --get remote.gerrit.url | sed -re 's~^ssh://([^@]*)@([^:]*):([0-9]*)/mahara~-p \3 -l \1 \2~')
mergebase := $(shell git fetch gerrit >/dev/null 2>&1 && git merge-base HEAD gerrit/master)
sha1chain := $(shell git log $(mergebase)..HEAD --pretty=format:%H | xargs)
changeidchain := $(shell git log $(mergebase)..HEAD --pretty=format:%b | grep '^Change-Id:' | cut -d' ' -f2)

securitycheck:
	@if ssh $(sshargs) gerrit query --format TEXT -- $(shell echo $(sha1chain) $(changeidchain) | sed -e 's/ / OR /g') | grep 'status: DRAFT' >/dev/null; then \
		echo "This change has drafts in the chain. Please use make security instead"; \
		false; \
	fi
	@if git log $(mergebase)..HEAD --pretty=format:%B | grep -iE '(security|cve)' >/dev/null; then \
		echo "This change has a security keyword in it. Please use make security instead"; \
		false; \
	fi

push: securitycheck minaccept
	@echo "Pushing the change upstream..."
	@if test -z "$(TAG)"; then \
		git push gerrit HEAD:refs/publish/master; \
	else \
		git push gerrit HEAD:refs/publish/master/$(TAG); \
	fi

security: minaccept
	@echo "Pushing the SECURITY change upstream..."
	@if test -z "$(TAG)"; then \
		git push gerrit HEAD:refs/drafts/master; \
	else \
		git push gerrit HEAD:refs/drafts/master/$(TAG); \
	fi
	ssh $(sshargs) gerrit set-reviewers --add \"Mahara Security Managers\" -- $(sha1chain)
