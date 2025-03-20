USING: sequences make kernel math splitting tools.annotations continuations io arrays strings vocabs combinators words quotations prettyprint prettyprint.sections urls help.topics effects accessors help.markup assocs see io.streams.string tools.annotations.private compiler.units classes generic macros sorting words.symbol sequences.deep vocabs.metadata vocabs.loader vocabs.hierarchy classes.builtin classes.intersection classes.mixin help classes.predicate classes.singleton tools.completion classes.tuple classes.union help.vocabs help.apropos namespaces io.files io.encodings.utf8 ui.operations ui.gestures ui.commands english.private xml.errors.private math.matrices.private sequences.generalizations math.parser help.home help.tips ;
IN: factor-lsp.help


DEFER: md-$link
DEFER: md-$heading
DEFER: md-$see
DEFER: md-$links
DEFER: md-$strong
DEFER: md-$see-also
DEFER: md-$pretty-link
DEFER: md-$table
DEFER: md-$words
DEFER: md-$vocab-roots
DEFER: md-$values
DEFER: md-$snippet
DEFER: md-$completions
DEFER: md-$subsection
DEFER: dollarsign-hash
SYMBOL: link-prefix
SYMBOL: link-suffix
GENERIC: element>markdown ( element -- )

ERROR: printing-not-handled ;

! : with-annotations ( words annotation-quot: ( word old-def -- new-def ) quot: ( ..a -- ..b ) -- ..b ) 
!  rot [ [ [ dupd with (annotate) ] curry ] 2dip -rot [ [ each ] 2curry [ with-compilation-unit ] curry ] dip ] keep [ [ (reset) ] each ] curry 
!  [ with-compilation-unit ] curry [ compose ] dip [ finally ] 2curry call ; inline

! MACRO: with-replacements ( assoc quot: ( ..a -- ..b ) -- quot: ( ..a -- ..b ) ) [ [ keys ] [ [ at def>> ] curry [ drop ] prepose ] bi ] dip [ with-annotations ] 3curry ;

: help-word? ( word -- ? ) dollarsign-hash at ;

: non-executable-word? ( word -- ? ) [ symbol? ] [ class? ] bi or ;

M: array element>markdown 
    unclip dup help-word? [ dollarsign-hash at ] when dup non-executable-word? [ unparse prefix [ element>markdown ] each ] [ ( arg -- ) execute-effect ] if ; inline
M: effect element>markdown effect>string % ; inline
M: f element>markdown % ; inline
M: simple-element element>markdown [ element>markdown ] each ; inline
M: string element>markdown % ; inline
M: word element>markdown 
    { } swap dup help-word? [ dollarsign-hash at ] when dup non-executable-word? [ unparse prefix element>markdown ] [ ( arg -- ) execute-effect ] if ; inline

GENERIC: link-address ( article-name -- link )
 
M: array link-address last link-address ;
M: apropos-search link-address text>> link-prefix get "/search?search=" append prepend link-suffix get append  ;
M: string link-address link-prefix get "/article-" append prepend link-suffix get append ;
M: link link-address name>> link-address ;
M: vocab-author link-address name>> link-prefix get "/author-" append prepend link-suffix get append ;
M: vocab-link link-address name>> link-prefix get "/vocab-" append prepend link-suffix get append ;
M: vocab-prefix link-address name>> link-prefix get "/vocab-" append prepend link-suffix get append ;
M: vocab link-address name>> link-prefix get "/vocab-" append prepend link-suffix get append  ;
M: vocab-tag link-address name>> link-prefix get "/tag-" append prepend link-suffix get append  ;
M: word link-address [ name>> link-prefix get "/word-" append prepend ] [ vocabulary>> "," prepend ] bi link-suffix get append append ;
M: f link-address drop link-prefix get "/word-f,syntax" link-suffix get append append ;

M: vocab-prefix article-title name>> ;

: array-length-or-zero ( seq -- length ) dup array? [ length ] [ drop 0 ] if ;

: (article>markdown) ( article-seq -- elts )
    link-prefix [ "https://docs.factorcode.org/content" ] initialize
    link-suffix [ ".html" ] initialize
    [ dup array-length-or-zero 0 > [ unclip dup help-word? [ dollarsign-hash at ] when prefix ] when ] deep-map ; inline 

