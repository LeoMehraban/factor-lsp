USING: sequences make kernel math splitting tools.annotations continuations io arrays strings vocabs combinators words quotations prettyprint prettyprint.sections urls help.topics effects accessors help.markup assocs see io.streams.string tools.annotations.private compiler.units ;
IN: factor-lsp.help

DEFER: md-$link
DEFER: md-$heading
DEFER: md-$see
DEFER: md-$see-also
DEFER: md-$table
DEFER: md-$snippet
DEFER: dollarsign-hash
GENERIC: element>markdown ( element -- string )

: with-annotations ( words annotation-quot: ( word old-def -- new-def ) quot: ( ..a -- ..b ) -- ..b ) 
  rot [ [ [ dupd with (annotate) ] curry ] 2dip -rot [ [ each ] 2curry [ with-compilation-unit ] curry ] dip ] keep [ [ (reset) ] each ] curry 
  [ with-compilation-unit ] curry [ compose ] dip [ finally ] 2curry call ; inline

MACRO: with-replacements ( assoc quot: ( ..a -- ..b ) -- quot: ( ..a -- ..b ) ) [ [ keys ] [ [ at def>> ] curry [ drop ] prepose ] bi ] dip [ with-annotations ] 3curry ;

M: array element>markdown unclip [ ( arg -- ) execute-effect ] "" make ; inline
M: effect element>markdown effect>string ; inline
M: f element>markdown ; inline
M: simple-element element>markdown [ element>markdown ] map concat ; inline
M: string element>markdown ; inline
M: word element>markdown [ { } swap ( arg -- ) execute-effect ] "" make ; inline

GENERIC: link-address ( article-name -- link )

M: string link-address "https://docs.factorcode.org/content/article-" prepend ".html" append ;
M: vocab link-address name>> "https://docs.factorcode.org/content/vocab-" prepend ".html" append  ;
M: word link-address [ name>> "https://docs.factorcode.org/content/word-" prepend ] [ vocabulary>> "," prepend ] bi ".html" append append ;
M: f link-address drop "https://docs.factorcode.org/content/word-f,syntax.html" ;

: (article>markdown) ( article-seq -- markdown ) dollarsign-hash [ element>markdown ] with-replacements ; inline
 
MEMO: article>markdown ( article-name -- markdown ) article-content (article>markdown) ; inline

: md-$breadcrumbs ( element -- ) dup length 0 > [ unclip-last [ "" [ [ 1array md-$link ] "" make " » " append append ] reduce ] dip [ 1array md-$link ] "" make append % ] [ drop ] if ;
: md-$class-description ( element -- ) "Class Description" md-$heading element>markdown % ;
: md-$code ( element -- ) "```factor\n" % element>markdown % "\n```\n" % ;
! : md-$content ( element -- )  ;
: md-$contract ( element -- ) "Generic word contract" md-$heading element>markdown % ;
: md-$curious ( element -- ) "For the curious..." md-$heading element>markdown %  ;
: md-$definition ( element -- ) "Definition" md-$heading md-$see ;
: md-$definition-icons ( element -- ) drop ;
: md-$deprecated ( element -- ) "Deprecated" md-$heading element>markdown split-lines [ "> " prepend "\n" append % ] each ;
: md-$description ( element -- ) "Description" md-$heading element>markdown %  ;
: md-$emphasis ( children -- ) "*" % element>markdown % "*" % ;
: md-$error-description ( element -- ) md-$description ;
: md-$errors ( element -- ) "Errors" md-$heading element>markdown %  ;
: md-$example ( element -- ) unclip-last [ join-lines ] dip "\n! prints:\n" prepend append md-$code ;
: md-$examples ( element -- ) "Examples" md-$heading element>markdown %  ;
: md-$heading ( element -- ) "\n\n## " % element>markdown % "\n" % ;
: md-$image ( element -- ) drop "\n<image>\n" % ;
: md-$inputs ( element -- ) "Inputs" md-$heading [ "None" % ] [ [ values-row ] map md-$table ] if-empty ;
: md-$instance ( element -- ) first dup name>> a/an % " " % 1array md-$link ;
: md-$io-error ( children -- ) drop "Throws an error if the I/O operation fails." md-$errors ;
: md-$link ( element -- ) 
    first dup article-name "[" prepend "]" append % "(" % link-address % ")" % ;
: md-$links ( topics -- ) dup length 0 > [ unclip-last [ "" [ [ 1array md-$link ] "" make ", " append append ] reduce ] dip [ 1array md-$link ] "" make append % ] [ drop ] if  ;
: md-$list ( element -- ) [ "- " % element>markdown % "\n" % ] each ;
: md-$long-link ( element -- ) first dup article-name "[" prepend % dup word? [ [ " " % stack-effect effect>string % ] [ name>> "](word:" % % ")" % ] bi ] [ "](article:" % % ")" % ] if  ;
: md-$low-level-note ( element -- ) drop "Notes" md-$heading "Calling this word directly is not necessary in most cases. Higher-level words call it automatically.\n" % ;
: md-$markup-example ( element -- ) first dup unparse " print-element" append 1array md-$code element>markdown % ;
: md-$maybe ( element -- ) md-$instance " or " % POSTPONE: f 1array md-$link ;
: md-$methods ( element -- ) first methods [ "Methods" md-$heading [ [ see "\n" write ] each ] with-string-writer md-$code ] unless-empty ;
: md-$nl ( element -- ) drop "\n" % ;
: md-$notes ( element -- ) "Notes" md-$heading element>markdown % ;
: md-$or ( element -- ) dup length 
    { 
        { 1 [ first md-$instance ] } 
        { 2 [ first2 [ md-$instance " or " element>markdown % ] [ md-$instance ] bi* ] } 
        [ drop unclip-last [ [ md-$instance ", " % ] each ] [ "or " % md-$instance ] bi* ]
    } case ;
