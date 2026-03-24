;;; arxane.el --- Description -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Oliver McLaughlin
;;
;; Author: Oliver McLaughlin <olwmcjp@gmail.com>
;; Maintainer: Oliver McLaughlin <olwmcjp@gmail.com>
;; Created: March 20, 2026
;; Modified: March 20, 2026
;; Version: 0.0.1
;; Keywords: files
;; Homepage: https://github.com/olwmc/arxane
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Description
;;
;;; Code:
(require 'xml)
(require 'evil-commands)
(require 'pdf-view)

;; Parse out the xml response from url-retrive-synchronously
(defun arxane-parse-xml-response-buffer (buffer)
   (with-current-buffer buffer
      (goto-char (point-min))
      ;; Skip past the HTTP headers to the XML body
      (search-forward "\n\n")
      (let ((feed-xml (nth 0 (xml-parse-region (point) (point-max)))))
        (kill-buffer buffer)
        feed-xml)))

(defun arxane-get-feed ()
  "Return a feed in xml format."
  (let ((response-buffer (url-retrieve-synchronously "http://rss.arxiv.org/atom/cs.cl")))
    (arxane-parse-xml-response-buffer response-buffer)))

;; https://info.arxiv.org/help/atom_specifications.html
(defun arxane-parse-entry (entry)
  (let
      ((title (caddar(xml-get-children entry 'title)))
       (link (xml-get-attribute (car (xml-get-children entry 'link)) 'href))
       (summary (caddar(xml-get-children entry 'summary)))
       (author (caddar(xml-get-children entry 'dc:creator))))
    (list 'title title 'link link 'summary summary 'author author)))

(defun arxane-format-column (string width)
  (let ((len (length string)))
    (cond
     ((< len width) (substring (concat string (make-string (- width len) ?\s)) 0 width)
     ((> len width) (substring string 0 width))
     (string))))

(defun arxane-insert-item (item)
  (let* ((name    (arxane-format-column (plist-get item 'title)))
         (author  (arxane-format-column (plist-get item 'author) 30))
         (link    (plist-get item 'link))       ; was copying author
         (summary (plist-get item 'summary))
         (start   (point)))
    (insert (propertize name   'face 'bold))
    (insert " ")
    (insert (propertize author 'face 'italic))
    (insert "\n")
    (put-text-property start (point) 'summary summary)
    (put-text-property start (point) 'link    link)))  ; both inside let*

(defun arxane-get-entries ()
  (mapcar #'arxane-parse-entry (xml-get-children (arxane-get-feed) 'entry)))

(defvar arxane-summary-mode-map
  (let ((map (make-sparse-keymap)))
    map))

(define-derived-mode arxane-summary-mode special-mode "Arxane-Summary"
  "Major mode for Arxane summary view."
  (setq-local word-wrap t)
  (visual-line-mode 1))

(defun arxane-summary-open-link ()
  (interactive)
  (let ((link (get-text-property (point) 'link)))
    (browse-url link)))

(defun arxane-summary-open-pdf ()
  (interactive)
  (let* ((article_link (get-text-property (point) 'link))
         (pdf_link (concat "https://arxiv.org/pdf/" (nth 4 (split-string article_link "/")))))
    (let ((response-buffer (url-retrieve-synchronously pdf_link)))
      ;; Kill the summary window so we don't leak memory
      ;; Swap to the new one
      (switch-to-buffer response-buffer)
      (kill-buffer "*arxane-summary*")))

  ;; Now in the pdf buffer
  (search-forward "%PDF")
  (delete-region (point-min) (- (point) 4))
  (pdf-view-mode))

(evil-define-key 'normal arxane-summary-mode-map (kbd "q") #'arxane-kill-summary-window)
(evil-define-key 'normal arxane-summary-mode-map (kbd "RET") #'arxane-kill-summary-window)
(evil-define-key 'normal arxane-summary-mode-map (kbd "o") #'arxane-summary-open-link)
(evil-define-key 'normal arxane-summary-mode-map (kbd "p") #'arxane-summary-open-pdf)

(defun arxane-show-summary ()
  (interactive)
  (let ((summary (get-text-property (point) 'summary))
         (link (get-text-property (point) 'link)))
    (if (not summary)
        (message "No entry at point")
      (let ((buf (get-buffer-create "*arxane-summary*"))
            (line-start (line-beginning-position))
            (line-end   (line-end-position)))
        (with-current-buffer buf
          (erase-buffer)
          (insert (propertize summary 'link link))
          (goto-char (point-min))
          (arxane-summary-mode))
        (let ((inhibit-read-only t))
          (remove-text-properties line-start line-end '(face nil)))
        (select-window
          (display-buffer buf
            '(display-buffer-in-side-window
              (side . right)
              (window-width . 0.4))))))))

(defun arxane-kill-summary-window ()
  (interactive)
  (when-let ((win (get-buffer-window "*arxane-summary*")))
    (delete-window win))
  (kill-buffer "*arxane-summary*")
  (next-line))

(defvar arxane-mode-map
  (let ((map (make-sparse-keymap)))
    map))

(define-derived-mode arxane-mode special-mode "Arxane"
  "Major mode for Arxane.")

(evil-define-key 'normal arxane-mode-map (kbd "RET") #'arxane-show-summary)

(defun arxane ()
  "Create the arxane buffer."
  (interactive)
  (if (get-buffer "arxane")
      (switch-to-buffer "arxane")
    (with-current-buffer (get-buffer-create "arxane")
      (erase-buffer)
      (dolist (entry (arxane-get-entries))
        (arxane-insert-item entry))
      (arxane-mode)
      (evil-goto-first-line)
      (switch-to-buffer (current-buffer)))))

(provide 'arxane)
;;; arxane.el ends here
