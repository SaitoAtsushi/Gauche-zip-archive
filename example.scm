
(use zip-archive)
(use rfc.zlib)

(define za (open-output-zip-archive "test.zip"))
(zip-add-entry za "1.txt" "number one.")
(zip-add-entry za "2.txt" "number two.")
(zip-add-entry za "3.txt" "number three." :compression-level Z_NO_COMPRESSION)
(zip-close za)
