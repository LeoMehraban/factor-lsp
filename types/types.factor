IN: factor-lsp.types
USING: kernel urls strings ;

TUPLE: lsp-error code msg ;

: <lsp-parse-error> ( msg -- err ) -32700 swap lsp-error boa ;
: <lsp-invalid-request-error> ( msg -- err ) -32600 swap lsp-error boa ;
: <lsp-method-not-found-error> ( msg -- err ) -32601 swap lsp-error boa ;
: <lsp-invalid-params-error> ( msg -- err ) -32602 swap lsp-error boa ;
: <lsp-internal-error> ( msg -- err ) -32603 swap lsp-error boa ;
: <lsp-server-not-initialized-error> ( msg -- err ) -32002 swap lsp-error boa ;
: <lsp-unknown-error-code-error> ( msg -- err ) -32001 swap lsp-error boa ;
: <lsp-request-failed-error> ( msg -- err ) -32803 swap lsp-error boa ;
: <lsp-server-cancelled-error> ( msg -- err ) -32802 swap lsp-error boa ;
: <lsp-content-modified-error> ( msg -- err ) -32801 swap lsp-error boa ;
: <lsp-request-cancelled-error> ( msg -- err ) -32800 swap lsp-error boa ;

TUPLE: lsp-server documents initialized? ;
C: <lsp-server> lsp-server
