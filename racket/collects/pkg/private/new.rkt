#lang racket/base

(provide pkg-new)

(require racket/match
         racket/port
         racket/system
         racket/string
         racket/date
         racket/format
         setup/collection-name
         "print.rkt")

(define (package-name? package)
  (regexp-match-exact? #rx"[-_a-zA-Z0-9]*" package))

(define (pkg-new name)

  ;; Useful strings
  (define user
    (string-trim
     (with-output-to-string
         (lambda ()
           (match (system-type)
             [(or 'unix 'macosx)
              (system "whoami")]
             ['windows
              (system "echo %username%")]
             [else (pkg-error "not supported")])))))

  (define ====
    (make-string (string-length name) #\=))

  (define year
    (number->string (date-year (current-date))))

  (define sanitized-name
    (if (string->number name)
        (string-append "|" name "|")
        name))

  ;; Because I wish I had @-expressions
  (define (expand/display str [table (hash #"name" name #"user" user
                                           #"====" ==== #"year" year
                                           #"sanitized-name"
                                           sanitized-name)])
    (let ([in (open-input-string str)])
      (let loop ()
        (let ([m (regexp-match #rx"<<([^>]*)>>" in 0 #f (current-output-port))])
          (when m
            (display (hash-ref table (cadr m)))
            (loop))))))

  ;; Initialize the new package
  (cond
   [(directory-exists? name)
    (pkg-error (format "cannot make package, folder exists~n  path: ~a" name))]
   [(not (package-name? name))
    (pkg-error (format "cannot make package, invalid collection name~n  name:  ~a"
                       name))]
   [else
    (make-directory name)
    (parameterize ([current-directory name])

      ;; LICENSE.txt
      (with-output-to-file "LICENSE.txt"
        (lambda () (expand/display #<<EOS
<<name>>
Copyright (c) <<year>> <<user>>

This package is distributed under the GNU Lesser General Public
License (LGPL).  This means that you can link <<name>> into proprietary
applications, provided you follow the rules stated in the LGPL.  You
can also modify this package; if you distribute a modified version,
you must distribute it under the terms of the LGPL, which in
particular means that you must release the source code for the
modified software.  See http://www.gnu.org/copyleft/lesser.html
for more information.

EOS
)))

      ;; .gitignore
      (with-output-to-file ".gitignore"
        (lambda () (display #<<EOS
*~
\#*
.\#*
.DS_Store
compiled

EOS
)))

      ;; .travis.yml
      (with-output-to-file ".travis.yml"
        (lambda () (display #<<EOS
language: c

# Supply at least one RACKET_VERSION environment variable definition
# here. RACKET_VERSION is used by the install-racket.sh script
# (specifed below under before_install) to select the version of
# Racket to download and install.
#
# If you supply more than one, you can create multiple builds (a
# Travis-CI build matrix resulting in multiple builds). You can use
# this to test against multiple Racket versions.
env:
 - RACKET_VERSION=6.0
 - RACKET_VERSION=6.0.1
 - RACKET_VERSION=6.1
 - RACKET_VERSION=6.1.1
 - RACKET_VERSION=HEAD

before_install:
- git clone https://github.com/greghendershott/travis-racket.git
- cat travis-racket/install-racket.sh | bash # pipe to bash not sh!

install:

before_script:

# Here supply steps such as raco make, raco test, etc.  Note that you
# need to supply /usr/racket/bin/ -- it's not in PATH. You can run
# `raco pkg install --deps search-auto <<name>>` to install any required
# packages without it getting stuck on a confirmation prompt.
script:
 - /usr/racket/bin/raco make main.rkt
 - /usr/racket/bin/raco test -x .

# NOTE: If your repo is a Racket package with an info.rkt that
# includes some `deps`, the following is more elegant:
#
# script:
# - cd ..   # Travis did a cd into the dir. Back up, for the next:
# - /usr/racket/bin/raco pkg install --deps search-auto --link <<name>>
# - /usr/racket/bin/raco test -x -p <<name>>

after_script:

EOS
)))
      ;; info.rkt
      (with-output-to-file "info.rkt"
        (lambda () (expand/display #<<EOS
#lang info
(define collection "<<name>>")
(define deps '("base"
               "rackunit-lib"))
(define build-deps '("scribble-lib" "racket-doc"))
(define scribblings '(("scribblings/<<name>>.scrbl" ())))
(define pkg-desc "Description Here")
(define version "0.0")
(define pkg-authors '(<<user>>))

EOS
)))

      ;; README.md
      (with-output-to-file "README.md"
        (lambda () (expand/display #<<EOS
<<name>>
<<====>>
README text here.

EOS
)))

      ;; main.rkt
      (with-output-to-file "main.rkt"
(lambda () (display #<<EOS
#lang racket/base

(module+ test
  (require rackunit))

;; Notice
;; To install (from within the package directory):
;;   $ raco pkg install
;; To install (once uploaded to pkgs.racket-lang.org):
;;   $ raco pkg install <<name>>
;; To uninstall:
;;   $ raco pkg remove <<name>>
;; To view documentation:
;;   $ raco doc <<name>>
;;
;; For your convenience, we have included a LICENSE.txt file, which links to
;; the GNU Lesser General Public License.
;; If you would prefer to use a different license, replace LICENSE.txt with the
;; desired license.
;;
;; Some users like to add a `private/` directory, place auxiliary files there,
;; and require them in `main.rkt`.
;;
;; See the current version of the racket style guide here:
;; http://docs.racket-lang.org/style/index.html

;; Code here

(module+ test
  ;; Tests to be run with raco test
  )

(module+ main
  ;; Main entry point, executed when run with the `racket` executable or DrRacket.
  )

EOS
)))
      (make-directory "scribblings")
      (parameterize ([current-directory "scribblings"])

        ;; scribblings/name.scrbl
        (with-output-to-file (format "~a.scrbl" name)
          (lambda () (expand/display #<<EOS
#lang scribble/manual
@require[@for-label[<<sanitized-name>>
                    racket/base]]

@title{<<name>>}
@author{<<user>>}

@defmodule[<<sanitized-name>>]

Package Description Here

EOS
)))))]))
