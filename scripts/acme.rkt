#!/usr/bin/env racket
#lang racket
; Copyright (C) 2026  wormt <209373679+wormt@users.noreply.github.com>
; SPDX-License-Identifier: AGPL-3.0-or-later
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU Affero General Public License for more details.
;
; You should have received a copy of the GNU Affero General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(require ffi/unsafe
  racket/file
  racket/system)

(unless (zero? ((get-ffi-obj "geteuid" (ffi-lib #f) (_fun -> _int))))
  (error 'acme "Must run as root."))

(define umask! (get-ffi-obj "umask" (ffi-lib #f) (_fun _uint -> _uint)))
(umask! #o077)

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

(umask! #o022)

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
   "-c"
   "/etc/nginx/nginx.conf"
   "-s"
   "reload"
   ))(error 'acme "nginx reload failed"))
