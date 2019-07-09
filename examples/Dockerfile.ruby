FROM ruby:2.6.3-alpine3.10
SHELL [ "/usr/local/bin/ruby", "-e" ]
RUN puts Dir.pwd
RUN foo='/foo'; \
    Dir.mkdir '/foo'; \
    Dir.chdir foo; \
    puts Dir.pwd; \
    require 'fileutils'; \
    FileUtils.touch('bar.txt')
RUN exec("apk add vim")
RUN exec("ls -lart /foo/")