: md-$outputs ( element -- ) "Outputs" md-$heading [ "None" % ] [ [ values-row ] map md-$table ] if-empty ;
: md-$parsing-note ( element -- ) drop "This word should only be called from parsing words." md-$notes ;
: md-$pretty-link ( element -- ) md-$link ;
: md-$prettyprinting-note ( element -- ) drop { "This word should only be called from inside the " { $link with-pprint } " combinator." } md-$notes ;
: md-$quotation ( element -- ) { "a " { $link quotation } " with stack effect " } element>markdown % md-$snippet ;
: md-$references ( element -- ) "References" md-$heading unclip element>markdown % [ \ $link swap ] map>alist md-$list ;
: md-$related ( element -- ) first dup "related" word-prop remove [ md-$see-also ] unless-empty ;
: md-$see ( element -- ) first [ see ] with-string-writer md-$code ;
: md-$see-also ( element -- ) "See also" md-$heading md-$links ;
: md-$sequence ( element -- ) 
    { "a " { $link sequence } " of " } element>markdown % dup length 
    {
        { 1 [ md-$link "s" % ] }
        {
            2
            [
                first2
                [ drop " or " % ]
                [ md-$link "s" %  ] bi*
            ]
        }
        [
            drop unclip-last
            [ [ md-$link "s" %  ", " % ] each ]
            [ "or " % md-$link "s" %  ] bi*
        ]
    } case ;
: md-$shuffle ( element -- ) 
    "This is a shuffle word, rearranging the top of the datastack as indicated by the word's stack effect: " swap ?first [ ": " swap "." 4array ] [ "." append ] if* md-$description ;
: md-$side-effects ( element -- ) "Side effects" md-$heading "Modifies " % md-$snippet ;
: md-$slot ( element -- ) md-$snippet ;
: md-$slots ( element -- ) [ unclip \ $slot swap 2array prefix ] map md-$table ;
: md-$snippet ( element -- ) "`" % element>markdown % "`" % ;
: md-$strong ( element -- ) "**" % element>markdown % "**" % ;
: md-$subheading ( element -- ) "### " % element>markdown % "\n" %  ;
: md-$subsection ( element -- ) "\n" % md-$link "\n" % ;
: md-$subsection* ( element -- ) md-$subsection ;
: md-$subsections ( element -- ) [ md-$subsection ] each ;
: md-$synopsis ( element -- ) synopsis md-$code ;
: md-$syntax ( element -- ) "Syntax" md-$heading md-$code ;
: md-$table ( element -- ) 
    dup length 0 > 
    [ 
        unclip 
        [ 
            [ 
                [ "| " % element>markdown % " " % ] each 
                "|\n" % 
            ] each 
        ] dip 
        [
            "| " % element>markdown % " " % 
        ] each
        "| " % 
    ] 
    [ drop ] if ;
: md-$unchecked-example ( element -- ) md-$example ;
: md-$url ( element -- ) first >url unparse % ;
: md-$value ( element -- ) drop ;
: md-$values ( element -- ) "Inputs and outputs" md-$heading [ "\nNone\n" % ] [ [ values-row ] map md-$table ] if-empty  ;
: md-$values-x/y ( element -- ) drop { { "x" number } { "y" number } } md-$values ;
: md-$var-description ( element -- ) md-$description ;
: md-$vocab-link ( element -- ) <vocab> 1array md-$link ;
: md-$vocab-links ( element -- ) [ md-$vocab-link ] each ;
: md-$vocab-subsection ( element -- ) vocab-help md-$subsection ;
: md-$vocab-subsections ( element -- ) [ "\n" % md-$vocab-subsection "\n" % ] each ;
: md-$vocabulary ( element -- ) first vocabulary>> "Vocabulary" md-$heading md-$vocab-link ;
: md-$warning ( element -- ) "Warning" md-$heading element>markdown split-lines [ "> " prepend "\n" append % ] each  ;
<<
CONSTANT: dollarsign-hash
    H{ 
        { $outputs md-$outputs }
        { $quotation md-$quotation }
        { $or md-$or }
        { $see-also md-$see-also }
        { $related md-$related }
        { $methods md-$methods }
        { $value md-$value }
        { $definition-icons md-$definition-icons }
        { $sequence md-$sequence }
        { $class-description md-$class-description }
        { $table md-$table }
        { $long-link md-$long-link }
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
        { $errors md-$errors }
        { $shuffle md-$shuffle }
        { $subsection* md-$subsection* }
        { $values-x/y md-$values-x/y }
        { $examples md-$examples }
        { $links md-$links }
        { $prettyprinting-note md-$prettyprinting-note }
        { $url md-$url }
        { $definition md-$definition }
        { $strong md-$strong }
        { $slot md-$slot }
        { $subheading md-$subheading }
        { $slots md-$slots }
        { $image md-$image }
        { $io-error md-$io-error }
        { $vocab-link md-$vocab-link }
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
