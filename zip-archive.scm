
(define-module zip-archive
  (use srfi-11)
  (use srfi-19)
  (use rfc.zlib)
  (use binary.pack)
  (use gauche.collection)
  (use gauche.record)
  (export <output-zip-archive>
          open-output-zip-archive
          open-input-zip-archive
          zip-close
          call-with-output-zip-archive
          call-with-input-zip-archive
          zip-add-entry
          zip-entries
          zip-entry-timestamp
          zip-entry-datasize
          zip-entry-filename
          zip-entry-body
          zip-entry?
          input-zip-archive?
          output-zip-archive?))

(select-module zip-archive)

(define (date->dos-format date)
  (let* ((year (date-year date))
         (month (date-month date))
         (day (date-day date))
         (hour (date-hour date))
         (minute (date-minute date))
         (second (date-second date)))
    (+ (ash (- year 1980) 25) (ash month 21) (ash day 16)
       (ash hour 11) (ash minute 5) (quotient second 2))))

(define (dos-format->date df-date)
  (let ((year (+ 1980 (logand (ash df-date -25) #b1111111)))
        (month (logand (ash df-date -21) #b1111))
        (day (logand (ash df-date -16) #b11111))
        (hour (logand (ash df-date -11) #b11111))
        (minute (logand (ash df-date -5) #b111111))
        (second (ash (logand df-date #b11111) 1)))
    (make-date 0 second minute hour day month year 0)))

(define-record-type zip-entry #t #t
  (#:archive         zip-entry-archive)
  (#:compress-method zip-entry-compress-method)
  (#:timestamp       zip-entry-timestamp)
  (#:checksum        zip-entry-checksum)
  (#:compressed-size zip-entry-compressed-size)
  (#:datasize        zip-entry-datasize)
  (#:offset          zip-entry-offset)
  (#:filename        zip-entry-filename))

(define-class <zip-archive> ()
  ((#:port :init-keyword :port :accessor zip-archive-port)
   (#:name :init-keyword :name :accessor zip-archive-name)
   (#:entries :init-keyword :entries
              :accessor zip-archive-entries
              :init-form '())))

(define-class <output-zip-archive> (<zip-archive>)
  ((#:tempname :init-keyword :tempname :accessor zip-archive-tempname)
   (#:timestamp :init-form (current-date) :getter zip-archive-timestamp)))

(define (output-zip-archive? obj)
  (is-a? obj <output-zip-archive>))

(define-class <input-zip-archive> (<zip-archive> <collection>)
  ())

(define (input-zip-archive? obj)
  (is-a? obj <input-zip-archive>))

(define (write-pk0304 entry)
  (pack "VvvvVVVVvva*"
    (list #x04034b50
          20
          2048
          (zip-entry-compress-method entry)
          (date->dos-format (zip-entry-timestamp entry))
          (zip-entry-checksum entry)
          (zip-entry-compressed-size entry)
          (zip-entry-datasize entry)
          (string-size (zip-entry-filename entry))
          0
          (zip-entry-filename entry))
    :output (zip-archive-port (zip-entry-archive entry))))

(define-method initialize ((obj <output-zip-archive>) initargs)
  (next-method obj '())
  (let-keywords initargs
      ((filename :name #f) . restargs)
    (unless filename
      (error "<output-zip-archive> class requires :name argument in initialization"))
    (set! (zip-archive-name obj) filename)
    (receive (port tempname)
        (sys-mkstemp (string-append (sys-dirname filename) "/ziptmp"))
      (set! (zip-archive-port obj)  port)
      (set! (zip-archive-tempname obj) tempname))))

(define (open-output-zip-archive filename)
  (make <output-zip-archive> :name filename))

(define-method zip-add-entry
    ((archive <output-zip-archive>) (name <string>) (content <string>)
     :key (timestamp (zip-archive-timestamp archive))
          (compression-level Z_DEFAULT_COMPRESSION))
  (let* ((position (port-tell (zip-archive-port archive)))
         (compress-method (if (= compression-level Z_NO_COMPRESSION) 0 8))
         (compressed
          (if (= compress-method 0)
              content
              (deflate-string content
                :window-bits -15
                :compression-level compression-level)))
         (entry
          (make-zip-entry
           archive
           compress-method
           timestamp
           (crc32 content)
           (string-size compressed)
           (string-size content)
           position
           name)))
    (write-pk0304 entry)
    (display compressed (zip-archive-port archive))
    (push! (zip-archive-entries archive) entry)))

(define (write-pk0102 entry)
  (pack "VvvvvVVVVvvvvvVVa*"
    (list #x02014b50 20 20 2048
          (zip-entry-compress-method entry)
          (date->dos-format (zip-entry-timestamp entry))
          (zip-entry-checksum entry)
          (zip-entry-compressed-size entry)
          (zip-entry-datasize entry)
          (string-size (zip-entry-filename entry))
          0 0 0 0 0
          (zip-entry-offset entry)
          (zip-entry-filename entry))
    :output (zip-archive-port (zip-entry-archive entry))))

(define-method %zip-close ((archive <output-zip-archive>))
  (let ((cd (port-tell (zip-archive-port archive)))
        (num (length (zip-archive-entries archive))))
    (for-each write-pk0102 (reverse (zip-archive-entries archive)))
    (let1 eoc (port-tell (zip-archive-port archive))
      (pack "VvvvvVVv"
        (list #x06054b50 0 0 num num (- eoc cd) cd 0)
        :output (zip-archive-port archive)))
    (close-output-port (zip-archive-port archive)))
  (sys-rename (zip-archive-tempname archive) (zip-archive-name archive)))

(define-method %zip-close ((archive <input-zip-archive>))
  (close-input-port (zip-archive-port archive)))

(define (zip-close archive)
  (%zip-close archive))

(define (call-with-output-zip-archive filename proc)
  (let1 archive (open-output-zip-archive filename)
    (guard (e (else (close-output-port (zip-archive-port archive))
                    (sys-unlink (zip-archive-tempname archive))
                    (raise e)))
      (proc archive)
      (zip-close archive))))

(define (read-entry archive)
  (let*-values (((port) (zip-archive-port archive))
                ((signature version option compress-method
                  timestamp crc32 compressed-size uncompressed-size
                  filename-size ext-field-len)
                 (apply values (unpack "VvvvVVVVvv" :input port))))
    (if (= #x04034b50 signature)
        (let1 filename (read-string filename-size port)
          (port-seek port ext-field-len SEEK_CUR)
          (make-zip-entry
           archive
           compress-method
           (dos-format->date timestamp)
           crc32
           compressed-size
           uncompressed-size
           (port-tell port)
           filename))
        #f)))

(define (read-entries archive)
  (let1 port (zip-archive-port archive)
    (do ((header (read-entry archive) (read-entry archive))
         (headers '() (cons header headers)))
        ((not header) (reverse! headers))
      (port-seek port (zip-entry-compressed-size header) SEEK_CUR))))

(define (open-input-zip-archive filename)
  (let* ((port (open-input-file filename))
         (archive (make <input-zip-archive> :port port :name filename)))
    (set! (zip-archive-entries archive) (read-entries archive))
    archive))

(define (call-with-input-zip-archive filename proc)
  (let1 archive (open-input-zip-archive filename)
    (guard (e (else (close-input-port (zip-archive-port archive))
                    (raise e)))
      (proc archive)
      (zip-close archive))))

(define (zip-entries archive)
  (zip-archive-entries archive))

(define-method call-with-iterator
    ((archive <input-zip-archive>) proc . options)
  (apply call-with-iterator (zip-entries archive) proc options))

(define (zip-entry-body entry)
  (let* ((archive (zip-entry-archive entry))
         (port (zip-archive-port archive))
         (position (zip-entry-offset entry)))
    (port-seek port position SEEK_SET)
    (let* ((body (read-block (zip-entry-compressed-size entry) port)))
      ((if (zero? (logand 8 (zip-entry-compress-method entry)))
           values
           (cut inflate-string <> :window-bits -15))
       body))))

(provide "zip-archive")
