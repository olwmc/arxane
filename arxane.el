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
(require 'org)

;;; ---------------------------------------------------------------------------
;;; Customization
;;; ---------------------------------------------------------------------------
(defcustom arxane-reading-list (expand-file-name "arxane-reading-list.org" org-directory)
  "File for storing the Arxane reading list."
  :type 'file)

(defcustom arxane-score-p nil
  "Whether or not to score on startup"
  :type 'boolean)

;;; ---------------------------------------------------------------------------
;;; Global entries state
;;; ---------------------------------------------------------------------------
(defvar-local arxane-entries nil
  "List of entries for the current arxane buffer.")

;;; ---------------------------------------------------------------------------
;;; Feed Parsing
;;; ---------------------------------------------------------------------------
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
  (let ((response-buffer (url-retrieve-synchronously "https://rss.arxiv.org/atom/cs.cl")))
    (arxane-parse-xml-response-buffer response-buffer)))

;; https://info.arxiv.org/help/atom_specifications.html
(defun arxane-parse-entry (entry)
  (let
      ((title (caddar(xml-get-children entry 'title)))
       (link (xml-get-attribute (car (xml-get-children entry 'link)) 'href))
       (summary (caddar(xml-get-children entry 'summary)))
       (author (caddar(xml-get-children entry 'dc:creator))))
    (list 'title title 'link link 'summary summary 'author author 'score 0)))

(defun arxane-get-entries ()
  (mapcar #'arxane-parse-entry (xml-get-children (arxane-get-feed) 'entry)))

;;; ---------------------------------------------------------------------------
;;; Display Helpers
;;; ---------------------------------------------------------------------------
(defun arxane-format-column (string width)
  (let ((len (length string)))
    (cond
     ((< len width) (concat string (make-string (- width len) ?\s)))
     ((> len width) (substring string 0 width))
     (string))))

(defun arxane-insert-item (item idx)
  (let* ((name    (plist-get item 'title))
         (author  (arxane-format-column (plist-get item 'author) 30))
         (score   (plist-get item 'score))
         (start   (point)))

    (when arxane-score-p
      (insert
       (propertize (concat "["(number-to-string score) "]") 'face '(:background "blue" :foreground "white")))
      (insert " "))

    (insert (propertize name   'face 'bold))
    (insert " ")
    (insert (propertize author 'face 'italic))
    (insert "\n")
    (put-text-property start (point) 'idx idx)))

;;; ---------------------------------------------------------------------------
;;; Summary mode
;;; ---------------------------------------------------------------------------
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
  (let* ((article-link (get-text-property (point) 'link))
         (pdf-link (concat "https://arxiv.org/pdf/"
                           (nth 4 (split-string article-link "/"))))
         (tmp-file (make-temp-file "arxane-" nil ".pdf")))
    (url-copy-file pdf-link tmp-file t)
    (kill-buffer "*arxane-summary*")
    (let ((buf (find-file-noselect tmp-file)))
      (with-current-buffer buf
        (pdf-view-mode)
        (evil-define-key 'normal pdf-view-mode-map (kbd "q")
          (lambda () (interactive)
            (kill-buffer buf)
            (delete-window))))
      (select-window
       (display-buffer buf
                       '(display-buffer-in-side-window
                         (side . right)
                         (window-width . 0.6)))))))

(evil-define-key 'normal arxane-summary-mode-map (kbd "q") #'arxane-kill-summary-window)
(evil-define-key 'normal arxane-summary-mode-map (kbd "RET")
  (lambda ()
    (interactive)
    (arxane-kill-summary-window)
    (forward-line 1)
    (arxane-show-summary)))

(evil-define-key 'normal arxane-summary-mode-map (kbd "j")
  (lambda ()
    (interactive)
    (arxane-kill-summary-window)
    (forward-line 1)
    (arxane-show-summary)))

(evil-define-key 'normal arxane-summary-mode-map (kbd "k")
  (lambda ()
    (interactive)
    (arxane-kill-summary-window)
    (forward-line -1)
    (arxane-show-summary)))

(evil-define-key 'normal arxane-summary-mode-map (kbd "o") #'arxane-summary-open-link)
(evil-define-key 'normal arxane-summary-mode-map (kbd "p") #'arxane-summary-open-pdf)
(evil-define-key 'normal arxane-summary-mode-map (kbd "m")
  (lambda ()
    (interactive)
    (arxane-kill-summary-window)
    (with-current-buffer (get-buffer "arxane-arxiv")
      (arxane-toggle-mark-entry))
    (arxane-show-summary)))

(defun arxane-show-summary ()
  (interactive)
  (let* ((entry (nth (get-text-property (point) 'idx) arxane-entries))
         (summary (plist-get entry 'summary))
         (link (plist-get entry 'link))
         (title (plist-get entry 'title)))
    (if (not summary)
        (message "No entry at point")
      (let ((buf (get-buffer-create "*arxane-summary*"))
            (line-start (line-beginning-position))
            (line-end   (line-end-position)))
        (with-current-buffer buf
          (erase-buffer)
          (insert (propertize title 'face 'bold 'link link))
          (insert "\n")
          (insert (propertize summary 'link link))
          (goto-char (point-min))
          (arxane-summary-mode))
        (let ((inhibit-read-only t))
          (remove-text-properties line-start line-end '(face nil)))
        (select-window
         (display-buffer buf
                         '(display-buffer-in-side-window
                           (side . right)
                           (window-width . 0.6))))))))

(defun arxane-kill-summary-window ()
  (interactive)
  (when-let ((win (get-buffer-window "*arxane-summary*")))
    (delete-window win))
  (when (get-buffer "*arxane-summary*")
    (kill-buffer "*arxane-summary*")))

;;; ---------------------------------------------------------------------------
;;; Article Scoring
;;; ---------------------------------------------------------------------------
(defun arxane--score-entry (entry)
  (let
      ((title (plist-get entry 'title))
       (link  (plist-get entry 'link))
       (summary (plist-get entry 'summary))
       (author (plist-get entry 'author)))
    (plist-put entry 'score (random 200))))

(defun arxane--compare-scores (e1 e2)
  (> (plist-get e1 'score) (plist-get e2 'score)))

;;; ---------------------------------------------------------------------------
;;; Arxane Mode
;;; ---------------------------------------------------------------------------
(defvar arxane-mode-map
  (let ((map (make-sparse-keymap)))
    map))

(define-derived-mode arxane-mode special-mode "Arxane"
  "Major mode for Arxane.")

(evil-define-key 'normal arxane-mode-map (kbd "RET") #'arxane-show-summary)
(evil-define-key 'normal arxane-mode-map (kbd "m") #'arxane-toggle-mark-entry)
(evil-define-key 'normal arxane-mode-map (kbd "x") #'arxane-export-marked-items)

(defun arxane-toggle-mark-entry ()
  (interactive)
  (let ((idx (get-text-property (point) 'idx)))
        (if (not idx)
            (message "No entry at point")
          (let* ((line-start (line-beginning-position))
                 (line-end   (line-end-position))
                 (entry (nth idx arxane-entries))
                 (marked (plist-get entry 'marked)))
            (let ((inhibit-read-only t))
              (if (not marked)
                  (progn
                    (put-text-property line-start line-end 'face '(:foreground "yellow"))
                    (setf (plist-get (nth idx arxane-entries) 'marked) t)
                    (message "Entry marked!"))
                (progn
                  (put-text-property line-start line-end 'face '(:foreground "white"))
                  (setf (plist-get (nth idx arxane-entries) 'marked) nil)
                  (message "Entry unmarked!"))))
            (forward-line 1)))))

(defun arxane-export-marked-items ()
  (interactive)
  (when (y-or-n-p "Are you sure you want to export the marked items?")
    (let ((entries arxane-entries))
      (with-current-buffer (find-file-noselect arxane-reading-list)
        (goto-char (point-max))
        (insert (format "\n* %s\n" (format-time-string "%Y-%m-%d")))
        (dolist (res (seq-filter (lambda (e) (plist-get e 'marked)) entries))
          (let ((title (plist-get res 'title ))
                (link (plist-get res 'link ))
                (summary (plist-get res 'summary ))
                (author (plist-get res 'author )))
            (goto-char (point-max))
            (insert (format "\n** TODO %s\n%s\n%s\n%s\n\n" title link author summary))
            (save-buffer)))))))

(defun arxane--refresh ()
  (let ((inhibit-read-only t))
    (erase-buffer)
    (if arxane-entries
        (seq-do-indexed (lambda (entry idx)
                          (arxane-insert-item entry idx)) arxane-entries)
      (insert "No entries today"))))

(defun arxane ()
  "Create the arxane buffer."
  (interactive)
  (if (get-buffer "arxane-arxiv")
      (switch-to-buffer "arxane-arxiv")
    (with-current-buffer (get-buffer-create "arxane-arxiv")
      (arxane-mode)
      (setq arxane-entries
            (let ((raw (arxane-get-entries)))
              (if arxane-score-p
                  (sort (mapcar #'arxane--score-entry raw) #'arxane--compare-scores)
                raw)))
      (arxane--refresh)
      (evil-goto-first-line)
      (switch-to-buffer (current-buffer)))))

(provide 'arxane)
;;; arxane.el ends here
