;;; md-preview.el --- Live markdown preview with pandoc -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Karim Aziiev <karim.aziiev@gmail.com>

;; Author: Karim Aziiev <karim.aziiev@gmail.com>
;; URL: https://github.com/KarimAziev/md-preview
;; Version: 0.1.0
;; Keywords: tools outlines
;; Package-Requires: ((emacs "24.3") (impatient-mode "1.1") (simple-httpd "1.5.1") (markdown-mode "2.5"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Live markdown preview with pandoc

;;; Code:

(require 'impatient-mode)
(require 'simple-httpd)
(require 'markdown-mode)

(defcustom md-preview-html-template "<!DOCTYPE html>\n<html>\n  <title>Markdown preview</title\n  ><link\n    rel=\"stylesheet\"\n    href=\"https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/3.0.1/github-markdown.min.css\"\n  />\n  <link\n    rel=\"stylesheet\"\n    href=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.5.1/styles/default.min.css\"\n  />\n  <script src=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.5.1/highlight.min.js\"></script>\n  <script type=\"text/javascript\">\n    document.addEventListener('DOMContentLoaded', (event) => {\n      document.querySelectorAll('pre code').forEach((el) => {\n        hljs.highlightElement(el);\n      });\n    });\n  </script>\n  <body>\n    <article\n      class=\"markdown-body\"\n      style=\"\n        box-sizing: border-box;\n        min-width: 200px;\n        max-width: 980px;\n        margin: 0 auto;\n        padding: 45px;\n      \"\n    ></article>\n  </body>\n</html>\n"
  "HTML template for preview markdown.
It must contains article section."
  :group 'md-edit-org
  :type 'string)

(defun md-preview-inject-content (content)
  "Add CONTENT to `md-preview-html-template'."
  (with-temp-buffer
    (insert md-preview-html-template)
    (re-search-backward "</article" nil t 1)
    (insert content)
    (buffer-substring-no-properties (point-min)
                                    (point-max))))

(defun md-preview-markdown-filter (buffer)
  "Html-producing filter function per BUFFER."
  (princ
   (with-temp-buffer
     (let ((tmp (buffer-name)))
       (set-buffer buffer)
       (set-buffer (markdown tmp))
       (md-preview-inject-content
        (buffer-string))))
   (current-buffer)))

;;;###autoload
(defun md-preview ()
  "Live preview markdown with pandoc."
  (interactive)
  (setq-local markdown-command "pandoc -t html")
  (unless (process-status "httpd")
    (httpd-start))
  (impatient-mode)
  (imp-set-user-filter 'md-preview-markdown-filter)
  (imp-visit-buffer))

(provide 'md-preview)
;;; md-preview.el ends here