MEMO: article>markdown ( article-name -- markdown )
    [ article-content (article>markdown) ] keep [ article-name "# " prepend % "\n" % element>markdown ] curry "" make ; inline


: test-generation ( topic -- ? ) 
    [ [ article>markdown ] with-string-writer "" = [ printing-not-handled ] unless drop t ] 
    [ [ unparse "generation of " prepend " failed: " append print ] dip "\t" write . f ] recover ;

! tests-pass-len articles-len
: test-everything ( -- ) 
    loaded-vocab-names [ [ <vocab> test-generation not ] map sift ] keep 2length
    articles get keys [ [ test-generation not ] map sift ] keep 2length swapd [ + ] 2bi@
    all-words [ [ test-generation not ] map sift ] keep 2length swapd [ + >dec ] 2bi@ "/" -rot surround "failed: " prepend print ;

: ?nl ( -- ) building get dup length 0 > [ last CHAR: \n = [ "\n" % ] unless ] [ drop "\n" % ] if ;

: md-$0-plurality ( element -- )
    drop {
        "Due to the unique way in which the English language is structured, the number "
        { md-$snippet "0" }
        " is considered plural; "
        { md-$snippet "1" }
        " is the only singular quantity."
    } element>markdown ;
: md-$about ( element -- ) first vocab-help [ 1array md-$subsection ] when* ;
: md-$authors ( element -- ) [ <vocab-author> ] map md-$links ;
: md-$authored-vocabs ( element -- ) first authored md-$vocab-roots ;
: md-$all-authors ( element -- ) drop "Authors" md-$heading all-authors md-$authors ;
: md-$tags ( seq -- ) [ <vocab-tag> ] map md-$links ;
: md-$tagged-vocabs ( element -- ) first tagged md-$vocab-roots ;
: md-$all-tags ( element -- ) drop "Tags" md-$heading all-tags md-$tags ;
:: md-(apropos) ( search completions category -- element )
    completions [
        [
            { $heading search } , [
                max-completions index-or-length head
                keys \ md-$completions prefix ,
            ] [
                length max-completions >
                [ { md-$link T{ more-completions f completions search category } } , ] when
            ] bi
        ] unless-empty
    ] { } make ;
: md-$apropos ( str -- )
    first
    [ dup words-matching word-result md-(apropos) ]
    [ dup vocabs-matching vocabulary-result md-(apropos) ]
    [ dup articles-matching article-result md-(apropos) ] tri
    3array element>markdown ;
: md-$breadcrumbs ( element -- ) dup length 0 > [ unclip-last [ "" [ [ 1array md-$link ] "" make " » " append append ] reduce ] dip [ 1array md-$link ] "" make append % ] [ drop ] if ;
: md-$class-description ( element -- ) "Class Description" md-$heading element>markdown ;
: md-$code ( element -- ) ?nl "```factor\n" % element>markdown "\n```" % ;
: md-$completions ( element -- )
    dup [ word? ] all?
    [ words-table ] [
        dup [ vocab-spec? ] all?
        [ $vocabs ] [ [ \ md-$pretty-link swap 2array 1array ] map md-$table ] if
    ] if ;

: md-$content ( element -- ) first article>markdown % ;
: md-command-map. ( element -- ) [ command-map-row ] { } assoc>map { "Shortcut" "Command" "Word" "Notes" } [ \ md-$strong swap ] map>alist prefix md-$table  ;
: md-$command ( element -- ) reverse first3 get-command-at commands>> value-at gesture>string md-$snippet ;
: md-$command-map ( element -- ) 
    [ second (command-name) " commands" append md-$heading ] [
        first2 swap get-command-at
        [ blurb>> element>markdown ] [ commands>> md-command-map. ] bi
    ] bi ;
