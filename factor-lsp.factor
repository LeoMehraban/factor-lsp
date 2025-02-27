! Copyright (C) 2025 Your name.
! See https://factorcode.org/license.txt for BSD license.
USING: kernel json sequences math.parser unicode classes vocabs classes.parser accessors arrays calendar continuations io.files io.servers io.streams.c io.encodings.utf8 assocs quotations io math classes.predicate literals urls parser words generic hashtables strings factor-lsp.types summary tools.completion io.backend.unix source-files.errors source-files effects prettyprint math.order io.ports destructors io.encodings splitting tools.continuations factor-lsp.help io.encodings.string prettyprint.config byte-arrays help.topics namespaces vocabs.refresh make io.streams.string concurrency.futures vocabs.loader io.pathnames stack-checker.errors ;
IN: factor-lsp

GENERIC: lsp-reply ( server request -- server )
PREDICATE: lsp-message < hashtable "jsonrpc" of ;
ERROR: not-implemented-yet ;
ERROR: lsp-unexpected-eof ;
ERROR: lsp-unreachable msg ;
SYMBOL: lsp-should-log?

: log-lsp ( string -- ) lsp-should-log? get [ "~/lsp.log" utf8 [ now [ "[" write hour>> pprint ] [ ":" write minute>> pprint "]" write ] bi print ] with-file-appender ] [ drop ] if ;

PREDICATE: lsp-notification < lsp-message "id" of not ;

GENERIC: concise-summary ( obj -- str )
M: object concise-summary [ summary ": " append ] [ unparse ] bi append ;
M: effect-error concise-summary [ summary ": expected effect " append ] [ dup declared>> effect>string ", but inferred " append swap inferred>> effect>string append ] bi append ;
! obj last
M: unbalanced-branches-error concise-summary [ [ summary % ": expected effect(s) " % ] keep
    dup declareds>> unclip-last [ [ [ effect>string % ", " % ] each ] keep length 0 > [ " and " % ] when ] dip 
    effect>string % ", but inferred " % actuals>> unclip-last [ [ [ effect>string % ", " % ] each ] keep length 0 > [ " and " % ] when ] dip effect>string % ] "" make ;

<<
SYNTAX: LSP-METHOD:  
    scan-new-class dup 
    lsp-message
    scan-word-name [ swap "method" of = ] curry define-predicate-class
    \ lsp-reply create-method
    \ ; parse-until >quotation define
    ;

SYNTAX: LSP-NOTIF:  
    scan-new-class dup 
    lsp-notification
    scan-word-name [ swap "method" of = ] curry define-predicate-class
    \ lsp-reply create-method
    \ ; parse-until >quotation define
    ;

CONSTANT: server-capabilities 
    H{ 
        { "completionProvider" H{ { "labelDetailsSupport" t } } }
        ! { "declarationProvider" f } ! for now
        ! { "definitionProvider" f } ! for now
        ! { "implementationProvider" f } ! for now
        ! { "referencesProvider" f } ! for now
        { "signatureHelpProvider" H{ } }
        ! { "diagnosticProvider" H{ { "interFileDependencies" t } { "workspaceDiagnostics" f } } }
        { "hoverProvider" t }
        { "textDocumentSync" 1 } ! FULL
        ! { "executeCommandProvider" H{ { "commands" { "apropos" } } } }
    }

CONSTANT: server-info H{ { "name" "factor-lsp" } { "version" "0.0.1" } }

>>

M: lsp-notification lsp-reply "method" of "did not handle: " prepend log-lsp ;

: create-lsp-message ( object -- string ) >json dup length >dec "Content-Length: " prepend "\r\n\r\n" append prepend ;

: respond ( response -- ) create-lsp-message [ log-lsp ] [ write ] bi flush ;

: byte-length ( str -- len ) utf8 encode length ;

: byte-read ( n -- str ) input-stream get dup decoder? [ stream>> stream-read utf8 decode ] [ stream-read ] if ;

: read-check ( n -- string complete? ) dup byte-read tuck length = ;
! start + "Content-Length: " + num + "\r\n" + rest + actually-read

: log-byte-array ( byte-array prefix -- ) [ utf8 decode [ unparse ] without-limits ] dip prepend log-lsp ;

: byte-cut ( str i -- before after ) [ utf8 encode ] dip cut [ utf8 decode ] bi@ ;

: byte-cut* ( str i -- before after ) [ utf8 encode ] dip cut* [ utf8 decode ] bi@ ;

