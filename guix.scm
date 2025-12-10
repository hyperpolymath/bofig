;; bofig - Guix Package Definition
;; Run: guix shell -D -f guix.scm

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system mix)
             ((guix licenses) #:prefix license:)
             (gnu packages base))

(define-public bofig
  (package
    (name "bofig")
    (version "0.1.0")
    (source (local-file "." "bofig-checkout"
                        #:recursive? #t
                        #:select? (git-predicate ".")))
    (build-system mix-build-system)
    (synopsis "Elixir application")
    (description "Elixir application - part of the RSR ecosystem.")
    (home-page "https://github.com/hyperpolymath/bofig")
    (license license:agpl3+)))

;; Return package for guix shell
bofig