: md-$contract ( element -- ) "Generic word contract" md-$heading element>markdown ;
: md-$curious ( element -- ) "For the curious..." md-$heading element>markdown  ;
: md-$definition ( element -- ) "Definition" md-$heading md-$see ;
: md-$definition-icons ( element -- ) drop ;
: md-$deprecated ( element -- ) "Deprecated" md-$heading [ element>markdown ] "" make split-lines [ "> " prepend "\n" append % ] each ;
: md-$description ( element -- ) "Description" md-$heading element>markdown  ;
: md-$emphasis ( children -- ) "*" % element>markdown "*" % ;
: md-$error-description ( element -- ) md-$description ;
: md-$errors ( element -- ) "Errors" md-$heading element>markdown  ;
: md-$example ( element -- ) unclip-last [ join-lines ] dip "\n! prints:\n" prepend append md-$code ?nl ;
: md-$examples ( element -- ) "Examples" md-$heading element>markdown ?nl ;
: md-$heading ( element -- ) ?nl "## " % element>markdown ?nl ;
: md-$image ( element -- ) drop "<image>\n" % ;
: md-$index ( element -- ) first ( -- seq ) call-effect [ sort-articles [ \ md-$subsection swap 2array ] map element>markdown ] unless-empty ;
: md-$inputs ( element -- ) "Inputs" md-$heading [ "None" % ] [ [ values-row ] map (article>markdown) md-$table ] if-empty ;
: md-$instance ( element -- ) first dup word? [ dup name>> a/an % " " % 1array md-$link ] [ element>markdown ] if ;
: md-$io-error ( children -- ) drop "Throws an error if the I/O operation fails." md-$errors ;
: md-$keep-case ( element -- )
    drop "This word attempts to preserve the letter case style of the input." element>markdown
    ;
: md-$link ( element -- ) 
    first dup wrapper? [ wrapped>> ] when dup article-name "[" prepend "]" append % "(" % link-address % ")" % ;
: md-$links ( topics -- ) dup length 0 > [ unclip-last [ "" [ [ 1array md-$link ] "" make ", " append append ] reduce ] dip [ 1array md-$link ] "" make append % ] [ drop ] if  ;
: md-$list ( element -- ) [ ?nl "- " % element>markdown ] each ?nl ;
: md-$long-link ( element -- ) md-$link "\n" % ;
: md-$low-level-note ( element -- ) drop "Notes" md-$heading "Calling this word directly is not necessary in most cases. Higher-level words call it automatically.\n" % ;
: md-$markup-example ( element -- ) first dup unparse " print-element" append 1array md-$code element>markdown ;
: md-$maybe ( element -- ) md-$instance " or " % \ f 1array md-$link ;
: md-$methods ( element -- ) first methods [ "Methods" md-$heading [ [ see "\n" write ] each ] with-string-writer md-$code ] unless-empty ;
: md-$nl ( element -- ) drop "\n" % ;
: md-$notes ( element -- ) "Notes" md-$heading element>markdown ;

: md-$or ( element -- ) dup length 
    { 
        { 1 [ first 1array md-$instance ] } 
        { 2 [ first2 [ 1array md-$instance " or " element>markdown ] [ 1array md-$instance ] bi* ] } 
        [ drop unclip-last [ [ 1array md-$instance ", " % ] each ] [ "or " % 1array md-$instance ] bi* ]
    } case ;
: md-$outputs ( element -- ) "Outputs" md-$heading [ "None" % ] [ [ values-row ] map (article>markdown) md-$table ] if-empty ;
: md-$operation ( element -- ) first +keyboard+ word-prop gesture>string md-$snippet ;
: md-$operations ( element -- ) >quotation ( -- obj ) call-effect f operations>commands md-command-map. ;
: md-$parsing-note ( element -- ) drop "This word should only be called from parsing words." md-$notes ;
: md-$predicate ( element --  ) { { "object" object } { "?" boolean } } md-$values [
        "Tests if the object is an instance of the " ,
        first "predicating" word-prop \ md-$link swap 2array , " class." ,
    ] { } make md-$description ;
: md-$pretty-link ( element -- ) md-$link ;
: md-$prettyprinting-note ( element -- ) drop { "This word should only be called from inside the " { $link with-pprint } " combinator." } md-$notes ;
: md-$quotation ( element -- ) { "a " { $link quotation } " with stack effect " } element>markdown md-$snippet ;
: md-$recent ( element -- ) first get [ valid-article? ] filter <reversed> [ "\n" % ] [ 1array md-$pretty-link ] interleave ;
: md-$recent-searches ( element -- )
    drop recent-searches get [ \ md-$link swap 2array ] map md-$list ;
