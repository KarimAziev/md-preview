;;; md-preview.el --- Live markdown preview with pandoc -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Karim Aziiev <karim.aziiev@gmail.com>

;; Author: Karim Aziiev <karim.aziiev@gmail.com>
;; URL: https://github.com/KarimAziev/md-preview
;; Version: 0.1.0
;; Keywords: tools outlines
;; Package-Requires: ((emacs "26.1") (impatient-mode "1.1") (simple-httpd "1.5.1") (markdown-mode "2.6-alpha"))

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
(require 'xwidget nil t)

(defconst md-preview--home-dir (file-name-directory
                                (or load-file-name buffer-file-name))
  "Directory with `md-preview'.")

(defcustom md-preview-html-template (with-temp-buffer
                                      (insert-file-contents
                                       (expand-file-name
                                        "index.html"
                                        md-preview--home-dir))
                                      (buffer-string))
  "HTML template for preview markdown.
It must contains article section."
  :group 'md-preview
  :type 'string)

(defcustom md-preview-enable-xwidget-webkit-p (and
                                               window-system
                                               (featurep 'xwidget-internal))
  "If non-nil, browse and sync with xwidget-webkit."
  :type 'boolean
  :group 'md-preview)


(defun md-preview-xwidget-script (script)
  "Inject SCRIPT in existing xwidget session."
  (when-let* ((xwidget-sess (when (and  md-preview-enable-xwidget-webkit-p
                                        (xwidget-webkit-current-session))
                              (xwidget-webkit-current-session)))
              (url (xwidget-webkit-uri xwidget-sess)))
    (when (equal url
                 (md-preview-get-impatient-url))
      (xwidget-webkit-execute-script xwidget-sess script))))

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


(defun md-preview-get-word-to-search ()
  "Get word to search in webkit."
  (let ((re "a-zz-aA-Z-Z-A-0-9\\.\\+\s,'"))
    (save-excursion
      (string-join (split-string
                    (string-trim
                     (buffer-substring-no-properties
                      (+ (point)
                         (save-excursion
                           (skip-chars-backward
                            re)))
                      (+ (point)
                         (save-excursion
                           (skip-chars-forward
                            re)))))
                    "\n"  t)
                   "\s"))))

(defun md-preview-search ()
  "Search for current word in webkit."
  (let ((word (md-preview-get-word-to-search)))
    (when (>= (length (split-string word nil t)) 2)
      (xwidget-webkit-search word
                             (xwidget-webkit-current-session))
      (xwidget-webkit-finish-search (xwidget-webkit-current-session)))))

(defun md-preview-get-impatient-url ()
  "Visit the current buffer in a browser.
If given a prefix ARG, visit the buffer listing instead."
  (unless (process-status "httpd")
    (httpd-start))
  (unless impatient-mode
    (impatient-mode))
  (let* ((buff (current-buffer))
         (proc (get-process "httpd"))
         (proc-info (process-contact proc t))
         (raw-host (plist-get proc-info :host))
         (host (if (member raw-host
                           '(nil local "127.0.0.1" "::1" "0.0.0.0" "::"))
                   "localhost"
                 raw-host))
         (local-addr (plist-get proc-info :local))
         (port (aref local-addr (1- (length local-addr))))
         (url (format "http://%s:%d/imp/" host port)))
    (format "%slive/%s/" url (url-hexify-string (buffer-name buff)))))

(defun md-preview-visit-buffer ()
  "Visit the current buffer in a browser.
If given a prefix ARG, visit the buffer listing instead."
  (interactive)
  (unless (process-status "httpd")
    (httpd-start))
  (unless impatient-mode
    (impatient-mode))
  (let ((buff (current-buffer))
        (url (md-preview-get-impatient-url)))
    (if (not  md-preview-enable-xwidget-webkit-p)
        (browse-url url)
      (with-selected-window (get-buffer-window buff)
        (with-selected-window (or (window-right (selected-window))
                                  (window-left (selected-window))
                                  (split-window-right))
          (xwidget-webkit-browse-url url))
        (run-with-timer 1 nil 'md-preview-xwidget-script
                        "window.scrollBy = (a, b) => document.querySelector('iframe').contentWindow.scrollBy(a, b);")))))

;;;###autoload
(defun md-preview ()
  "Live preview markdown with pandoc."
  (interactive)
  (setq-local markdown-command "pandoc -t html")
  (unless (process-status "httpd")
    (httpd-start))
  (impatient-mode)
  (imp-set-user-filter 'md-preview-markdown-filter)
  (md-preview-visit-buffer))

(defun md-preview-xwidget-scroll-up-page ()
  "Inject SCRIPT for xwidget."
  (md-preview-xwidget-script
   "document.querySelector('iframe').contentWindow.scrollBy(0, -document.querySelector('iframe').contentWindow.innerHeight);"))

(defun md-preview-xwidget-scroll-down-page ()
  "Inject SCRIPT for xwidget."
  (md-preview-xwidget-script
   "document.querySelector('iframe').contentWindow.scrollBy(0, document.querySelector('iframe').contentWindow.innerHeight);"))

(defun md-preview-xwidget-goto-page (page)
  "Go to xwidget PAGE."
  (if (= page 0)
      (md-preview-xwidget-script
       "document.querySelector('iframe').contentWindow.scrollTo(0, 0);")
    (md-preview-xwidget-script
     (format
      "document.querySelector('iframe').contentWindow.scrollTo(0, 0);
document.querySelector('iframe').contentWindow.scrollBy(0, document.querySelector('iframe').contentWindow.innerHeight * %s);"
      page))))

(defun md-preview-scroll-to-the-end ()
  "Scroll to the end of xwidget page."
  (interactive)
  (md-preview-xwidget-script
   "document.querySelector('iframe').contentWindow.scrollTo(0, document.querySelector('iframe').contentWindow.document.body.scrollHeight);"))

(defun md-preview-scroll-to-the-top ()
  "Scroll to the beginning of xwidget page."
  (interactive)
  (md-preview-xwidget-script
   "document.querySelector('iframe').contentWindow.scrollTo(0, 0);"))


(defun md-preview-current-page ()
  "Return current page in markdown buffer."
  (let ((page-height (window-height)))
    (/ (count-lines (point-min)
                    (point))
       page-height)))

(defvar-local md-preview-window-prev-wind-start 1)
(defun md-preview-sync-xwidgets ()
  "Sync point in markdown buffer with xwidgets."
  (let ((prev-wstart md-preview-window-prev-wind-start))
    (setq md-preview-window-prev-wind-start (window-start))
    (pcase this-command
      ('end-of-buffer
       (md-preview-xwidget-script
        "document.querySelector('iframe').contentWindow.scrollTo(0, document.querySelector('iframe').contentWindow.document.body.scrollHeight);"))
      ('beginning-of-buffer
       (md-preview-xwidget-script
        "document.querySelector('iframe').contentWindow.scrollTo(0, 0);"))
      ('scroll-up-command
       (md-preview-xwidget-scroll-down-page))
      ('scroll-down-command
       (md-preview-xwidget-scroll-up-page))
      (_
       (unless (equal prev-wstart md-preview-window-prev-wind-start)
         (md-preview-xwidget-goto-page (md-preview-current-page)))))))

(define-minor-mode md-preview-mode
  "Minor mode `md-preview-mode'."
  :lighter " md-live"
  (remove-hook 'post-command-hook 'md-preview-sync-xwidgets t)
  (if (not md-preview-mode)
      (httpd-stop)
    (setq md-preview-window-prev-wind-start 1)
    (when md-preview-enable-xwidget-webkit-p
      (add-hook 'post-command-hook 'md-preview-sync-xwidgets nil t))
    (md-preview)))

(provide 'md-preview)
;;; md-preview.el ends here