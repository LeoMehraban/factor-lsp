! Copyright (C) 2025 Your name.
! See https://factorcode.org/license.txt for BSD license.

USING: accessors assocs calendar classes.parser classes.predicate combinators concurrency.futures continuations definitions effects factor-lsp.types generic hashtables help.apropos io io.encodings io.encodings.string io.encodings.utf8 io.files io.files.temp io.pathnames io.servers json kernel literals make math math.order math.parser namespaces parser present prettyprint prettyprint.config quotations sequences source-files source-files.errors splitting arrays help.topics command-line stack-checker.errors strings classes summary tools.completion unicode urls vocabs vocabs.loader vocabs.refresh words factor-lsp.help byte-arrays sequences.private splitting.private ;

IN: factor-lsp
! TODO: something with offsets broken in unicode-heavy files
GENERIC: lsp-reply ( server request -- server )
GENERIC: lsp-command-reply ( server id params command -- server result/f )
PREDICATE: lsp-message < hashtable "jsonrpc" of ;
ERROR: not-implemented-yet ;
ERROR: lsp-unexpected-eof ;
ERROR: lsp-unreachable msg ;
ERROR: likely-infinate-loop ;
SYMBOL: lsp-logfile
SYMBOL: lsp-threaded-server
SYMBOL: md-article-cache-count

: log-lsp ( string -- ) lsp-logfile get [ utf8 [ now [ "[" write hour>> pprint ] [ ":" write minute>> pprint "]" write ] bi print ] with-file-appender ] [ drop ] if* ;

PREDICATE: lsp-notification < lsp-message "id" of not ;
PREDICATE: lsp-response < lsp-message "result" of ;
M: lsp-response lsp-reply drop ;

GENERIC: concise-summary ( obj -- str )
M: object concise-summary [ summary ": " append ] [ unparse ] bi append  ;
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

SYNTAX: LSP-COMMAND:
    scan-new-class dup
    string
    scan-word-name [ = ] curry define-predicate-class
    \ lsp-command-reply create-method
    \ ; parse-until >quotation define
    ;

CONSTANT: server-capabilities 
    H{ 
        { "completionProvider" H{ { "labelDetailsSupport" t } } }
        ! { "declarationProvider" f } ! for now
        { "definitionProvider" t } ! for now
        ! { "implementationProvider" f } ! for now
        ! { "referencesProvider" f } ! for now
        { "signatureHelpProvider" H{ } }
        ! { "diagnosticProvider" H{ { "interFileDependencies" t } { "workspaceDiagnostics" f } } }
        { "hoverProvider" t }
        { "textDocumentSync" 2 } ! INCREMENTAL
        { "positionEncoding" "utf-8" }
        { "executeCommandProvider" H{ { "commands" { "article" } } } }
    }

CONSTANT: server-info H{ { "name" "factor-lsp" } { "version" "0.0.1" } }

>>

M: lsp-notification lsp-reply "method" of "did not handle: " prepend log-lsp ;

: byte-length ( str -- len ) utf8 encode length ;

: >utf8 ( str -- byte-array ) dup byte-array? [ utf8 encode ] unless ;

: utf8> ( byte-array -- str ) dup byte-array? [ utf8 decode ] unless ;

: create-lsp-message ( object -- string ) >json dup byte-length >dec "Content-Length: " prepend "\r\n\r\n" append prepend ;

: respond ( response -- ) create-lsp-message [ log-lsp ] [ write ] bi flush ;

: byte-read ( n -- str ) input-stream get dup decoder? [ stream>> stream-read utf8 decode ] [ stream-read ] if ;

: read-check ( n -- string complete? ) dup byte-read tuck length = ;
! start + "Content-Length: " + num + "\r\n" + rest + actually-read