: md-$references ( element -- ) "References" md-$heading unclip element>markdown [ \ md-$link swap ] map>alist md-$list ;
: md-$related ( element -- ) first dup "related" word-prop remove [ md-$see-also ] unless-empty ;
: md-$see ( element -- ) first [ see ] with-string-writer md-$code ;
: md-$see-also ( element -- ) "See also" md-$heading md-$links ;
: md-$sequence ( element -- ) 
    { "a " { md-$link sequence } " of " } element>markdown dup length 
    {
        { 1 [ element>markdown "s" % ] }
        {
            2
            [
                first2
                [ drop " or " % ]
                [ element>markdown "s" %  ] bi*
            ]
        }
        [
            drop unclip-last
            [ [ element>markdown "s" %  ", " % ] each ]
            [ "or " % element>markdown "s" %  ] bi*
        ]
    } case ;

: md-$shuffle ( element -- ) 
    "This is a shuffle word, rearranging the top of the datastack as indicated by the word's stack effect: " swap ?first [ ": " swap "." 4array ] [ "." append ] if* md-$description ;
: md-$side-effects ( element -- ) "Side effects" md-$heading "Modifies " % md-$snippet ;
: md-$slot ( element -- ) md-$snippet ;
: md-$slots ( element -- ) [ unclip \ md-$slot swap 2array prefix ] map md-$table ;
: md-$snippet ( element -- ) "`" % element>markdown "`" % ;
: md-$strong ( element -- ) "**" % element>markdown "**" % ;
: md-$subheading ( element -- ) "### " % element>markdown "\n" %  ;
: md-$subsection ( element -- ) md-$link "\n" % ;
: md-$subsection* ( element -- ) md-$subsection ;
: md-$subsections ( element -- ) [ 1array md-$subsection ] each ;
: md-$synopsis ( element -- ) first synopsis md-$code ;
: md-$syntax ( element -- ) "Syntax" md-$heading md-$code ;
: md-$table ( element -- ) 
    dup length 0 > 
    [ 
        [ 
            [ "| " % element>markdown " " % ] each 
            "|\n" % 
        ] each 
    ] 
    [ drop ] if ;
: md-$title ( element -- ) ?nl "# " % article-title % "\n" % ;
: md-$tip-title ( element -- ) 
    [ "Tip of the day" md-$heading ] dip [ element>markdown ] "" make split-lines [ "> " prepend "\n" append % ] each ;
: md-$tip-of-the-day ( element -- )
    drop a-tip $tip-title "— " % "all-tips-of-the-day" md-$link
    ;
: md-$tips-of-the-day ( element -- )
    drop tips get
    [ "\n" % "\n" % ] [ content>> element>markdown ] interleave ;
: md-$unchecked-example ( element -- ) md-$example ;
: md-$url ( element -- ) first >url unparse % ;
: md-$value ( element -- ) drop ;
: md-$values ( element -- ) "Inputs and outputs" md-$heading [ "None\n" % ] [ [ values-row ] map (article>markdown) md-$table ] if-empty  ;
: md-$values-x/y ( element -- ) drop { { "x" number } { "y" number } } md-$values ;
: md-$var-description ( element -- ) md-$description ;
: md-$vocab-link ( element -- ) first vocab-name <vocab> 1array md-$link ;
: md-$vocab-links ( element -- ) [ md-$vocab-link "\n" % ] each ;
: md-$vocab-subsection ( element -- ) last vocab-help 1array md-$subsection ;
: md-$vocab-subsections ( element -- ) [ md-$vocab-subsection "\n" % ] each ;
: md-$vocab-roots ( element -- ) [ [ drop ] [ [ [ "Children from " prepend ] [ "Children" ] if* md-$heading ] [ md-$vocab-link ] bi* ] if-empty ] assoc-each ;
: md-vocab-words ( vocab -- ) { { [ dup lookup-vocab ] [ vocab-words md-$words ] } { [ dup find-vocab-root ] [ [ load-vocab drop ] keep md-vocab-words ] } [ drop ] } cond  ;
: md-$vocab ( element -- ) first { 
        [ dup vocab-help [ "Documentation" md-$heading nip 1array md-$long-link ] [ "Summary" md-$heading vocab-summary % ] if* ]
        [ md-vocab-words ]
        [ vocab-name disk-vocabs-for-prefix md-$vocab-roots ]
    } cleave ;
