#!/usr/bin/env gosh
(use zip-archive)
(use rfc.zlib)

(define za (open-output-zip-archive "test.zip"))
(zip-add-entry za "1.txt" "number one.")
(zip-add-entry za "2.txt" "number two.")
(zip-add-entry za "3.txt" "number three." :compression-level Z_NO_COMPRESSION)
(zip-close za)

(call-with-output-zip-archive "test2.zip"
  (lambda(za)
    (zip-add-entry za "one.txt" "number 1.")
    (zip-add-entry za "two.txt" "number 2.")
    (zip-add-entry za "three.txt" "number 3.")))

(call-with-output-zip-archive "test3.zip"
  (lambda(za)
    (zip-add-entry za "eins.txt" "number 1.")
    (zip-add-entry za "twei.txt" "number 2.")
    (error "It's error test.")
    (zip-add-entry za "drei.txt" "number 3.")))