: read-lsp-message ( start -- remainder obj/f ) 
    dup [ unparse ] without-limits "start: " prepend log-lsp readln "\r\n" append append dup [ unparse ] without-limits "input-full: " prepend log-lsp dup "Content-Length: " subseq-index
    [ 
       "Content-Length: " length + cut dup "\r\n" subseq-index [ "there should always be a \\r\\n" lsp-unreachable ] unless*
        cut over [ append "\r\n" append ] 2dip dec> [ 2 cut swap dup "\r\n" = [ drop ] [ unparse " should equal \\r\\n" append lsp-unreachable ] if ] dip
        [ 
            over byte-length - dup 0 < [ nipd -1 * 2 - byte-cut* swap ] 
            [ 2 read dup "\r\n" = 
                [ drop "" swap ] [ swap ] if read-check [ append dup [ unparse ] without-limits "read: " prepend log-lsp append ] dip [ nip f swap ] [ append f ] if ] if
        ]
        [ nip f ] if* 
        [ 
            swap [ append ] when* CHAR: } over last-index 1 + cut swap [ dup [ unparse ] without-limits "remainder: " prepend log-lsp dup byte-length >dec "overread: " prepend log-lsp ] 
            [ dup [ unparse ] without-limits "result: " prepend log-lsp ] bi* json> assoc>> [ obj>> last ] assoc-map 
        ] [ f ] if* 
    ] 
    [ f ] if* ;
! stolen from splitting.private
: linebreak? ( ch -- ? )
    dup 31 <
    [ dup 10 13 between? [ drop t ] [ 28 30 between? ] if ] [
        dup 133 <
        [ drop f ]
        [ dup 133 = [ drop t ] [ 8232 8233 between? ] if ] if
    ] if ; inline

: set-at* ( value key assoc -- assoc ) [ set-at ] keep ;
: <lsp-request> ( id method params -- request ) "params" associate [ "method" ] dip set-at* [ "id" ] dip set-at* [ "2.0" "jsonrpc" ] dip set-at* ;
: <lsp-notification> ( method params -- notif ) "params" associate [ "method" ] dip set-at* [ "2.0" "jsonrpc" ] dip set-at* ;
: <lsp-response> ( id result/f error/f -- response ) "error" associate [ "result" ] dip set-at* [ "id" ] dip set-at* [ "2.0" "jsonrpc" ] dip set-at*  ;

: create-completion-item ( vocabulary name effect -- completion-item ) 
    [ "label" associate ] dip "detail" associate "labelDetails" rot set-at* [ "detail" ] dip set-at* ;

: create-completion-items ( str -- items ) words-matching 10 head 
    [ [ first vocabulary>> dup string? not [ unparse ] when ] [ second ] [ first stack-effect unparse ] tri create-completion-item ] map ;

: index-at-line-start ( string line-number -- index ) 0 -rot [ dup 0 > ] [ [ 2dup nth linebreak? ] dip swap [ 1 - ] when [ 1 + ] 2dip ] while 2drop ;

: pos>index ( string position -- index ) [ "line" of index-at-line-start ] keep "character" of + ;

: get-previous-word ( string index -- word ) [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 2dup swap nth [ 1 - ] dip ] collector [ while 2drop ] dip >string reverse ;

: get-previous-word-index ( string index -- index ) [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 1 - ] while nip ;

: get-next-word ( string index -- word ) [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 2dup swap nth [ 1 + ] dip ] collector [ while 2drop ] dip >string  ;

: get-next-word-index ( string index -- index ) [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 1 + ] while nip  ;

: send-message ( severity message -- ) [ "type" associate ] dip "message" rot set-at* "window/showMessage" swap <lsp-notification> respond ;

: string>factor-markup-content ( string -- markup-content ) [ "" ] unless* "value" "factor" "language" associate set-at* ;

: get-current-word ( string position -- word ) 
    dupd pos>index [ get-previous-word ] [ 1 + get-next-word ] 2bi append ;

: get-current-word-range ( string position -- range ) dupd pos>index [ get-next-word-index "end" ] [ get-previous-word-index 1 + "start" associate ] 2bi set-at* ;

: first-word-with-name ( string -- word/f ) all-words [ name>> = ] with find nip ;
! /Users/leomehraban/factor/work/factor-lsp/factor-lsp.factor >> resource:work/factor-lsp/factor-lsp.factor
: resource-path ( path -- resource-path ) 
    [ 
        vocab-roots get 
        [ dupd [ 2dup [ absolute-path "/" append = not ] keepd root-directory? not and ] [ [ parent-directory ] dip ] while drop root-directory? not ] find 2nip 
    ] keep over absolute-path length tail append ;

