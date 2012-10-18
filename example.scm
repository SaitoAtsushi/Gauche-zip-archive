
(use zip-archive)
(use rfc.zlib)

(define za (open-output-zip-archive "test.zip"))
(zip-add-file za "1.txt" "number one.")
(zip-add-file za "2.txt" "number two.")
(zip-add-file za "3.txt" "number three." :compression-level Z_NO_COMPRESSION)
(zip-close za)