: md-$vocabulary ( element -- ) first vocabulary>> "Vocabulary" md-$heading 1array md-$vocab-link ;

: md-$warning ( element -- ) "Warning" md-$heading [ element>markdown ] "" make split-lines [ "> " prepend "\n" append % ] each  ;
: md-list-words ( words name -- ) over length 0 > [ md-$subheading [ [ \ md-$link swap 2array ] [ stack-effect effect>string \ md-$snippet swap 2array ] bi 2array ] map md-$table ] [ 2drop ] if ;
: md-list-classes-with-slots ( classes name -- ) 
    over length 0 > 
    [ 
        md-$subheading 
        [ 
            [ \ md-$link swap 2array ] 
            [ superclass-of \ md-$link swap 2array ] 
            [ all-slots [ name>> " " append ] map " " suffix concat dup length 1 > [ 1 head* ] when \ md-$snippet swap 2array ] tri 3array ] map md-$table 
    ] 
    [ 2drop ] if ;
: md-list-classes-without-slots ( classes name -- )  
    over length 0 > 
    [ md-$subheading [ [ \ md-$link swap 2array ] [ superclass-of \ md-$link swap 2array ] bi 2array ] map md-$table ] 
    [ 2drop ] if  ;
: md-$classes ( element -- )
    [ builtin-class? ] partition [ tuple-class? ] partition
    [ singleton-class? ] partition
    [ predicate-class? ] partition [ mixin-class? ] partition
    [ union-class? ] partition [ intersection-class? ] filter {
        [ "Builtin classes" md-list-classes-with-slots ]
        [ "Tuple classes" md-list-classes-with-slots ]
        [ "Singleton classes" md-list-classes-without-slots ]
        [ "Predicate classes" md-list-classes-without-slots ]
        [ "Mixin classes" md-list-classes-without-slots ]
        [ "Union classes" md-list-classes-without-slots ]
        [ "Intersection classes" md-list-classes-without-slots ]
    } spread
    ;
: md-$words ( element -- ) 
    "Words" md-$heading sort
    [ [ class? ] filter md-$classes ] [
            [ [ class? ] [ symbol? ] bi and ] reject
            [ parsing-word? ] partition [ generic? ] partition
            [ macro? ] partition [ symbol? ] partition
            [ primitive? ] partition
            [ predicate? ] partition swap {
                [ "Parsing words" md-list-words ]
                [ "Generic words" md-list-words ]
                [ "Macros" md-list-words ]
                [ "Symbol words" md-list-words ]
                [ "Primatives" md-list-words ]
                [ "Regular words" md-list-words ]
                [ "Predicate words" md-list-words ]
            } spread
    ] bi
    ;


: md-$xml-error ( element -- )
    "Bad XML document for the error" md-$heading md-$code ;

! like $subsections but skip the extra blank line
: md-$subs-nobl ( children -- )
    [ 1array md-$subsection* ] each ;

! swapped and n-matrix variants
: md-$equiv-word-note ( children -- )
    [ "This word is the " ] dip
    first2
    " variant of " swap
    [ { md-$link } ] dip suffix
    "."
    5 narray element>markdown ;

! words like <scale-matrix3> which have an array of inputs
: md-$finite-input-note ( children -- )
    [ "Only the first " ] dip
    first2
    " values in " swap
    [ { md-$snippet } ] dip suffix
    " are used."
    5 narray element>markdown ;

! a note for when a word assumes a 2d matrix
: md-$2d-only-note ( children -- )
    drop { "This word is intended for use with \"flat\" (2-dimensional) matrices. "
      ! "Using it with matrices of 3 or more dimensions may lead to unexpected results."
    }
    element>markdown ;

! a note for numeric-specific operations
: md-$matrix-scalar-note ( children -- )
    \ md-$subs-nobl prefix
    "This word assumes that elements of the input matrix are compatible with the following words:"
    swap 2array
    element>markdown ;

