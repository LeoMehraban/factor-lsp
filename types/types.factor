IN: factor-lsp.types
USING: kernel urls strings hashtables assocs ;

: <lsp-error> ( code msg -- err ) "message" associate [ "code" ] dip [ set-at ] keep ;
: <lsp-parse-error> ( msg -- err ) -32700 swap <lsp-error> ;
: <lsp-invalid-request-error> ( msg -- err ) -32600 swap <lsp-error> ;
: <lsp-method-not-found-error> ( msg -- err ) -32601 swap <lsp-error> ;
: <lsp-invalid-params-error> ( msg -- err ) -32602 swap <lsp-error> ;
: <lsp-internal-error> ( msg -- err ) -32603 swap <lsp-error> ;
: <lsp-server-not-initialized-error> ( msg -- err ) -32002 swap <lsp-error> ;
: <lsp-unknown-error-code-error> ( msg -- err ) -32001 swap <lsp-error> ;
: <lsp-request-failed-error> ( msg -- err ) -32803 swap <lsp-error> ;
: <lsp-server-cancelled-error> ( msg -- err ) -32802 swap <lsp-error> ;
: <lsp-content-modified-error> ( msg -- err ) -32801 swap <lsp-error> ;
: <lsp-request-cancelled-error> ( msg -- err ) -32800 swap <lsp-error> ;

TUPLE: lsp-server documents initialized? ;
C: <lsp-server> lsp-server
