TARGETS := swcarpentry/r-novice-gapminder.txt


.PHONY = all

all: $(TARGETS)

%.txt : %.R transform-lesson.R
	Rscript transform-lesson.R \
		--save    ../$(@D)/ \
		--output  ../$(@D)/sandpaper/ \
		          $(@D)/$* \
		          $<
	touch $@