: md-$keep-shape-note ( children -- )
    drop { "The shape of the input matrix is preserved in the output." } element>markdown ;

: md-$link2 ( children -- )
    first2 [ md-$link "\n" % ] bi@ ;

! so that we don't end up with multiple $notes calls leading to multiple Notes sections
: md-$notelist ( children -- )
    \ md-$list prefix md-$notes ;



<<
CONSTANT: dollarsign-hash
    H{ 
        { $outputs md-$outputs }
        { $command md-$command }
        { $command-map md-$command-map }
        { $operations md-$operations }
        { $operation md-$operation }
        { $notelist md-$notelist }
        { $link2 md-$link2 }
        { $keep-shape-note md-$keep-shape-note }
        { $matrix-scalar-note md-$matrix-scalar-note }
        { $2d-only-note md-$2d-only-note }
        { $finite-input-note md-$finite-input-note }
        { $equiv-word-note md-$equiv-word-note }
        { $subs-nobl md-$subs-nobl }
        { $apropos md-$apropos }
        { $xml-error md-$xml-error }
        { $about md-$about }
        { $quotation md-$quotation }
        { $tips-of-the-day md-$tips-of-the-day }
        { $or md-$or }
        { $all-tags md-$all-tags }
        { $all-authors md-$all-authors }
        { $authors md-$authors }
        { $tags md-$tags }
        { $authored-vocabs md-$authored-vocabs }
        { $see-also md-$see-also }
        { $related md-$related }
        { $tip-of-the-day md-$tip-of-the-day }
        { $methods md-$methods }
        { $value md-$value }
        { $title md-$title }
        { $definition-icons md-$definition-icons }
        { $recent md-$recent }
        { $content md-$content }
        { $sequence md-$sequence }
        { $class-description md-$class-description }
        { $table md-$table }
        { $long-link md-$long-link }
        { $index md-$index }
        { $recent-searches md-$recent-searches }
        { $keep-case md-$keep-case }
        { $0-plurality md-$0-plurality }
        { $completions md-$completions }
        { $markup-example md-$markup-example }
        { $see md-$see }
        { $parsing-note md-$parsing-note }
        { $pretty-link md-$pretty-link }
        { $curious md-$curious }
        { $list md-$list }
        { $warning md-$warning }
        { $var-description md-$var-description }
        { $heading md-$heading }
        { $vocab-subsections md-$vocab-subsections }
        { $syntax md-$syntax }
        { $example md-$example }
        { $subsections md-$subsections }
        { $link md-$link }
        { $emphasis md-$emphasis }
        { $inputs md-$inputs }
        { $nl md-$nl }
        { $breadcrumbs md-$breadcrumbs }
        { $tip-title md-$tip-title }
        { $errors md-$errors }
        { $shuffle md-$shuffle }
        { $subsection* md-$subsection* }
        { $values-x/y md-$values-x/y }
        { $examples md-$examples }
        { $links md-$links }
        { $prettyprinting-note md-$prettyprinting-note }
        { $predicate md-$predicate }
        { $url md-$url }
        { $definition md-$definition }
        { $strong md-$strong }
        { $slot md-$slot }
        { $subheading md-$subheading }
        { $slots md-$slots }
        { $image md-$image }
        { $io-error md-$io-error }
        { $vocab-link md-$vocab-link }
        { $vocab md-$vocab }
        { $vocab-roots md-$vocab-roots }
        { $words md-$words }
        { $vocab-subsection md-$vocab-subsection }
        { $subsection md-$subsection }
        { $synopsis md-$synopsis }
        { $contract md-$contract }
        { $unchecked-example md-$unchecked-example }
        { $error-description md-$error-description }
        { $low-level-note md-$low-level-note }
        { $code md-$code }
        { $snippet md-$snippet }
        { $vocabulary md-$vocabulary }
        { $vocab-links md-$vocab-links }
        { $side-effects md-$side-effects }
        { $deprecated md-$deprecated }
        { $maybe md-$maybe }
        { $notes md-$notes }
        { $references md-$references }
        { $description md-$description }
        { $instance md-$instance }
        { $values md-$values }
    }
>>