M:: byte-array split-lines ( seq -- seq' )
    seq length :> len V{ } clone 0
    [ dup len < ] [
        dup seq [ linebreak? ] find-from
        [ len or [ seq subseq-unsafe suffix! ] [ 1 + ] bi ]
        [ 13 eq? [ dup seq ?nth 10 eq? [ 1 + ] when ] when ] bi*
    ] while drop { } like ; inline

: log-byte-array ( byte-array prefix -- ) [ utf8 decode [ unparse ] without-limits ] dip prepend log-lsp ;

: byte-cut ( str i -- before after ) [ utf8 encode ] dip cut [ utf8 decode ] bi@ ;

: byte-cut* ( str i -- before after ) [ utf8 encode ] dip cut* [ utf8 decode ] bi@ ;

: read-lsp-message ( counter start -- counter remainder obj/f )
    [ length 0 > [ 1 - ] [ drop 100 ] if ] keep over 0 <= [ likely-infinate-loop ] when
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

: imported-vocabs ( document -- imports using-start using-end ) 
    dup "USING: " subseq-index 
    [ 
        "USING: " length + over CHAR: ; swap index 
        [ swapd [ [ dup length ] dip - ] [ 0 ] if* head* swap tail " \n\r" split harvest ] 2keep 
    ]
    [ drop { } f f ] if* ;

: (make-vocab-change) ( vocab-to-add imports using-start using-end -- new using-start using-end ) 
    [ 2nip [ swap vocab-name " " append ] keep rot ] 
    [ [ [ swap vocab-name suffix " " join " ;\n" append dup length ] dip tuck + ] [ drop vocab-name "USING: " prepend " ;\n" append 0 0 ] if* ] if* ;

: set-at* ( value key assoc -- assoc ) [ set-at ] keep ;
: <lsp-request> ( id method params -- request ) "params" associate [ "method" ] dip set-at* [ "id" ] dip set-at* [ "2.0" "jsonrpc" ] dip set-at* ;
: <lsp-notification> ( method params -- notif ) "params" associate [ "method" ] dip set-at* [ "2.0" "jsonrpc" ] dip set-at* ;
: <lsp-response> ( id result/f error/f -- response ) "error" associate [ "result" ] dip set-at* [ "id" ] dip set-at* [ "2.0" "jsonrpc" ] dip set-at*  ;

! TODO: find a way to fix that 1 +: it assumes the linebreak is only one character long
: index-at-line-start ( string line-number -- index ) 
    [ >utf8 split-lines ] dip 0 -rot [ dup 0 > ] 
    [ 1 - [ unclip length swap [ + 1 + ] dip ] dip ] while 2drop ;

: pos>index ( string position -- index ) [ "line" of index-at-line-start ] keep "character" of + ;

: index>pos ( string index -- position ) 
    [ >utf8 split-lines ] dip over [ over [ dup length 1 > [ dup first length 1 + ] [ 0 <fp-nan> ] if ] dip <= ] [ unclip length 1 + swap [ - ] dip ] while swapd [ length ] bi@ -
    "line" associate [ "character" ] dip set-at* ;

: get-previous-word ( string index -- word ) [ >utf8 ] dip [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 2dup swap nth [ 1 - ] dip ] collector [ while 2drop ] dip reverse utf8> ;

: get-previous-word-index ( string index -- index ) [ >utf8 ] dip [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 1 - ] while nip ;

: get-next-word ( string index -- word ) [ >utf8 ] dip [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 2dup swap nth [ 1 + ] dip ] collector [ while 2drop ] dip utf8>  ;

: get-next-word-index ( string index -- index ) [ >utf8 ] dip [ 2dup swap ?nth [ blank? not ] [ f ] if* ] [ 1 + ] while nip  ;

: <text-edit> ( text start end document -- text-edit ) tuck [ swap index>pos ] 2bi@ "end" associate [ "start" ] dip set-at* "range" associate [ "newText" ] dip set-at* ;

: vocabulary-of-file ( string -- vocab-name/f ) dup "IN: " subseq-index [ 4 + tail 0 get-next-word ] [ drop f ] if* ;

: make-vocab-change ( vocab-to-add document -- text-edits ) 
    over "syntax" = 
    [ 2drop { } ] 
    [ 
        2dup [ vocabulary-of-file = ] [ vocabulary-of-file ".private" append = ] bi or not
        [ 
            tuck imported-vocabs [ 2dup index ] 2dip rot 
            [ 4drop drop { } ] 
            [ 
                (make-vocab-change) roll <text-edit> 1array
            ] if 
        ] [ 2drop { } ] if
    ] if ;

GENERIC: create-completion-item ( document obj -- completion-item )
! text-edits completion-item
M: class create-completion-item 
    [ 
        [ vocabulary>> vocab-name ] [ name>> ] [ superclass-of ] tri 
        [ "label" associate ] dip "detail" associate [ [ swap make-vocab-change ] keep ] 2dip 
        "labelDetails" rot set-at* [ "detail" ] dip set-at* [ 7 "kind" ] dip set-at* [ "additionalTextEdits" ] dip set-at* 
    ] keep deprecated? 
    [ [ { 1 } "tags" ] dip set-at* ] when ;
M: word create-completion-item
    [
        [ vocabulary>> vocab-name ] [ name>> ] [ stack-effect effect>string ] tri 
        [ "label" associate ] dip "detail" associate [ [ swap make-vocab-change ] keep ] 2dip
        "labelDetails" rot set-at* [ "detail" ] dip set-at* [ 3 "kind" ] dip set-at* [ "additionalTextEdits" ] dip set-at* 
    ] keep deprecated? [ [ { 1 } "tags" ] dip set-at* ] when ;

: create-completion-items ( document str -- items ) 
    dup length 0 > 
    [ dup words-matching [ first name>> swap head? ] with filter [ dup ] H{ } map>assoc keys [ first create-completion-item ] with map ] 
    [ 2drop { } ] if ;

: send-message ( severity message -- ) [ "type" associate ] dip "message" rot set-at* "window/showMessage" swap <lsp-notification> respond ;

: string>factor-markup-content ( string -- markup-content ) [ "" ] unless* "value" "factor" "language" associate set-at* ;

: get-current-word ( string position -- word ) 
    dupd pos>index [ 1 - get-previous-word ] [ get-next-word ] 2bi append ;

: get-current-word-range ( string position -- range ) dupd pos>index [ dupd get-next-word-index index>pos "end" ] [ dupd get-previous-word-index 1 + index>pos "start" associate ] 2bi set-at* ;

: first-word-with-name ( string -- word/f ) all-words [ name>> = ] with find nip ;
! /Users/leomehraban/factor/work/factor-lsp/factor-lsp.factor >> resource:work/factor-lsp/factor-lsp.factor
: resource-path ( path -- resource-path ) 
    [ 
        vocab-roots get 
        [ dupd [ 2dup [ absolute-path "/" append = not ] keepd root-directory? not and ] [ [ parent-directory ] dip ] while drop root-directory? not ] find 2nip 
    ] keep over absolute-path length tail append ;

! too lazy to do precise diagnostics
: full-line-range ( line# -- range ) [ "line" associate [ 0 "character" ] dip set-at* ] [ 1 - "line" associate [ 0 "character" ] dip set-at* "start" associate ] bi [ "end" ] dip set-at* ;

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

: send-hover ( id word-name -- ) 
    words-named dup length 0 > [ first article>markdown "value" associate [ "markdown" "kind" ] dip set-at* "contents" associate ] [ drop json-null ] if json-null <lsp-response> respond ;

M: lsp-server errors-changed 
    documents>> keys all-errors group-by-source-file [ [ dup >url path>> resource-path ] dip at [ swap send-diagnostics ] [ drop ] if* ] curry each ;

: string>topic ( string type -- topic/f ) {
            { "word" [ words-matching first first ] }
            { "vocab" [ vocabs-matching first first ] }
            { "article" [ articles-matching first first ] }
            [ 2drop f ]
        } case
;

: filename>topic ( filename -- topic ) "-" split1 "," split1 drop swap string>topic ;

: lsp-server-run ( logfile/f -- ) 
        dup [ utf8 [ "" write ] with-file-writer ] when* lsp-logfile
        [ 
            [
                "lsp started" log-lsp H{ } clone f <lsp-server> dup add-error-observer 100 "" [ read-lsp-message [ rotd lsp-reply -rot t ] [ t ] if* ] loop 3drop 
            ] 
            [ "lsp crashed" log-lsp dup unparse log-lsp error-continuation get unparse log-lsp rethrow ] recover
        ] with-variable ;

: split-remove-range ( document range -- before-range after-range ) 
    [ >utf8 dup ] dip [ "start" of pos>index ] [ "end" of ] bi pick split-lines length [ dup "line" of ] dip
    < [ swapd dupd pos>index [ dup length ] dip min cut ] [ drop swap "" ] if [ swap [ dup length ] dip min head ] dip [ utf8> ] bi@ ;

: apply-change ( document new-text range -- document ) swapd split-remove-range rot prepend append ;

: parse-command-line ( -- logfile/f ) command-line get dup length 0 > [ first ] [ drop f ] if ;
MAIN: [ parse-command-line lsp-server-run ]

! I'm just gonna assume the client can do everything for now, and not check the capibilities
LSP-METHOD: lsp-initialize initialize 
    "id" of 
    H{ { "capabilities" $[ server-capabilities ] } { "serverInfo" $[ server-info ] } } clone json-null <lsp-response> respond 
    "initialized" json-null <lsp-notification> respond t >>initialized? 3 "factor-lsp loaded" send-message ;

LSP-METHOD: lsp-shutdown shutdown "id" of json-null json-null <lsp-response> respond ;

LSP-METHOD: lsp-exit exit not-implemented-yet ;

LSP-METHOD: lsp-command workspace/executeCommand 
    [ "id" of dup ] [ "params" of "arguments" of ] [ "params" of "command" of ] tri lsp-command-reply [ json-null <lsp-response> respond ] [ drop ] if* ;

LSP-NOTIF: lsp-open-doc textDocument/didOpen 
    "params" of "textDocument" of [ swap [ [ "text" of ] [ "uri" of dup >url path>> resource-path path>source-file unparse log-lsp ] bi over load-file ] dip set-at* ] curry change-documents ;

LSP-NOTIF: lsp-did-change textDocument/didChange 
    "params" of [ "contentChanges" of ] [ "textDocument" of "uri" of ] bi 
    [ overd [ documents>> ] dip [ of swap [ "text" of ] [ "range" of ] bi apply-change ] keep [ rot set-at* ] 2curry change-documents ] curry each ;

LSP-NOTIF: lsp-did-close textDocument/didClose "params" of "textDocument" of "uri" of [ f spin set-at* ] curry change-documents ;

LSP-NOTIF: lsp-did-save textDocument/didSave "params" of "textDocument" of "uri" of over documents>> at load-file ;

LSP-METHOD: lsp-signature-help textDocument/signatureHelp
    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri 
    [ swapd dupd [ swapd documents>> ] dip of ] dip 
    get-current-word words-named [ [ [ stack-effect unparse ] [ vocabulary>> [ "IN: " prepend " " append ] [ "" ] if* ] bi prepend ] [ f ] if* string>factor-markup-content "documentation" associate ] map
    "signatures" associate
    json-null <lsp-response> respond ;
! server id document pos
LSP-METHOD: lsp-hover textDocument/hover
    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri
    [ swapd dupd [ swapd documents>> ] dip of ] dip [ get-current-word send-hover ] 
    [ 3drop f ] if*
    ;

: (get-help) ( name -- markdown/f ) 
        { 
            { [ dup words-named length 0 > ] [ words-named first article>markdown ] }
            { [ dup vocab-exists? ] [ article>markdown ] }
            { [ dup articles get at ] [ articles get at article>markdown ] }
            [ drop f ]
        } cond
 ;

! stop it, get some help
: get-help ( name -- markdown/f )
    dup first CHAR: - =
    [ 
        1 tail CHAR: \s over index cut 1 tail swap 
        [ string>topic ] 2keep rot [ 2nip article>markdown ] [ "-" prepend " " append prepend (get-help) ] if*
    ] 
    [ (get-help) ] if
    ;
    

: inc-md-article-cache-count ( -- str ) md-article-cache-count [ [ 0 ] initialize ] [ get >dec ] [ [ 1 + ] change ] tri ;

: make-call-hierarchy-item ( uri range word -- item ) 
    -rot [ { [ name>> "name" ] [ class? 5 12 ? "kind" ] [ deprecated? { 1 } { } ? "tags" ] } cleave ] 2dip
    swap [ "range" over "selectionRange" ] dip "uri" associate set-at* set-at* set-at* set-at* set-at*
    ;
! ( server id params command -- server result/f )
! server id+1 "window/showDocument" H{ { "uri" url } }
LSP-COMMAND: lsp-article article
    drop
    [ 
        unclip-last [ [ " " append ] map ] dip suffix concat get-help 
        [ 
            "markdown-article-" inc-md-article-cache-count append ".md" append dup log-lsp
            cache-file [ utf8 set-file-contents <url> ] keep absolute-path >>path "file" >>protocol present "uri" associate "window/showDocument" swap
            [ 1 + ] 2dip <lsp-request> respond json-null
        ] 
        [ "unknown article" <lsp-invalid-params-error> json-null swap <lsp-response> respond f ] if* 
    ] 
    [ "usage: article <search-term>" <lsp-invalid-params-error> json-null swap <lsp-response> respond f ] if*
    ;
! server id document position
LSP-METHOD: lsp-text-document-definition textDocument/definition 
    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri
    [ swapd dupd [ swapd documents>> ] dip of ] dip 
        get-current-word first-word-with-name where 
        [ first2 [ absolute-path "file://" prepend ] [ full-line-range ] bi* "range" associate [ "uri" ] dip set-at* ] [ json-null ] if* 
        string>factor-markup-content "documentation" associate json-null <lsp-response> respond 
        ;
LSP-METHOD: lsp-text-document-completion textDocument/completion 
    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri 
    [ swapd dupd [ swapd documents>> ] dip of ] dip dupd get-current-word create-completion-items json-null <lsp-response> respond ;

LSP-METHOD: lsp-completion-resolve completionItem/resolve 
   [ "id" of ] [ "params" of [ "detail" of ] [ "label" of ] bi words-named [ vocabulary>> dup string? not [ unparse ] when = ] with find nip ] [ "params" of ] tri
   [ article>markdown "value" associate [ "markdown" "kind" ] dip set-at* "documentation" ] dip set-at* json-null <lsp-response> respond ;

LSP-METHOD: lsp-diagnostics textDocument/diagnostic 
    [ "id" of ] 
    [ "params" of "textDocument" of "uri" of ] bi dup 
    >url path>> resource-path 
    all-errors group-by-source-file 
    at swap [ [ { } ] unless* (send-diagnostics) "items" ] dip "uri" associate set-at* [ "full" "kind" ] dip set-at* json-null <lsp-response> respond ;
! server id uri range word
! LSP-METHOD: lsp-prepare-call-hierarchy textDocument/prepareCallHierarchy
!    [ "id" of ] [ "params" of "textDocument" of "uri" of ] [ "params" of "position" of ] tri
!    [ swapd dupd [ swapd documents>> ] dip [ of ] keepd ] dip swapd [ get-current-word-range ] [ get-current-word ] 2bi
!    words-named dup length 0 >
!    [ first make-call-hierarchy-item ]
!    [ 3drop json-null json-null <lsp-response> respond ] if
!    ;
