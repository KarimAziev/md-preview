# md-preview

Live Markdown Preview.

## Requirements

  - Emacs \>= 24.3
  - [pandoc](https://pandoc.org/) program
  - impatient-mode
  - simple-httpd
  - markdown-mode

## Installation

### Manual

Install `md-preview` dependencies - `impatient-mode`, `simple-httpd` and
`markdown-mode`.

Download the source code of `md-preview` and put it wherever you like
and add the directory to the load path:

``` elisp

(add-to-list 'load-path "/path/to/md-preview)

(require 'md-preview)

```

### With use-package and straight

``` elisp

(use-package md-preview
    :straight (md-preview
                   :repo "KarimAziev/md-preview"
                   :type git
                   :host github)
    :commands (md-preview))

```

## Usage

Run in markdown buffer:

`M-x md-preview RET`.
