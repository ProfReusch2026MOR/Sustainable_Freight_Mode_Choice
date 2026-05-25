NOTEBOOK = main.ipynb
BASENAME = notebook
BIB = ../literature/sources.bib
CSL = ./latex/ieee.csl
OUTPUT = notebook.pdf
LATEX_DIR = ./latex

all: pdf

pdf:
	python -m jupyter nbconvert --to markdown $(NOTEBOOK) --output $(BASENAME)
	pandoc $(BASENAME).md \
		--citeproc \
		--bibliography=$(BIB) \
		--csl=$(CSL) \
		--metadata link-citations=true \
		--metadata reference-section-title="Literatur" \
		--toc \
		--toc-depth=2 \
		--include-in-header=$(LATEX_DIR)/chapterbreak.tex \
		--include-in-header=$(LATEX_DIR)/codeformat.tex \
		--metadata toc-title="Inhaltsverzeichnis" \
		--lua-filter=$(LATEX_DIR)/minted.lua \
		--pdf-engine-opt=-shell-escape \
		--pdf-engine=xelatex \
		-o $(OUTPUT)

clean:
	rm -f $(BASENAME).md $(OUTPUT)
	rm -rf $(BASENAME)_files
	rm -rf _minted-$(BASENAME)

.PHONY: all pdf clean