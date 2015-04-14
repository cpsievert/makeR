R	:= R --no-save --no-restore
RSCRIPT	:= Rscript
DELETE	:= rm -fR
PKGNAME := $(shell Rscript ./makeR/get-pkg-name)
VERSION := $(shell Rscript ./makeR/get-pkg-version)
TARGZ   := $(PKGNAME)_$(VERSION).tar.gz

.SILENT:

usage:
	echo "Available targets:"
	echo ""
	echo " clean          - Clean everything up"
	echo " bump-cran      - Bump second digit of version (0.1 -> 0.2) and tag"
	echo " bump-gh        - Bump third digit of version (0.1.2 -> 0.1.3) and tag"
	echo " bump           - Bump fourth digit of version (0.1.2.3 -> 0.1.2.4) and tag"
	echo " rd             - Create documentation via roxygen2"
	echo " install        - Install dependencies"
	echo " dependencies   "
	echo " test           - Run tests"
	echo " covr           - Check coverage"
	echo " lintr          - Run lintr"
	echo " check-rev-dep  - Run a reverse dependency check against packages on CRAN"
	echo " check-rd-files - Run Rd2pdf on each doc file to track hard-to-spot doc/latex errors"
	echo " winbuilder     - Ask for email and build on winbuilder"
	echo " init-gh-pages  - Initialize orphan gh-pages branch"
	echo " staticdocs     - Build staticdocs in inst/web"
	echo " gh-pages-build - Populate gh-pages branch with staticdocs"
	echo " gh-pages-push  - Push gh-pages branch to GitHub Pages"
	echo " view-docs      - View staticdocs locally"
	echo " init-wercker   - Install a default wercker.yml"
	echo " wercker-build  - Run wercker build for local instance of docker"
	echo " wercker-deploy - Run wercker deploy for local instance of docker"
	echo " upgrade        - upgrade installation of makeR"
	echo " uninstall      - uninstall makeR"


## Script targers

git-is-clean branch-is-master init-gh-pages init-staticdocs gh-pages-build postinstall init-wercker:
	sh ./makeR/$@



## Helper targers

git-is-clean:

branch-is-master: git-is-clean

tag:
	(echo Release v$$(sed -n -r '/^Version: / {s/.* ([0-9.-]+)$$/\1/;p}' DESCRIPTION); echo; sed -n '/^===/,/^===/{:a;N;/\n===/!ba;p;q}' NEWS.md | head -n -3 | tail -n +3) | git tag -a -F /dev/stdin v$$(sed -n -r '/^Version: / {s/.* ([0-9.-]+)$$/\1/;p}' DESCRIPTION)

bump-cran-desc: branch-is-master rd
	crant -u 2 -C

bump-gh-desc: branch-is-master rd
	crant -u 3 -C

bump-desc: branch-is-master rd
	test "$$(git status --porcelain | wc -c)" = "0"
	sed -i -r '/^Version: / s/( [0-9.]+)$$/\1-0.0/' DESCRIPTION
	git add DESCRIPTION
	test "$$(git status --porcelain | wc -c)" = "0" || git commit -m "add suffix -0.0 to version"
	crant -u 4 -C

inst/NEWS.Rd: git-is-clean NEWS.md
	Rscript -e "tools:::news2Rd('$(word 2,$^)', '$@')"
	sed -r -i 's/`([^`]+)`/\\code{\1}/g' $@
	git add $@
	test "$$(git status --porcelain | wc -c)" = "0" || git commit -m "update NEWS.Rd"

inst/web:
	mkdir -p inst
	git branch gh-pages origin/gh-pages || true
	git clone --branch gh-pages . inst/web



## Cleanup

clean:
	echo  "Cleaning up ..."
	${DELETE} src/*.o src/*.so *.tar.gz
	${DELETE} *.Rcheck
	${DELETE} .RData .Rhistory



## Tagging

bump-cran: bump-cran-desc inst/NEWS.Rd tag

bump-gh: bump-gh-desc inst/NEWS.Rd tag

bump: bump-desc inst/NEWS.Rd tag



## Documentation

rd: git-is-clean
	Rscript -e "library(methods); devtools::document()"
	git add man/ NAMESPACE
	test "$$(git status --porcelain | wc -c)" = "0" || git commit -m "document"



## Testing

dependencies-hook:

install dependencies: dependencies-hook
	Rscript -e "sessionInfo()"
	Rscript -e "devtools::install_github('hadley/testthat')"
	Rscript -e "options(repos = 'http://cran.rstudio.com'); devtools::install_deps(dependencies = TRUE)"

test:
	Rscript -e "devtools::check(document = FALSE, check_dir = '.', cleanup = FALSE)"
	! egrep -A 5 "ERROR|WARNING|NOTE" *.Rcheck/00check.log

covr:
	Rscript -e 'if (!requireNamespace("covr")) devtools::install_github("jimhester/covr"); covr::codecov()'

lintr:
	Rscript -e 'if (!requireNamespace("lintr")) devtools::install_github("jimhester/lintr"); lintr::lint_package()'

check-rev-dep:
	echo "Running reverse dependency checks for CRAN ..."
	${RSCRIPT} ./makeR/check-rev-dep

check-rd-files: rd
	echo "Checking RDs one by one ..."
	${RSCRIPT} ./makeR/check-rd-files

winbuilder: rd
	echo "Building via winbuilder"
	${RSCRIPT} ./makeR/winbuilder



# staticdocs

gh-pages-init:

init-staticdocs:

staticdocs: inst/web
	Rscript -e 'if (!requireNamespace("staticdocs")) devtools::install_github("gaborcsardi/staticdocs"); staticdocs::build_site()'

gh-pages-build: staticdocs

gh-pages-push:
	git push origin gh-pages

view-docs:
	chromium-browser inst/web/index.html



## wercker

init-wercker: branch-is-master

wercker-build:
	wercker build --docker-host=unix://var/run/docker.sock --no-remove

wercker-deploy:
	wercker deploy --docker-host=unix://var/run/docker.sock --no-remove



## Maintenance

postinstall: branch-is-master

upgrade: branch-is-master
	echo "Upgrading makeR"
	sh ./makeR/upgrade

uninstall: branch-is-master
	echo "Uninstalling makeR"
	sh ./makeR/uninstall