! too lazy to do precise diagnostics
: full-line-range ( line# -- range ) [ "line" associate [ 0 "character" ] dip set-at* ] [ 1 - "line" associate [ 0 "character" ] dip set-at* "start" associate ] bi [ "end" ] dip set-at* ;
: vocabulary-of-file ( string -- vocab-name/f ) dup "IN: " subseq-index [ 4 + tail 0 get-next-word ] [ drop f ] if* ;

: load-file ( full-file-text -- ) 
    [ 
        vocabulary-of-file [ [ require ] [ refresh ] [ "loaded vocabulary: " prepend 3 swap send-message ] tri ] [ 2 "failed to load file because of: " rot unparse append send-message drop ] recover 
    ] curry future drop ;

: (send-diagnostics) ( errors -- diagnostics ) [ 
        [ error-line full-line-range "range" ] 
        [ error>> concise-summary "message" associate ] bi set-at*
        [ "factor-lsp" "source" ] dip set-at* [ 1 "severity" ] dip set-at*
    ] map  ;

: send-diagnostics ( errors uri -- ) [ (send-diagnostics) "diagnostics" ] dip "uri" associate set-at* [ "textDocument/publishDiagnostics" ] dip <lsp-notification> respond ;

: send-signatures ( id word-name -- ) 
    words-named 
    [ 
        dup stack-effect unparse "label" associate 
        [ article>markdown "value" associate [ "markdown" "kind" ] dip set-at* "documentation" ] dip set-at*
    ] map "signatures" associate json-null <lsp-response> respond ;

M: lsp-server errors-changed 
    documents>> keys all-errors group-by-source-file [ [ dup >url path>> resource-path ] dip at [ swap send-diagnostics ] [ drop ] if* ] curry each ;


: lsp-server-run ( do-logging? -- ) 
        dup [ "~/lsp.log" utf8 [ "" write ] with-file-writer ] when lsp-should-log?
        [ 
            [
                "lsp started" log-lsp H{ } clone f <lsp-server> dup add-error-observer "" [ read-lsp-message [ swapd lsp-reply swap t ] [ t ] if* ] loop 2drop 
            ] 
            [ "lsp crashed" log-lsp dup unparse log-lsp error-continuation get unparse log-lsp rethrow ] recover 
        ] with-variable ;

MAIN: [ t lsp-server-run ]


! I'm just gonna assume the client can do everything for now, and not check the capibilities
LSP-METHOD: lsp-initialize initialize 
    "id" of 
    H{ { "capabilities" $[ server-capabilities ] } { "serverInfo" $[ server-info ] } } clone json-null <lsp-response> respond 
    "initialized" json-null <lsp-notification> respond t >>initialized? 3 "factor-lsp loaded" send-message ;

LSP-METHOD: lsp-shutdown shutdown "id" of json-null json-null <lsp-response> respond ;

LSP-METHOD: lsp-exit exit not-implemented-yet ;

LSP-NOTIF: lsp-open-doc textDocument/didOpen 
    "params" of "textDocument" of [ swap [ [ "text" of ] [ "uri" of dup >url path>> resource-path path>source-file unparse log-lsp ] bi over load-file ] dip set-at* ] curry change-documents ;

LSP-NOTIF: lsp-did-change textDocument/didChange "params" of [ "contentChanges" of last "text" of ] [ "textDocument" of "uri" of ] bi [ rot set-at* ] 2curry change-documents ;

LSP-NOTIF: lsp-did-close textDocument/didClose "params" of "textDocument" of "uri" of [ f spin set-at* ] curry change-documents ;

LSP-NOTIF: lsp-did-save textDocument/didSave "params" of "textDocument" of "uri" of over documents>> at load-file ;

LSP-METHOD: lsp-hover textDocument/hover 
    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri 
    [ swapd dupd [ swapd documents>> ] dip of ] dip 
    [ get-current-word first-word-with-name [ [ stack-effect unparse ] [ vocabulary>> [ "IN: " prepend " " append ] [ "" ] if* ] bi prepend ] 
    [ f ] if* string>factor-markup-content "contents" ] [ get-current-word-range "range" associate ] 2bi set-at* 
    json-null <lsp-response> respond ;
! server id document pos
LSP-METHOD: lsp-signature-help textDocument/signatureHelp 
    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri
    [ swapd dupd [ swapd documents>> ] dip of ] dip [ get-current-word send-signatures ] 
    [ 3drop f ] if*
    ;

LSP-METHOD: lsp-text-document-completion textDocument/completion 
    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri 
    [ swapd dupd [ swapd documents>> ] dip of ] dip get-current-word create-completion-items json-null <lsp-response> respond ;

LSP-METHOD: lsp-completion-resolve completionItem/resolve 
    [ "id" of ] [ "params" of [ "detail" of ] [ "label" of ] bi words-named [ vocabulary>> dup string? not [ unparse ] when = ] with find nip ] [ "params" of ] tri
    [ article>markdown "value" associate [ "markdown" "kind" ] dip set-at* "documentation" ] dip set-at* json-null <lsp-response> respond ;
! 
LSP-METHOD: lsp-diagnostics textDocument/diagnostic 
    [ "id" of ] 
    [ "params" of "textDocument" of "uri" of ] bi dup 
    >url path>> resource-path 
    all-errors group-by-source-file 
    at swap [ [ { } ] unless* (send-diagnostics) "items" ] dip "uri" associate set-at* [ "full" "kind" ] dip set-at* json-null <lsp-response> respond ;
