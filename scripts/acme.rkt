#!/usr/bin/env racket
#lang racket

(require ffi/unsafe
  racket/file
  racket/system)

(unless (zero? ((get-ffi-obj "geteuid" (ffi-lib #f) (_fun -> _int))))
  (error 'acme "Must run as root."))

((get-ffi-obj "umask" (ffi-lib #f) (_fun _uint -> _uint)) #o077)

(unless (directory-exists? "/etc/nginx/certs/")
  (make-directory* "/etc/nginx/certs/")
  (file-or-directory-permissions "/etc/nginx/certs/" #o700))

(unless (file-exists? "/etc/nginx/certs/account.key")
  (unless (zero? (system*/exit-code
                   (find-executable-path "openssl")
                   "genrsa"
                   "-out"
                   "/etc/nginx/certs/account.key"
                   "4096"))
    (error 'acme "account key generation failed")))

(unless (file-exists? "/etc/nginx/certs/brainworm.homes.key")
  (unless (zero? (system*/exit-code
                   (find-executable-path "openssl")
                   "genrsa"
                   "-out"
                   "/etc/nginx/certs/brainworm.homes.key"
                   "4096"))
    (error 'acme "domain key generation failed")))

(unless (file-exists? "/etc/nginx/certs/brainworm.homes.csr")
  (unless (zero? (system*/exit-code
                   (find-executable-path "openssl")
                   "req"
                   "-new"
                   "-key"
                   "/etc/nginx/certs/brainworm.homes.key"
                   "-subj"
                   "/CN=brainworm.homes"
                   "-out"
                   "/etc/nginx/certs/brainworm.homes.csr"))
    (error 'acme "CSR generation failed")))

(when
    (and
     (file-exists? "/etc/nginx/certs/brainworm.homes.crt")
     (zero?
      (parameterize ([current-output-port (open-output-nowhere)]
                     [current-error-port (open-output-nowhere)])
        (system*/exit-code
         (find-executable-path "openssl")
         "x509"
         "-in"
         "/etc/nginx/certs/brainworm.homes.crt"
         "-noout"
         "-checkend"
         (number->string (* 30 86400))))))
  (exit 0))

(when (file-exists? "/etc/nginx/certs/brainworm.homes.crt.tmp")
  (delete-file "/etc/nginx/certs/brainworm.homes.crt.tmp"))

(call-with-output-file
 "/etc/nginx/certs/brainworm.homes.crt.tmp"
 (lambda (output)
   (parameterize ([current-output-port output])
     (unless (zero? (system*/exit-code
                      (find-executable-path "acme_tiny")
                      "--account-key"
                      "/etc/nginx/certs/account.key"
                      "--csr"
                      "/etc/nginx/certs/brainworm.homes.csr"
                      "--acme-dir"
                      "/var/www/challenges/"))
       (error 'acme "certificate issuance failed"))))
 #:exists 'error
 #:permissions #o600)

(rename-file-or-directory
  "/etc/nginx/certs/brainworm.homes.crt.tmp"
  "/etc/nginx/certs/brainworm.homes.crt"
  #t)

(file-or-directory-permissions "/etc/nginx/certs/brainworm.homes.crt" #o644)

(unless (zero? (system*/exit-code
  (find-executable-path "nginx")
   "-s"
   "reload"
   ))(error 'acme "nginx reload failed"))
