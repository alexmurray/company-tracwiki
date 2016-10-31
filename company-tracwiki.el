;;; company-trac --- Company backend for tracwiki

;;; Commentary:

;;; Code:

(require 'tracwiki-mode)

(defvar company-tracwiki-ticket-cache nil)

(defun company-tracwiki-rpc-get-ticket-title (id &optional endpoint)
  "Get the title of ticket ID in remote site of ENDPOINT.
If optional argument EP is nil, use `trac-rpc-endpoint' is used."
  (let ((trac-rpc-endpoint (or endpoint trac-rpc-endpoint)))
    (let ((details (trac-rpc-call 'ticket.get id)))
      (if details
          (cdr-safe (assoc "summary" (nth 3 details)))
        ""))))

(defun company-tracwiki-rpc-get-all-tickets (&optional endpoint)
  "Get list of tickets available in remote site of ENDPOINT.
If optional argument EP is nil, use `trac-rpc-endpoint' is used."
  (message "Getting all tickets....")
  (let ((trac-rpc-endpoint (or endpoint trac-rpc-endpoint)))
    (trac-rpc-call 'ticket.query)))

(defun company-tracwiki-update-ticket-cache ()
  "Update cache of wiki tickets."
  (interactive)
  (prog1
      (tracwiki-with-cache
          'company-tracwiki-ticket-cache
          trac-rpc-endpoint 'update
        (company-tracwiki-rpc-get-all-tickets))
    (if (interactive-p)
        (message "Ticket cache is updated."))))

(defun company-tracwiki-get-ticket-title (ticket)
  "Get title for TICKET."
  (let ((title (get-text-property 0 'title candidate)))
    (unless title
      (setq title
            (company-tracwiki-rpc-get-ticket-title (string-to-number ticket)))
      (propertize ticket 'title title))
    title))

(defun company-tracwiki--candidates (prefix)
  "Get candidates matching PREFIX."
  (let (res)
    (unless trac-rpc-endpoint
      (setq tracwiki-project-info (tracwiki-ask-project)
            trac-rpc-endpoint (plist-get tracwiki-project-info :endpoint)))
    (dolist (ticket (tracwiki-with-cache
                        'company-tracwiki-ticket-cache
                        trac-rpc-endpoint nil
                      (company-tracwiki-rpc-get-all-tickets)))
      (let ((ticket-str (number-to-string ticket)))
        (when (string-prefix-p prefix ticket-str)
          (push ticket-str res))))
    res))

(defun company-tracwiki--meta (candidate)
  "Get meta for CANDIDATE."
  (company-tracwiki-get-ticket-title candidate))

(defun company-tracwiki--annotation (candidate)
  "Get annotation for CANDIDATE."
  (let ((title (company-tracwiki-get-ticket-title candidate)))
    (format " %s" title)))

(defun company-tracwiki--doc-buffer (candidate)
  "Get doc-buffer for CANDIDATE."
  (company-doc-buffer (company-tracwiki-get-ticket-title candidate)))

(defun company-tracwiki--prefix ()
  "Grab prefix at point."
  (let ((prefix (company-grab-symbol-cons "#" 1)))
    (if (listp prefix)
        (car prefix)
      (let ((symbol (company-grab-symbol)))
        (message symbol)
        (if (string-prefix-p "ticket:" symbol)
            (substring symbol 7)
          nil)))))

;;;###autoload
(defun company-tracwiki (command &optional arg &rest ignored)
  "Company backend for tracwiki to complete for COMMAND with ARG and IGNORED."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-tracwiki))
    (prefix (company-tracwiki--prefix))
    (candidates (company-tracwiki--candidates arg))
    (annotation (company-tracwiki--annotation arg))
    (meta (company-tracwiki--meta arg))
    (doc-buffer (company-tracwiki--doc-buffer arg))))

(provide 'company-tracwiki)

;;; company-tracwiki.el ends here
