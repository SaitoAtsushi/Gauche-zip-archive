# Gauche-zip-archive

A library to read/write zip archive file.

## Requirements

- Gauche 0.9.5 pre1 or later

Install
Building from tarball

```
% ./configure
% make install
```

For windows without MSYS

```
> install.bat
```

## Usage

This library name is zip-archive.
Use it at first.

```
(use zip-archive)
```

## Procedures
Procedures that this library provides is two categories with roughly.
That is writing and reading.

### For writing

#### (open-output-zip-archive `string`)
Takes a `string` naming an output zip archive to be created and returns an output-zip-archive object.

#### (zip-close `output-zip-archive`)
Finanize the archive associated with `output-zip-archive`.

#### (zip-add-entry `output-zip-archive` `string1` `string2`)
Write entry that named `string1` into the file associated `output-zip-archive`.
The content of the entry is `string2`.
This is a generic function.

If you want to store an object other than string, be able to define a method.

#### (call-with-output-zip-archive `string` `proc`)
Open output zip archive that named `string` to write and call `proc` with _output-zip-archive_ object.
`proc` must receive one argument.

The _output-zip-archive_ object is closed automatically after return from `proc`.

##### (output-zip-archive? `obj`)

This procedure return #t if `obj` is _output-zip-archive_ object.
Otherwise this return #f.

### For reading

##### (open-input-zip-archive `string`)
Takes a `string` naming an input zip archive to be created and returns a _input-zip-archive_ object.

_input-zip-archive_ class is iherited `<collection>` class.
You can handle this as if it were a collection that contains the entry objects.
See [gauche.collection](http://practical-scheme.net/gauche/man/?l=en&p=gauche.collection).

#### (zip-close `input-zip-archive`)

Close the archive associated with `input-zip-archive`.

#### (call-with-input-zip-archive `string` `proc`)
Open the zip archive that named `string` for reading and call proc with _input-zip-archive_ object.
`proc` must receive one argument.

The _input-zip-archive_ object is closed automatically after return from `proc`.

#### (zip-entries `input-zip-archive`)

Returns a list of entry objects in the `input-zip-archive`.

_input-zip-archive_ object is collection.
You should not take entries from _input-zip-archive_ object explicitly by zip-entries.

#### (zip-entry-timestamp `zip-entry`)

Returns timestamp of `zip-entry` as a [date](http://practical-scheme.net/gauche/man/?l=en&p=%3Cdate%3E) object.

#### (zip-entry-datasize `zip-entry`)

Returns uncompressed size of content in `zip-entry`.
A size of the content is a number of bytes.

#### (zip-entry-filename `zip-entry`)

Returns filename of `zip-entry`.

#### (zip-entry-body `zip-entry`)

Inflate content of `zip-entry` and returns it as a string.
